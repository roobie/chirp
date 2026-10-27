/* chirp's pcre2 module: PCRE2's 8-bit library behind a small Janet API.
 *
 * Matching is bounded by PCRE2's counted limits, never by time, so a pattern
 * fails the same way on every machine. The defaults are set here, because the
 * library's own heap limit is about 20 GB.
 *
 * Resources (a compiled pattern made for one call, a match context, match
 * data) are freed before an error is raised; Janet's panic longjmps, so
 * nothing may be left owned across it. */

#include <janet.h>
#include <pcre2.h>

#include <stdio.h>
#include <string.h>

#define DEFAULT_MATCH_LIMIT 10000000u
#define DEFAULT_DEPTH_LIMIT 10000000u
#define DEFAULT_HEAP_LIMIT_KIB 65536u /* 64 MiB */
#define ERR_LEN 320
#define STR_(x) #x
#define STR(x) STR_(x)

/* Compiled patterns */

typedef struct {
    pcre2_code *code;
} Regex;

static int regex_gc(void *p, size_t size) {
    (void)size;
    Regex *r = p;
    if (r->code) pcre2_code_free(r->code);
    r->code = NULL;
    return 0;
}

static const JanetAbstractType regex_type = {"pcre2/regex", regex_gc, JANET_ATEND_GC};

/* Options: one dictionary serves compile and match calls */

typedef struct {
    uint32_t compile_flags;
    int utf;
    int has_compile_opts;
    uint32_t match_limit, depth_limit, heap_limit;
    int32_t start;
    int32_t max;      /* split: most pieces cut, 0 for no cap */
} Opts;

static const struct {
    const char *name;
    uint32_t flag;
} flag_opts[] = {
    {"caseless", PCRE2_CASELESS},   {"multiline", PCRE2_MULTILINE},
    {"dotall", PCRE2_DOTALL},       {"extended", PCRE2_EXTENDED},
    {"ungreedy", PCRE2_UNGREEDY},   {"anchored", PCRE2_ANCHORED},
    {"ucp", PCRE2_UCP},             {NULL, 0}};

static uint32_t limit_opt(Janet v, const char *name) {
    if (!janet_checkint(v) || janet_unwrap_integer(v) < 1) {
        janet_panicf("pcre2: %s must be a positive integer", name);
    }
    return (uint32_t)janet_unwrap_integer(v);
}

static void read_opts(Janet v, Opts *o) {
    memset(o, 0, sizeof *o);
    o->utf = 1;
    o->match_limit = DEFAULT_MATCH_LIMIT;
    o->depth_limit = DEFAULT_DEPTH_LIMIT;
    o->heap_limit = DEFAULT_HEAP_LIMIT_KIB;
    if (janet_checktype(v, JANET_NIL)) return;
    const JanetKV *kvs;
    int32_t len, cap;
    if (!janet_dictionary_view(v, &kvs, &len, &cap)) {
        janet_panic("pcre2: opts must be a table or a struct");
    }
    for (int i = 0; flag_opts[i].name; i++) {
        Janet f = janet_dictionary_get(kvs, cap, janet_ckeywordv(flag_opts[i].name));
        if (!janet_checktype(f, JANET_NIL)) {
            o->has_compile_opts = 1;
            if (janet_truthy(f)) o->compile_flags |= flag_opts[i].flag;
        }
    }
    Janet u = janet_dictionary_get(kvs, cap, janet_ckeywordv("utf"));
    if (!janet_checktype(u, JANET_NIL)) {
        o->has_compile_opts = 1;
        o->utf = janet_truthy(u);
    }
    Janet ml = janet_dictionary_get(kvs, cap, janet_ckeywordv("match-limit"));
    if (!janet_checktype(ml, JANET_NIL)) o->match_limit = limit_opt(ml, ":match-limit");
    Janet dl = janet_dictionary_get(kvs, cap, janet_ckeywordv("depth-limit"));
    if (!janet_checktype(dl, JANET_NIL)) o->depth_limit = limit_opt(dl, ":depth-limit");
    Janet hl = janet_dictionary_get(kvs, cap, janet_ckeywordv("heap-limit"));
    if (!janet_checktype(hl, JANET_NIL)) o->heap_limit = limit_opt(hl, ":heap-limit");
    Janet st = janet_dictionary_get(kvs, cap, janet_ckeywordv("start"));
    if (!janet_checktype(st, JANET_NIL)) {
        if (!janet_checkint(st) || janet_unwrap_integer(st) < 0) {
            janet_panic("pcre2: :start must be a non-negative integer");
        }
        o->start = janet_unwrap_integer(st);
    }
    Janet mx = janet_dictionary_get(kvs, cap, janet_ckeywordv("max"));
    if (!janet_checktype(mx, JANET_NIL)) {
        if (!janet_checkint(mx) || janet_unwrap_integer(mx) < 0) {
            janet_panic("pcre2: :max must be a non-negative integer");
        }
        o->max = janet_unwrap_integer(mx);
    }
}

/* One call's working state */

typedef struct {
    pcre2_code *code;
    int owns_code;
    pcre2_match_context *mc;
    pcre2_match_data *md;
    int utf;
    char err[ERR_LEN];
} Ctx;

static void ctx_free(Ctx *c) {
    if (c->md) pcre2_match_data_free(c->md);
    if (c->mc) pcre2_match_context_free(c->mc);
    if (c->owns_code && c->code) pcre2_code_free(c->code);
    c->md = NULL;
    c->mc = NULL;
    c->code = NULL;
}

static void ctx_fail(Ctx *c) {
    char msg[ERR_LEN];
    memcpy(msg, c->err, ERR_LEN);
    ctx_free(c);
    janet_panic(msg);
}

static void set_pcre_error(Ctx *c, int rc) {
    switch (rc) {
        case PCRE2_ERROR_MATCHLIMIT:
            snprintf(c->err, ERR_LEN, "pcre2: match limit exceeded; raise :match-limit if this pattern needs more work");
            return;
        case PCRE2_ERROR_DEPTHLIMIT:
            snprintf(c->err, ERR_LEN, "pcre2: backtracking depth limit exceeded; raise :depth-limit if this pattern needs more");
            return;
        case PCRE2_ERROR_HEAPLIMIT:
            snprintf(c->err, ERR_LEN, "pcre2: heap limit exceeded; raise :heap-limit (KiB) if this pattern needs more");
            return;
        default: {
            char m[200];
            pcre2_get_error_message(rc, (PCRE2_UCHAR *)m, sizeof m);
            snprintf(c->err, ERR_LEN, "pcre2: %s", m);
        }
    }
}

static pcre2_code *compile_bytes(const uint8_t *pat, size_t len, const Opts *o, Ctx *c) {
    uint32_t flags = o->compile_flags | (o->utf ? PCRE2_UTF : 0);
    int ec;
    PCRE2_SIZE eo;
    pcre2_code *code = pcre2_compile((PCRE2_SPTR)pat, len, flags, &ec, &eo, NULL);
    if (!code) {
        char m[160];
        pcre2_get_error_message(ec, (PCRE2_UCHAR *)m, sizeof m);
        snprintf(c->err, ERR_LEN, "pcre2: %s at offset %zu of the pattern", m, (size_t)eo);
    }
    return code;
}

/* Take the pattern argument (a compiled regex or a pattern string), and make
 * the match context and data for the call. */
static void ctx_open(Ctx *c, const Janet *argv, int32_t n, const Opts *o) {
    memset(c, 0, sizeof *c);
    if (janet_checktype(argv[n], JANET_ABSTRACT) &&
        janet_abstract_type(janet_unwrap_abstract(argv[n])) == &regex_type) {
        if (o->has_compile_opts) {
            janet_panic("pcre2: compile options only apply to a pattern string; "
                        "pass them to pcre2/compile");
        }
        Regex *r = janet_unwrap_abstract(argv[n]);
        c->code = r->code;
        uint32_t ov;
        pcre2_pattern_info(c->code, PCRE2_INFO_ALLOPTIONS, &ov);
        c->utf = (ov & PCRE2_UTF) != 0;
    } else {
        JanetByteView pat = janet_getbytes(argv, n);
        c->code = compile_bytes(pat.bytes, (size_t)pat.len, o, c);
        if (!c->code) ctx_fail(c);
        c->owns_code = 1;
        c->utf = o->utf;
    }
    c->mc = pcre2_match_context_create(NULL);
    if (!c->mc) {
        snprintf(c->err, ERR_LEN, "pcre2: out of memory");
        ctx_fail(c);
    }
    pcre2_set_match_limit(c->mc, o->match_limit);
    pcre2_set_depth_limit(c->mc, o->depth_limit);
    pcre2_set_heap_limit(c->mc, o->heap_limit);
    c->md = pcre2_match_data_create_from_pattern(c->code, NULL);
    if (!c->md) {
        snprintf(c->err, ERR_LEN, "pcre2: out of memory");
        ctx_fail(c);
    }
}

/* Results: a struct of the captured text, keyed by group number and by name.
 * A group that did not take part in the match has no key. */

static Janet text(const uint8_t *s, PCRE2_SIZE from, PCRE2_SIZE to) {
    return janet_stringv(s + from, (int32_t)(to - from));
}

static Janet capture_struct(Ctx *c, const uint8_t *s, int rc) {
    PCRE2_SIZE *ov = pcre2_get_ovector_pointer(c->md);
    uint32_t nnames = 0;
    pcre2_pattern_info(c->code, PCRE2_INFO_NAMECOUNT, &nnames);
    JanetKV *st = janet_struct_begin(rc + (int32_t)nnames);
    for (int i = 0; i < rc; i++) {
        if (ov[2 * i] == PCRE2_UNSET || ov[2 * i] > ov[2 * i + 1]) continue;
        janet_struct_put(st, janet_wrap_integer(i), text(s, ov[2 * i], ov[2 * i + 1]));
    }
    if (nnames) {
        PCRE2_SPTR table;
        uint32_t entry;
        pcre2_pattern_info(c->code, PCRE2_INFO_NAMETABLE, &table);
        pcre2_pattern_info(c->code, PCRE2_INFO_NAMEENTRYSIZE, &entry);
        for (uint32_t k = 0; k < nnames; k++, table += entry) {
            int g = (table[0] << 8) | table[1];
            if (g >= rc || ov[2 * g] == PCRE2_UNSET || ov[2 * g] > ov[2 * g + 1]) continue;
            janet_struct_put(st, janet_ckeywordv((const char *)table + 2),
                             text(s, ov[2 * g], ov[2 * g + 1]));
        }
    }
    return janet_wrap_struct(janet_struct_end(st));
}

/* Successive non-overlapping matches. After an empty match the next try must
 * not be empty at the same place; if that fails the search moves on one
 * character, as pcre2demo does. */

typedef struct {
    Ctx *c;
    const uint8_t *s;
    size_t len, pos;
    uint32_t flags;
    int rc;     /* the error, when iter_next returns -1 */
    int groups; /* what pcre2_match returned for the last match */
} Iter;

static void iter_init(Iter *it, Ctx *c, const uint8_t *s, size_t len, size_t start) {
    it->c = c;
    it->s = s;
    it->len = len;
    it->pos = start;
    it->flags = 0;
    it->rc = 0;
    it->groups = 0;
}

/* 1: a match is in the match data; 0: no more; -1: an error, in it->rc. */
static int iter_next(Iter *it) {
    for (;;) {
        if (it->pos > it->len) return 0;
        int rc = pcre2_match(it->c->code, (PCRE2_SPTR)it->s, it->len, it->pos, it->flags,
                             it->c->md, it->c->mc);
        if (rc > 0) {
            PCRE2_SIZE *ov = pcre2_get_ovector_pointer(it->c->md);
            if (ov[1] < it->pos) { /* \K in a lookbehind can end before the start */
                it->rc = PCRE2_ERROR_INTERNAL;
                return -1;
            }
            it->flags = PCRE2_NO_UTF_CHECK;
            if (ov[1] == ov[0]) it->flags |= PCRE2_NOTEMPTY_ATSTART | PCRE2_ANCHORED;
            it->pos = ov[1];
            it->groups = rc;
            return 1;
        }
        if (rc != PCRE2_ERROR_NOMATCH) {
            it->rc = rc;
            return -1;
        }
        if (!(it->flags & PCRE2_ANCHORED) || it->pos >= it->len) return 0;
        it->pos++;
        if (it->c->utf) {
            while (it->pos < it->len && (it->s[it->pos] & 0xC0) == 0x80) it->pos++;
        }
        it->flags = PCRE2_NO_UTF_CHECK;
    }
}

static void check_start(const Opts *o, size_t len) {
    if ((size_t)o->start > len) janet_panic("pcre2: :start is past the end of the subject");
}

/* Functions */

JANET_FN(chirp_pcre2_fn_compile, "(pcre2/compile pattern &opt opts)",
         "Compiles a Perl-style pattern to a regex that the other functions accept in place of "
         "a pattern string. Compile once when a pattern is used more than once.\n\n"
         "opts is a table or struct. Flags, each true or false: :caseless, :multiline, "
         ":dotall, :extended, :ungreedy, :anchored and :ucp (\\d, \\w and the like follow "
         "Unicode). :utf defaults to true, so the pattern and subjects are UTF-8 and a "
         "subject that is not valid UTF-8 is an error; pass :utf false to match bytes.") {
    janet_arity(argc, 1, 2);
    Opts o;
    read_opts(argc > 1 ? argv[1] : janet_wrap_nil(), &o);
    JanetByteView pat = janet_getbytes(argv, 0);
    Ctx c;
    memset(&c, 0, sizeof c);
    pcre2_code *code = compile_bytes(pat.bytes, (size_t)pat.len, &o, &c);
    if (!code) ctx_fail(&c);
    Regex *r = janet_abstract(&regex_type, sizeof(Regex));
    r->code = code;
    return janet_wrap_abstract(r);
}

JANET_FN(chirp_pcre2_fn_match, "(pcre2/match re subject &opt opts)",
         "Finds the first match of re (a compiled regex or a pattern string) in subject. "
         "Returns nil when there is none, otherwise a struct of the matched text: key 0 is "
         "the whole match, 1 and up are the groups, and a named group also has its name as a "
         "keyword key. A group that took no part in the match has no key.\n\n"
         "opts: :start, a byte offset to begin at (default 0), and the limits below. For a "
         "pattern string it also takes the compile options of pcre2/compile.\n\n"
         "Matching is bounded by counts, not time: :match-limit (default 10000000), "
         ":depth-limit (default 10000000) and :heap-limit in KiB (default 65536). A pattern "
         "that runs past one fails with an error naming it.") {
    janet_arity(argc, 2, 3);
    Opts o;
    read_opts(argc > 2 ? argv[2] : janet_wrap_nil(), &o);
    JanetByteView subj = janet_getbytes(argv, 1);
    Ctx c;
    ctx_open(&c, argv, 0, &o);
    if ((size_t)o.start > (size_t)subj.len) {
        snprintf(c.err, ERR_LEN, "pcre2: :start is past the end of the subject");
        ctx_fail(&c);
    }
    int rc = pcre2_match(c.code, (PCRE2_SPTR)subj.bytes, (size_t)subj.len, (size_t)o.start, 0, c.md, c.mc);
    if (rc == PCRE2_ERROR_NOMATCH) {
        ctx_free(&c);
        return janet_wrap_nil();
    }
    if (rc < 0) {
        set_pcre_error(&c, rc);
        ctx_fail(&c);
    }
    Janet res = capture_struct(&c, subj.bytes, rc);
    ctx_free(&c);
    return res;
}

JANET_FN(chirp_pcre2_fn_find_all, "(pcre2/find-all re subject &opt opts)",
         "Returns an array of every non-overlapping match of re in subject, each shaped as "
         "pcre2/match returns it. Takes the same opts.") {
    janet_arity(argc, 2, 3);
    Opts o;
    read_opts(argc > 2 ? argv[2] : janet_wrap_nil(), &o);
    JanetByteView subj = janet_getbytes(argv, 1);
    Ctx c;
    ctx_open(&c, argv, 0, &o);
    if ((size_t)o.start > (size_t)subj.len) {
        snprintf(c.err, ERR_LEN, "pcre2: :start is past the end of the subject");
        ctx_fail(&c);
    }
    JanetArray *out = janet_array(0);
    Iter it;
    iter_init(&it, &c, subj.bytes, (size_t)subj.len, (size_t)o.start);
    int r;
    while ((r = iter_next(&it)) == 1) {
        janet_array_push(out, capture_struct(&c, subj.bytes, it.groups));
    }
    if (r < 0) {
        set_pcre_error(&c, it.rc);
        ctx_fail(&c);
    }
    ctx_free(&c);
    return janet_wrap_array(out);
}

static Janet substitute(int32_t argc, Janet *argv, uint32_t global) {
    janet_arity(argc, 3, 4);
    Opts o;
    read_opts(argc > 3 ? argv[3] : janet_wrap_nil(), &o);
    JanetByteView subj = janet_getbytes(argv, 1);
    JanetByteView rep = janet_getbytes(argv, 2);
    Ctx c;
    ctx_open(&c, argv, 0, &o);
    if ((size_t)o.start > (size_t)subj.len) {
        snprintf(c.err, ERR_LEN, "pcre2: :start is past the end of the subject");
        ctx_fail(&c);
    }
    uint32_t opts = PCRE2_SUBSTITUTE_OVERFLOW_LENGTH | PCRE2_SUBSTITUTE_UNSET_EMPTY | global;
    PCRE2_SIZE cap = (PCRE2_SIZE)subj.len + 256;
    JanetBuffer *buf = janet_buffer((int32_t)cap);
    PCRE2_SIZE outlen = cap;
    int rc = pcre2_substitute(c.code, (PCRE2_SPTR)subj.bytes, (size_t)subj.len, (size_t)o.start, opts, c.md,
                              c.mc, (PCRE2_SPTR)rep.bytes, (size_t)rep.len, buf->data, &outlen);
    if (rc == PCRE2_ERROR_NOMEMORY) {
        janet_buffer_ensure(buf, (int32_t)outlen, 1);
        rc = pcre2_substitute(c.code, (PCRE2_SPTR)subj.bytes, (size_t)subj.len, (size_t)o.start, opts, c.md,
                              c.mc, (PCRE2_SPTR)rep.bytes, (size_t)rep.len, buf->data, &outlen);
    }
    if (rc < 0) {
        set_pcre_error(&c, rc);
        ctx_fail(&c);
    }
    ctx_free(&c);
    return janet_stringv(buf->data, (int32_t)outlen);
}

JANET_FN(chirp_pcre2_fn_replace, "(pcre2/replace re subject replacement &opt opts)",
         "Returns subject with the first match of re replaced. In replacement, $1 and ${1} "
         "insert a group, ${name} a named group, and $$ a literal $. A group that took no "
         "part in the match inserts nothing; a group that does not exist is an error. "
         "Takes the same opts as pcre2/match.") {
    return substitute(argc, argv, 0);
}

JANET_FN(chirp_pcre2_fn_replace_all, "(pcre2/replace-all re subject replacement &opt opts)",
         "Like pcre2/replace, but replaces every non-overlapping match.") {
    return substitute(argc, argv, PCRE2_SUBSTITUTE_GLOBAL);
}

JANET_FN(chirp_pcre2_fn_split, "(pcre2/split re subject &opt opts)",
         "Returns an array of the pieces of subject between the matches of re. A match at the "
         "start or end of subject gives an empty piece there, and an empty match splits "
         "between every character. :max, when given and above 0, cuts at most that many "
         "times, leaving the rest in the last piece. Takes the same opts as pcre2/match.") {
    janet_arity(argc, 2, 3);
    Opts o;
    read_opts(argc > 2 ? argv[2] : janet_wrap_nil(), &o);
    JanetByteView subj = janet_getbytes(argv, 1);
    Ctx c;
    ctx_open(&c, argv, 0, &o);
    if ((size_t)o.start > (size_t)subj.len) {
        snprintf(c.err, ERR_LEN, "pcre2: :start is past the end of the subject");
        ctx_fail(&c);
    }
    JanetArray *out = janet_array(0);
    Iter it;
    iter_init(&it, &c, subj.bytes, (size_t)subj.len, (size_t)o.start);
    PCRE2_SIZE last = (PCRE2_SIZE)o.start;
    int cuts = 0, r = 0;
    while ((o.max == 0 || cuts < o.max) && (r = iter_next(&it)) == 1) {
        PCRE2_SIZE *ov = pcre2_get_ovector_pointer(c.md);
        janet_array_push(out, text(subj.bytes, last, ov[0]));
        last = ov[1];
        cuts++;
    }
    if (!(o.max == 0 || cuts < o.max)) r = 0;
    if (r < 0) {
        set_pcre_error(&c, it.rc);
        ctx_fail(&c);
    }
    janet_array_push(out, text(subj.bytes, last, (PCRE2_SIZE)subj.len));
    ctx_free(&c);
    return janet_wrap_array(out);
}

JANET_FN(chirp_pcre2_fn_version, "(pcre2/version)", "Returns the version of the bundled PCRE2, such as \"10.49\".") {
    janet_fixarity(argc, 0);
    (void)argv;
    return janet_cstringv(STR(PCRE2_MAJOR) "." STR(PCRE2_MINOR));
}

JANET_MODULE_ENTRY(JanetTable *env) {
    static const JanetRegExt cfuns[] = {
        JANET_REG("compile", chirp_pcre2_fn_compile),
        JANET_REG("match", chirp_pcre2_fn_match),
        JANET_REG("find-all", chirp_pcre2_fn_find_all),
        JANET_REG("replace", chirp_pcre2_fn_replace),
        JANET_REG("replace-all", chirp_pcre2_fn_replace_all),
        JANET_REG("split", chirp_pcre2_fn_split),
        JANET_REG("version", chirp_pcre2_fn_version),
        JANET_REG_END};
    janet_cfuns_ext(env, "pcre2", cfuns);
}
