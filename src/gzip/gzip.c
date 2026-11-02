/* chirp's gzip module: gzip framing (RFC 1952) over miniz's raw deflate.
 *
 * spork/zip links miniz too, but offers only zlib framing and no streaming.
 * miniz is compiled into this file with every function static, so this copy
 * and spork/zip's cannot clash in the one binary, and the compiler drops the
 * parts this module does not call.
 *
 * Compressing writes one member with no name, mtime 0 and OS 255 (unknown), so
 * the same input always gives the same bytes. Decompressing reads every member
 * of a concatenation, as gzip -d does, checks each one's CRC-32 and length,
 * and rejects anything after the last member. */

#include <assert.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <janet.h>

/* miniz.h declares three of its functions extern, which a static MINIZ_EXPORT
 * contradicts, so extern means nothing while miniz is read. The system headers
 * it includes are already in, so their declarations keep it. */
#define MINIZ_EXPORT static
#define MINIZ_NO_ARCHIVE_APIS
#define MINIZ_NO_STDIO
#define MINIZ_NO_TIME
#define MINIZ_NO_ZLIB_COMPATIBLE_NAMES
#define extern
#include <miniz.c>
#undef extern

/* Output grows by at least this much, so each miniz call has room to work. */
#define CHUNK 65536

#define FHCRC 2
#define FEXTRA 4
#define FNAME 8
#define FCOMMENT 16

/* Room for at least CHUNK more bytes; a buffer cannot pass INT32_MAX. */
static void reserve(JanetBuffer *b) {
    if (b->capacity - b->count >= CHUNK) return;
    if (b->count > INT32_MAX - CHUNK) janet_panic("gzip: output too large for a buffer");
    janet_buffer_ensure(b, b->count + CHUNK, 2);
}

static void put_u32le(JanetBuffer *b, uint32_t v) {
    uint8_t x[4] = {(uint8_t) v, (uint8_t)(v >> 8), (uint8_t)(v >> 16), (uint8_t)(v >> 24)};
    janet_buffer_push_bytes(b, x, 4);
}

static uint32_t get_u32le(const uint8_t *p) {
    return (uint32_t) p[0] | ((uint32_t) p[1] << 8) | ((uint32_t) p[2] << 16) | ((uint32_t) p[3] << 24);
}

/* Compressor */

typedef struct {
    mz_stream z;
    int live;          /* z holds miniz state that must be freed */
    int started;       /* the header has been written */
    int finished;
    int level;
    uint32_t crc;
    uint32_t size;     /* input length mod 2^32, as the trailer holds it */
} Compressor;

static int compressor_gc(void *p, size_t len) {
    (void) len;
    Compressor *c = p;
    if (c->live) mz_deflateEnd(&c->z);
    return 0;
}

static const JanetAbstractType compressor_type = {
    .name = "gzip/compressor",
    .gc = compressor_gc,
};

static void compressor_init(Compressor *c, int level) {
    memset(c, 0, sizeof(*c));
    c->level = level;
    c->crc = MZ_CRC32_INIT;
    if (mz_deflateInit2(&c->z, level, MZ_DEFLATED, -MZ_DEFAULT_WINDOW_BITS, 9, MZ_DEFAULT_STRATEGY) != MZ_OK)
        janet_panic("gzip: cannot start a compressor");
    c->live = 1;
}

static void compressor_header(Compressor *c, JanetBuffer *out) {
    if (c->started) return;
    c->started = 1;
    /* XFL: 2 for the slowest level, 4 for the fastest, as gzip writes it. */
    uint8_t xfl = c->level >= 9 ? 2 : (c->level == 1 ? 4 : 0);
    uint8_t h[10] = {0x1f, 0x8b, 8, 0, 0, 0, 0, 0, xfl, 255};
    janet_buffer_push_bytes(out, h, 10);
}

static void compressor_run(Compressor *c, const uint8_t *in, int32_t len, int flush, JanetBuffer *out) {
    c->z.next_in = in;
    c->z.avail_in = (unsigned int) len;
    for (;;) {
        reserve(out);
        c->z.next_out = out->data + out->count;
        c->z.avail_out = (unsigned int)(out->capacity - out->count);
        unsigned int before = c->z.avail_out;
        int status = mz_deflate(&c->z, flush);
        out->count += (int32_t)(before - c->z.avail_out);
        if (status == MZ_STREAM_END) return;
        if (status == MZ_BUF_ERROR && c->z.avail_in == 0 && flush != MZ_FINISH) return;
        if (status != MZ_OK && status != MZ_BUF_ERROR)
            janet_panicf("gzip: compression failed: %s", mz_error(status));
        if (flush != MZ_FINISH && c->z.avail_in == 0 && c->z.avail_out > 0) return;
    }
}

static void compressor_update(Compressor *c, JanetByteView in, JanetBuffer *out) {
    if (c->finished) janet_panic("gzip: the compressor is already finished");
    compressor_header(c, out);
    c->crc = (uint32_t) mz_crc32(c->crc, in.bytes, (size_t) in.len);
    c->size += (uint32_t) in.len;
    compressor_run(c, in.bytes, in.len, MZ_NO_FLUSH, out);
}

static void compressor_finish(Compressor *c, JanetBuffer *out) {
    if (c->finished) janet_panic("gzip: the compressor is already finished");
    compressor_header(c, out);
    compressor_run(c, NULL, 0, MZ_FINISH, out);
    put_u32le(out, c->crc);
    put_u32le(out, c->size);
    c->finished = 1;
    mz_deflateEnd(&c->z);
    c->live = 0;
}

/* Decompressor */

enum {
    S_HEADER,    /* the fixed 10 bytes */
    S_XLEN,      /* FEXTRA's 2-byte length */
    S_EXTRA,     /* FEXTRA's bytes */
    S_NAME,      /* FNAME, up to its NUL */
    S_COMMENT,   /* FCOMMENT, up to its NUL */
    S_HCRC,      /* FHCRC's 2 bytes */
    S_BODY,      /* the deflate stream */
    S_TRAILER,   /* CRC-32 and length */
    S_BETWEEN    /* a member has ended; another may follow */
};

typedef struct {
    mz_stream z;
    int live;
    int state;
    int members;       /* members fully read */
    uint8_t flags;
    uint8_t fixed[10]; /* the header or the trailer, as it arrives */
    int have;          /* bytes of fixed[] filled, or of extra skipped */
    int need;
    uint32_t hcrc;     /* CRC-32 of the header so far, for FHCRC */
    uint32_t crc;      /* CRC-32 of the member's output so far */
    uint32_t size;
    int finished;
} Decompressor;

static int decompressor_gc(void *p, size_t len) {
    (void) len;
    Decompressor *d = p;
    if (d->live) mz_inflateEnd(&d->z);
    return 0;
}

static const JanetAbstractType decompressor_type = {
    .name = "gzip/decompressor",
    .gc = decompressor_gc,
};

static void decompressor_init(Decompressor *d) {
    memset(d, 0, sizeof(*d));
    if (mz_inflateInit2(&d->z, -MZ_DEFAULT_WINDOW_BITS) != MZ_OK)
        janet_panic("gzip: cannot start a decompressor");
    d->live = 1;
    d->state = S_HEADER;
    d->need = 10;
    d->hcrc = MZ_CRC32_INIT;
}

static void start_body(Decompressor *d) {
    d->state = S_BODY;
    d->crc = MZ_CRC32_INIT;
    d->size = 0;
}

/* After the fixed header, the optional fields its flags announce. */
static void next_header_field(Decompressor *d) {
    d->have = 0;
    if (d->state < S_XLEN && (d->flags & FEXTRA)) { d->state = S_XLEN; d->need = 2; return; }
    if (d->state < S_NAME && (d->flags & FNAME)) { d->state = S_NAME; return; }
    if (d->state < S_COMMENT && (d->flags & FCOMMENT)) { d->state = S_COMMENT; return; }
    if (d->state < S_HCRC && (d->flags & FHCRC)) { d->state = S_HCRC; d->need = 2; return; }
    start_body(d);
}

/* Header and trailer bytes, one at a time; they are short. */
static void header_byte(Decompressor *d, uint8_t c) {
    switch (d->state) {
        case S_HEADER:
            d->fixed[d->have++] = c;
            d->hcrc = (uint32_t) mz_crc32(d->hcrc, &c, 1);
            if ((d->have == 1 && c != 0x1f) || (d->have == 2 && c != 0x8b))
                janet_panic("gzip: not gzip data");
            if (d->have == 3 && c != 8) janet_panicf("gzip: unknown compression method %d", c);
            if (d->have == 4 && (c & 0xe0)) janet_panic("gzip: reserved header flags are set");
            if (d->have == d->need) {
                d->flags = d->fixed[3];
                next_header_field(d);
            }
            return;
        case S_XLEN:
            d->fixed[d->have++] = c;
            d->hcrc = (uint32_t) mz_crc32(d->hcrc, &c, 1);
            if (d->have == 2) {
                d->state = S_EXTRA;
                d->have = 0;
                d->need = d->fixed[0] | (d->fixed[1] << 8);
                if (d->need == 0) next_header_field(d);
            }
            return;
        case S_EXTRA:
            d->hcrc = (uint32_t) mz_crc32(d->hcrc, &c, 1);
            if (++d->have == d->need) next_header_field(d);
            return;
        case S_NAME:
        case S_COMMENT:
            d->hcrc = (uint32_t) mz_crc32(d->hcrc, &c, 1);
            if (c == 0) next_header_field(d);
            return;
        case S_HCRC:
            d->fixed[d->have++] = c;
            if (d->have == 2) {
                if ((uint32_t)(d->fixed[0] | (d->fixed[1] << 8)) != (d->hcrc & 0xffff))
                    janet_panic("gzip: header checksum mismatch");
                start_body(d);
            }
            return;
        case S_TRAILER:
            d->fixed[d->have++] = c;
            if (d->have == 8) {
                if (get_u32le(d->fixed) != d->crc) janet_panic("gzip: CRC-32 mismatch, the data is corrupt");
                if (get_u32le(d->fixed + 4) != d->size) janet_panic("gzip: length mismatch, the data is corrupt");
                d->members++;
                d->state = S_BETWEEN;
            }
            return;
        case S_BETWEEN:
            if (c != 0x1f) janet_panic("gzip: trailing data after the last member");
            if (mz_inflateReset(&d->z) != MZ_OK) janet_panic("gzip: cannot restart the decompressor");
            d->state = S_HEADER;
            d->have = 0;
            d->need = 10;
            d->hcrc = MZ_CRC32_INIT;
            header_byte(d, c);
            return;
    }
}

static void decompressor_update(Decompressor *d, JanetByteView in, JanetBuffer *out) {
    if (d->finished) janet_panic("gzip: the decompressor is already finished");
    const uint8_t *p = in.bytes;
    const uint8_t *end = in.bytes + in.len;
    while (p < end) {
        if (d->state != S_BODY) {
            header_byte(d, *p++);
            continue;
        }
        d->z.next_in = p;
        d->z.avail_in = (unsigned int)(end - p);
        int status;
        for (;;) {
            reserve(out);
            uint8_t *start = out->data + out->count;
            d->z.next_out = start;
            d->z.avail_out = (unsigned int)(out->capacity - out->count);
            unsigned int before = d->z.avail_out;
            status = mz_inflate(&d->z, MZ_NO_FLUSH);
            int32_t made = (int32_t)(before - d->z.avail_out);
            d->crc = (uint32_t) mz_crc32(d->crc, start, (size_t) made);
            d->size += (uint32_t) made;
            out->count += made;
            if (status == MZ_DATA_ERROR) janet_panic("gzip: the compressed data is corrupt");
            if (status != MZ_OK && status != MZ_STREAM_END && status != MZ_BUF_ERROR)
                janet_panicf("gzip: decompression failed: %s", mz_error(status));
            /* Only MZ_OK may leave output behind; inflate reports a call that can
             * do nothing more without input as MZ_BUF_ERROR. */
            if (status != MZ_OK) break;
        }
        p = d->z.next_in;
        if (status == MZ_STREAM_END) {
            d->state = S_TRAILER;
            d->have = 0;
        }
    }
}

static void decompressor_finish(Decompressor *d) {
    if (d->finished) janet_panic("gzip: the decompressor is already finished");
    d->finished = 1;
    if (d->state != S_BETWEEN) {
        if (d->members == 0 && d->state == S_HEADER && d->have == 0) janet_panic("gzip: no data");
        janet_panic("gzip: the data is truncated");
    }
    mz_inflateEnd(&d->z);
    d->live = 0;
}

/* Janet functions */

static int opt_level(const Janet *argv, int32_t argc, int32_t n) {
    int32_t level = janet_optinteger(argv, argc, n, 6);
    if (level < 0 || level > 9) janet_panicf("gzip: level must be 0 to 9, got %d", level);
    return level;
}

JANET_FN(chirp_gzip_fn_compress,
         "(gzip/compress bytes &opt level into)",
         "Compress `bytes` into one gzip member, appended to buffer `into` (a new "
         "buffer by default), and return it. `level` runs from 0 (stored) to 9 "
         "(smallest), default 6. The header holds no name and mtime 0, so equal "
         "input gives equal output.") {
    janet_arity(argc, 1, 3);
    JanetByteView in = janet_getbytes(argv, 0);
    int level = opt_level(argv, argc, 1);
    JanetBuffer *out = janet_optbuffer(argv, argc, 2, in.len / 2 + 32);
    Compressor *c = janet_abstract(&compressor_type, sizeof(Compressor));
    compressor_init(c, level);
    compressor_update(c, in, out);
    compressor_finish(c, out);
    return janet_wrap_buffer(out);
}

JANET_FN(chirp_gzip_fn_decompress,
         "(gzip/decompress bytes &opt into)",
         "Decompress gzip data, appended to buffer `into` (a new buffer by default), "
         "and return it. Concatenated members are read in turn, as `gzip -d` does. "
         "A bad checksum or length, a truncated member or data after the last "
         "member is an error.") {
    janet_arity(argc, 1, 2);
    JanetByteView in = janet_getbytes(argv, 0);
    /* A guess at the output size, kept far from INT32_MAX. */
    int32_t guess = in.len < (1 << 26) ? in.len * 3 + 64 : (1 << 28);
    JanetBuffer *out = janet_optbuffer(argv, argc, 1, guess);
    Decompressor *d = janet_abstract(&decompressor_type, sizeof(Decompressor));
    decompressor_init(d);
    decompressor_update(d, in, out);
    decompressor_finish(d);
    return janet_wrap_buffer(out);
}

JANET_FN(chirp_gzip_fn_compressor,
         "(gzip/compressor &opt level)",
         "A compressor for data that arrives in pieces: give each piece to "
         "`gzip/update`, then call `gzip/finish` once. `level` is as for "
         "`gzip/compress`.") {
    janet_arity(argc, 0, 1);
    int level = opt_level(argv, argc, 0);
    Compressor *c = janet_abstract(&compressor_type, sizeof(Compressor));
    compressor_init(c, level);
    return janet_wrap_abstract(c);
}

JANET_FN(chirp_gzip_fn_decompressor,
         "(gzip/decompressor)",
         "A decompressor for gzip data that arrives in pieces: give each piece to "
         "`gzip/update`, then call `gzip/finish` once to check the data ended "
         "where a member ends.") {
    janet_fixarity(argc, 0);
    Decompressor *d = janet_abstract(&decompressor_type, sizeof(Decompressor));
    decompressor_init(d);
    return janet_wrap_abstract(d);
}

JANET_FN(chirp_gzip_fn_update,
         "(gzip/update z bytes &opt into)",
         "Feed `bytes` to compressor or decompressor `z`, append what it can "
         "produce so far to buffer `into` (a new buffer by default), and return "
         "the buffer. Some output may wait for later input or for `gzip/finish`.") {
    janet_arity(argc, 2, 3);
    JanetByteView in = janet_getbytes(argv, 1);
    JanetBuffer *out = janet_optbuffer(argv, argc, 2, CHUNK);
    void *z = janet_checkabstract(argv[0], &compressor_type);
    if (z) {
        compressor_update(z, in, out);
    } else {
        z = janet_checkabstract(argv[0], &decompressor_type);
        if (!z) janet_panicf("gzip: expected a gzip/compressor or gzip/decompressor, got %v", argv[0]);
        decompressor_update(z, in, out);
    }
    return janet_wrap_buffer(out);
}

JANET_FN(chirp_gzip_fn_finish,
         "(gzip/finish z &opt into)",
         "End compressor or decompressor `z` and return buffer `into` (a new buffer "
         "by default). A compressor appends the rest of its output and the trailer. "
         "A decompressor appends nothing; it is an error if the data stopped "
         "inside a member. `z` takes no more input afterwards.") {
    janet_arity(argc, 1, 2);
    JanetBuffer *out = janet_optbuffer(argv, argc, 1, 64);
    void *z = janet_checkabstract(argv[0], &compressor_type);
    if (z) {
        compressor_finish(z, out);
    } else {
        z = janet_checkabstract(argv[0], &decompressor_type);
        if (!z) janet_panicf("gzip: expected a gzip/compressor or gzip/decompressor, got %v", argv[0]);
        decompressor_finish(z);
    }
    return janet_wrap_buffer(out);
}

JANET_FN(chirp_gzip_fn_version,
         "(gzip/version)",
         "The version of miniz that does the deflating.") {
    janet_fixarity(argc, 0);
    (void) argv;
    return janet_cstringv(MZ_VERSION);
}

JANET_MODULE_ENTRY(JanetTable *env) {
    JanetRegExt cfuns[] = {
        JANET_REG("compress", chirp_gzip_fn_compress),
        JANET_REG("decompress", chirp_gzip_fn_decompress),
        JANET_REG("compressor", chirp_gzip_fn_compressor),
        JANET_REG("decompressor", chirp_gzip_fn_decompressor),
        JANET_REG("update", chirp_gzip_fn_update),
        JANET_REG("finish", chirp_gzip_fn_finish),
        JANET_REG("version", chirp_gzip_fn_version),
        JANET_REG_END};
    janet_cfuns_ext(env, "gzip", cfuns);
}
