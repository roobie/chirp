/* chirp's ordered JSON decoder, for the json overlay. It is spork/json's
 * decoder (src/json.c, MIT, Calvin Rose) with the object case building an omap
 * instead of a table, so that on any input it gives the same values, the same
 * errors at the same positions. The overlay's parity test holds it to that;
 * keep the two in step when the pin moves. */

#include "omap.h"

#include <errno.h>
#include <stdlib.h>

#define JSON_KEYWORD_KEY 0x10000
#define JSON_NULL_TO_NIL 0x20000

static int white(uint8_t c) {
    return c == '\t' || c == '\n' || c == ' ' || c == '\r';
}

static void skipwhite(const char **p) {
    const char *cp = *p;
    for (;;) {
        if (white(*cp)) cp++;
        else break;
    }
    *p = cp;
}

static int hexdig(char dig) {
    if (dig >= '0' && dig <= '9') return dig - '0';
    if (dig >= 'a' && dig <= 'f') return 10 + dig - 'a';
    if (dig >= 'A' && dig <= 'F') return 10 + dig - 'A';
    return -1;
}

static const char *decode_utf16_escape(const char *p, uint32_t *outpoint) {
    if (!p[0] || !p[1] || !p[2] || !p[3]) return "unexpected end of source";
    int d1 = hexdig(p[0]);
    int d2 = hexdig(p[1]);
    int d3 = hexdig(p[2]);
    int d4 = hexdig(p[3]);
    if (d1 < 0 || d2 < 0 || d3 < 0 || d4 < 0) return "invalid hex digit";
    *outpoint = d4 | (d3 << 4) | (d2 << 8) | (d1 << 12);
    return NULL;
}

/* A string with escapes, where utf-16 escapes become utf-8. */
static const char *decode_string(const char **p, Janet *out) {
    JanetBuffer *buffer = janet_buffer(0);
    const char *cp = *p;
    while (*cp != '"') {
        uint8_t b = (uint8_t) *cp;
        if (b < 32) return "invalid character in string";
        if (b == '\\') {
            cp++;
            switch (*cp) {
                default:
                    return "unknown string escape";
                case 'b': b = '\b'; break;
                case 'f': b = '\f'; break;
                case 'n': b = '\n'; break;
                case 'r': b = '\r'; break;
                case 't': b = '\t'; break;
                case '"': b = '"'; break;
                case '\\': b = '\\'; break;
                case '/': b = '/'; break;
                case 'u': {
                    uint32_t codepoint;
                    const char *err = decode_utf16_escape(cp + 1, &codepoint);
                    if (err) return err;
                    if (codepoint >= 0xDC00 && codepoint <= 0xDFFF) {
                        return "unexpected utf-16 low surrogate";
                    } else if (codepoint >= 0xD800 && codepoint <= 0xDBFF) {
                        if (cp[5] != '\\') return "expected utf-16 low surrogate pair";
                        if (cp[6] != 'u') return "expected utf-16 low surrogate pair";
                        uint32_t lowsur;
                        const char *err2 = decode_utf16_escape(cp + 7, &lowsur);
                        if (err2) return err2;
                        if (lowsur < 0xDC00 || lowsur > 0xDFFF)
                            return "expected utf-16 low surrogate pair";
                        codepoint = ((codepoint - 0xD800) << 10) + (lowsur - 0xDC00) + 0x10000;
                        cp += 11;
                    } else {
                        cp += 5;
                    }
                    if (codepoint <= 0x7F) {
                        janet_buffer_push_u8(buffer, codepoint);
                    } else if (codepoint <= 0x7FF) {
                        janet_buffer_push_u8(buffer, ((codepoint >> 6) & 0x1F) | 0xC0);
                        janet_buffer_push_u8(buffer, ((codepoint >> 0) & 0x3F) | 0x80);
                    } else if (codepoint <= 0xFFFF) {
                        janet_buffer_push_u8(buffer, ((codepoint >> 12) & 0x0F) | 0xE0);
                        janet_buffer_push_u8(buffer, ((codepoint >> 6) & 0x3F) | 0x80);
                        janet_buffer_push_u8(buffer, ((codepoint >> 0) & 0x3F) | 0x80);
                    } else {
                        janet_buffer_push_u8(buffer, ((codepoint >> 18) & 0x07) | 0xF0);
                        janet_buffer_push_u8(buffer, ((codepoint >> 12) & 0x3F) | 0x80);
                        janet_buffer_push_u8(buffer, ((codepoint >> 6) & 0x3F) | 0x80);
                        janet_buffer_push_u8(buffer, ((codepoint >> 0) & 0x3F) | 0x80);
                    }
                }
                    continue;
            }
        }
        janet_buffer_push_u8(buffer, b);
        cp++;
    }
    *out = janet_stringv(buffer->data, buffer->count);
    *p = cp + 1;
    return NULL;
}

static const char *decode_one(const char **p, Janet *out, int depth) {
    /* Prevent stack overflow */
    if ((depth & 0xFFFF) > JANET_RECURSION_GUARD) goto recurdepth;

    skipwhite(p);

    switch (**p) {
        default:
            goto badchar;
        case '\0':
            goto eos;
        case '-': case '0': case '1': case '2': case '3': case '4':
        case '5': case '6': case '7': case '8': case '9': {
            errno = 0;
            char *end = NULL;
            double x = strtod(*p, &end);
            if (end == *p) goto badnum;
            *p = end;
            *out = janet_wrap_number(x);
            break;
        }
        case 'f': {
            const char *cp = *p;
            if (cp[1] != 'a' || cp[2] != 'l' || cp[3] != 's' || cp[4] != 'e') goto badident;
            *out = janet_wrap_false();
            *p = cp + 5;
            break;
        }
        case 'n': {
            const char *cp = *p;
            if (cp[1] != 'u' || cp[2] != 'l' || cp[3] != 'l') goto badident;
            if (depth & JSON_NULL_TO_NIL) {
                *out = janet_wrap_nil();
            } else {
                *out = janet_ckeywordv("null");
            }
            *p = cp + 4;
            break;
        }
        case 't': {
            const char *cp = *p;
            if (cp[1] != 'r' || cp[2] != 'u' || cp[3] != 'e') goto badident;
            *out = janet_wrap_true();
            *p = cp + 4;
            break;
        }
        case '"': {
            const char *cp = *p + 1;
            const char *start = cp;
            while ((*cp >= 32 || *cp < 0) && *cp != '"' && *cp != '\\') cp++;
            /* Only a string with escapes needs a buffer */
            if (*cp == '\\') {
                *p = *p + 1;
                const char *err = decode_string(p, out);
                if (err) return err;
                break;
            }
            if (*cp != '"') goto badchar;
            *p = cp + 1;
            *out = janet_stringv((const uint8_t *) start, cp - start);
            break;
        }
        case '[': {
            *p = *p + 1;
            JanetArray *array = janet_array(0);
            const char *err;
            Janet subval;
            skipwhite(p);
            while (**p != ']') {
                err = decode_one(p, &subval, depth + 1);
                if (err) return err;
                janet_array_push(array, subval);
                skipwhite(p);
                if (**p == ']') break;
                if (**p != ',') goto wantcomma;
                *p = *p + 1;
            }
            *p = *p + 1;
            *out = janet_wrap_array(array);
        } break;
        case '{': {
            *p = *p + 1;
            Omap *map = omap_create(0);
            const char *err;
            Janet subkey, subval;
            skipwhite(p);
            while (**p != '}') {
                skipwhite(p);
                if (**p != '"') goto wantstring;
                err = decode_one(p, &subkey, depth + 1);
                if (err) return err;
                skipwhite(p);
                if (**p != ':') goto wantcolon;
                *p = *p + 1;
                err = decode_one(p, &subval, depth + 1);
                if (err) return err;
                if (depth & JSON_KEYWORD_KEY) {
                    JanetString str = janet_unwrap_string(subkey);
                    subkey = janet_keywordv(str, janet_string_length(str));
                }
                /* As on a table, a nil value (a null with nils) removes the key. */
                omap_put(map, subkey, subval);
                skipwhite(p);
                if (**p == '}') break;
                if (**p != ',') goto wantcomma;
                *p = *p + 1;
            }
            *p = *p + 1;
            *out = janet_wrap_abstract(map);
            break;
        }
    }
    return NULL;

recurdepth:
    return "recursed too deeply";
eos:
    return "unexpected end of source";
badident:
    return "bad identifier";
badnum:
    return "bad number";
wantcomma:
    return "expected comma";
wantcolon:
    return "expected colon";
badchar:
    return "unexpected character";
wantstring:
    return "expected json string";
}

JANET_FN(json_omap_decode, "(json-omap/decode json-source &opt keywords nils)",
         "Decodes JSON as spork/json does, except that every object becomes an "
         "ordered map (see the omap module) holding its keys in the order they "
         "are written. Not for calling directly: json/decode takes it as its "
         "ordered argument.") {
    janet_arity(argc, 1, 3);
    Janet ret = janet_wrap_nil();
    const char *err;
    const char *start;
    const char *p;
    if (janet_checktype(argv[0], JANET_BUFFER)) {
        JanetBuffer *buffer = janet_unwrap_buffer(argv[0]);
        /* Ensure 0 padded */
        janet_buffer_push_u8(buffer, 0);
        buffer->count--;
        start = p = (const char *) buffer->data;
    } else {
        JanetByteView bytes = janet_getbytes(argv, 0);
        start = p = (const char *) bytes.bytes;
    }
    int flags = 0;
    if (argc > 1 && janet_truthy(argv[1])) flags |= JSON_KEYWORD_KEY;
    if (argc > 2 && janet_truthy(argv[2])) flags |= JSON_NULL_TO_NIL;
    err = decode_one(&p, &ret, flags);
    if (!err) {
        skipwhite(&p);
        if (*p) err = "unexpected extra token";
    }
    if (err) janet_panicf("decode error at position %d: %s", (int) (p - start), err);
    return ret;
}

JANET_MODULE_ENTRY(JanetTable *env) {
    static const JanetRegExt cfuns[] = {
        JANET_REG("decode", json_omap_decode),
        JANET_REG_END};
    janet_cfuns_ext(env, "json-omap", cfuns);
}
