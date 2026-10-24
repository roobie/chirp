/* chirp's yaml module: libyaml's parser and emitter events turned into Janet
 * values and back. libyaml only tokenises scalars, so the YAML 1.2 Core schema
 * (what a plain scalar means) is resolved here.
 *
 * Failures never longjmp while libyaml owns memory: every step returns 0 after
 * writing a message, the caller frees libyaml's state, then raises the error. */

#include <janet.h>
#include <yaml.h>

#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_DEPTH 512
#define MAX_ALIAS_NODES 1000000
#define ERR_LEN 512
#define TAG_PREFIX "tag:yaml.org,2002:"

/* Core schema resolution */

typedef enum { K_STR, K_NULL, K_TRUE, K_FALSE, K_INT, K_FLOAT } Kind;

static int word_is(const uint8_t *s, size_t n, const char *a, const char *b,
                   const char *c) {
    return (n == strlen(a) && memcmp(s, a, n) == 0) ||
           (n == strlen(b) && memcmp(s, b, n) == 0) ||
           (n == strlen(c) && memcmp(s, c, n) == 0);
}

static int is_digit(uint8_t c) { return c >= '0' && c <= '9'; }

static int digit_value(uint8_t c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

/* strtod needs a terminated string; the text was already checked to be a number. */
static double to_double(const uint8_t *s, size_t n) {
    char *buf = janet_smalloc(n + 1);
    memcpy(buf, s, n);
    buf[n] = 0;
    double v = strtod(buf, NULL);
    janet_sfree(buf);
    return v;
}

/* What a plain scalar resolves to. num is set for K_INT and K_FLOAT, and may be
 * NULL when only the kind matters. */
static Kind classify(const uint8_t *s, size_t n, double *num) {
    double scratch;
    if (!num) num = &scratch;
    if (n == 0) return K_NULL;
    if (n == 1 && s[0] == '~') return K_NULL;
    if (word_is(s, n, "null", "Null", "NULL")) return K_NULL;
    if (word_is(s, n, "true", "True", "TRUE")) return K_TRUE;
    if (word_is(s, n, "false", "False", "FALSE")) return K_FALSE;
    if (word_is(s, n, ".nan", ".NaN", ".NAN")) {
        *num = NAN;
        return K_FLOAT;
    }
    size_t i = 0;
    int neg = 0;
    if (s[0] == '+' || s[0] == '-') {
        neg = s[0] == '-';
        i = 1;
    }
    if (word_is(s + i, n - i, ".inf", ".Inf", ".INF")) {
        *num = neg ? -INFINITY : INFINITY;
        return K_FLOAT;
    }
    if (i == 0 && n > 2 && s[0] == '0' && (s[1] == 'o' || s[1] == 'x')) {
        int base = s[1] == 'o' ? 8 : 16;
        double v = 0;
        int ok = 1;
        for (size_t k = 2; k < n; k++) {
            int d = digit_value(s[k]);
            if (d < 0 || d >= base) {
                ok = 0;
                break;
            }
            v = v * base + d;
        }
        if (ok) {
            *num = v;
            return K_INT;
        }
        return K_STR;
    }
    size_t j = i;
    while (j < n && is_digit(s[j])) j++;
    size_t int_digits = j - i;
    if (int_digits > 0 && j == n) {
        *num = to_double(s, n);
        if (*num == 0) *num = 0; /* "-0" is the integer zero */
        return K_INT;
    }
    size_t k = j, frac_digits = 0;
    if (k < n && s[k] == '.') {
        k++;
        while (k < n && is_digit(s[k])) {
            k++;
            frac_digits++;
        }
    }
    if (int_digits == 0 && frac_digits == 0) return K_STR;
    if (k < n && (s[k] == 'e' || s[k] == 'E')) {
        k++;
        if (k < n && (s[k] == '+' || s[k] == '-')) k++;
        size_t exp_digits = 0;
        while (k < n && is_digit(s[k])) {
            k++;
            exp_digits++;
        }
        if (exp_digits == 0) return K_STR;
    }
    if (k != n) return K_STR;
    *num = to_double(s, n);
    return K_FLOAT;
}

/* Decoding */

typedef struct {
    yaml_parser_t parser;
    JanetTable *anchors; /* name -> 1-tuple holding the value, as a value may be nil */
    int keywords, nils;
    long alias_nodes;
    char err[ERR_LEN];
} Dec;

static int dec_fail(Dec *d, yaml_mark_t m, const char *fmt, ...) {
    char msg[ERR_LEN - 64];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(msg, sizeof msg, fmt, ap);
    va_end(ap);
    snprintf(d->err, ERR_LEN, "%s at line %lu, column %lu", msg,
             (unsigned long) m.line + 1, (unsigned long) m.column + 1);
    return 0;
}

static int next_event(Dec *d, yaml_event_t *ev) {
    if (yaml_parser_parse(&d->parser, ev)) return 1;
    yaml_parser_t *p = &d->parser;
    const char *problem = p->problem ? p->problem : "invalid YAML";
    if (p->error == YAML_READER_ERROR) {
        snprintf(d->err, ERR_LEN, "%s at byte offset %lu", problem,
                 (unsigned long) p->problem_offset);
    } else if (p->context) {
        snprintf(d->err, ERR_LEN, "%s at line %lu, column %lu (%s at line %lu)", problem,
                 (unsigned long) p->problem_mark.line + 1,
                 (unsigned long) p->problem_mark.column + 1, p->context,
                 (unsigned long) p->context_mark.line + 1);
    } else {
        snprintf(d->err, ERR_LEN, "%s at line %lu, column %lu", problem,
                 (unsigned long) p->problem_mark.line + 1,
                 (unsigned long) p->problem_mark.column + 1);
    }
    return 0;
}

static Janet null_value(Dec *d) {
    return d->nils ? janet_wrap_nil() : janet_ckeywordv("null");
}

/* An alias is a private copy, so a decoded document is always a tree. Each node
 * copied counts against the cap, which is what stops an alias bomb. */
static int copy_value(Dec *d, Janet v, int depth, yaml_mark_t m, Janet *out) {
    if (++d->alias_nodes > MAX_ALIAS_NODES)
        return dec_fail(d, m, "aliases expand to more than %d nodes", MAX_ALIAS_NODES);
    if (depth > MAX_DEPTH)
        return dec_fail(d, m, "nesting is deeper than %d levels", MAX_DEPTH);
    switch (janet_type(v)) {
        case JANET_ARRAY: {
            JanetArray *a = janet_unwrap_array(v);
            JanetArray *c = janet_array(a->count);
            for (int32_t i = 0; i < a->count; i++) {
                Janet e;
                if (!copy_value(d, a->data[i], depth + 1, m, &e)) return 0;
                janet_array_push(c, e);
            }
            *out = janet_wrap_array(c);
            return 1;
        }
        case JANET_TABLE: {
            JanetTable *t = janet_unwrap_table(v);
            JanetTable *c = janet_table(t->count);
            for (int32_t i = 0; i < t->capacity; i++) {
                JanetKV *kv = t->data + i;
                if (janet_checktype(kv->key, JANET_NIL)) continue;
                Janet e;
                if (!copy_value(d, kv->value, depth + 1, m, &e)) return 0;
                janet_table_put(c, kv->key, e);
            }
            *out = janet_wrap_table(c);
            return 1;
        }
        default:
            *out = v;
            return 1;
    }
}

static int tag_suffix(const char *tag, const char **suffix) {
    size_t n = strlen(TAG_PREFIX);
    if (strncmp(tag, TAG_PREFIX, n) != 0) return 0;
    *suffix = tag + n;
    return 1;
}

/* Only the YAML core tags are understood. A collection accepts its own tag. */
static int check_collection_tag(Dec *d, yaml_mark_t m, const char *tag, const char *want) {
    const char *suffix;
    if (!tag || strcmp(tag, "!") == 0) return 1;
    if (tag_suffix(tag, &suffix)) {
        if (strcmp(suffix, want) == 0) return 1;
        if (strcmp(suffix, "str") == 0 || strcmp(suffix, "int") == 0 ||
            strcmp(suffix, "float") == 0 || strcmp(suffix, "bool") == 0 ||
            strcmp(suffix, "null") == 0 || strcmp(suffix, "map") == 0 ||
            strcmp(suffix, "seq") == 0)
            return dec_fail(d, m, "tag !!%s does not fit a %s", suffix,
                            strcmp(want, "map") == 0 ? "mapping" : "sequence");
    }
    return dec_fail(d, m, "unsupported tag \"%s\"", tag);
}

static int scalar_value(Dec *d, yaml_event_t *ev, Janet *out) {
    const uint8_t *s = ev->data.scalar.value;
    size_t n = ev->data.scalar.length;
    const char *tag = (const char *) ev->data.scalar.tag;
    yaml_mark_t m = ev->start_mark;
    const char *suffix = NULL;
    int force_str = 0;
    if (tag) {
        if (strcmp(tag, "!") == 0) {
            force_str = 1;
        } else if (tag_suffix(tag, &suffix)) {
            if (strcmp(suffix, "str") == 0) force_str = 1;
            else if (strcmp(suffix, "map") == 0 || strcmp(suffix, "seq") == 0)
                return dec_fail(d, m, "tag !!%s does not fit a scalar", suffix);
            else if (strcmp(suffix, "null") && strcmp(suffix, "bool") &&
                     strcmp(suffix, "int") && strcmp(suffix, "float"))
                return dec_fail(d, m, "unsupported tag \"%s\"", tag);
        } else {
            return dec_fail(d, m, "unsupported tag \"%s\"", tag);
        }
    }
    double num = 0;
    Kind k = K_STR;
    if (!force_str && (suffix || ev->data.scalar.style == YAML_PLAIN_SCALAR_STYLE)) {
        k = classify(s, n, &num);
        if (suffix) {
            int ok = (!strcmp(suffix, "null") && k == K_NULL) ||
                     (!strcmp(suffix, "bool") && (k == K_TRUE || k == K_FALSE)) ||
                     (!strcmp(suffix, "int") && k == K_INT) ||
                     (!strcmp(suffix, "float") && (k == K_FLOAT || k == K_INT));
            if (!ok)
                return dec_fail(d, m, "cannot read \"%s\" as !!%s", (const char *) s, suffix);
        }
    }
    switch (k) {
        case K_NULL: *out = null_value(d); break;
        case K_TRUE: *out = janet_wrap_true(); break;
        case K_FALSE: *out = janet_wrap_false(); break;
        case K_INT:
        case K_FLOAT: *out = janet_wrap_number_safe(num); break;
        default: *out = janet_wrap_string(janet_string(s, (int32_t) n)); break;
    }
    return 1;
}

static int node(Dec *d, yaml_event_t *ev, int depth, Janet *out);

static int sequence_value(Dec *d, int depth, Janet *out) {
    JanetArray *arr = janet_array(0);
    for (;;) {
        yaml_event_t ev;
        if (!next_event(d, &ev)) return 0;
        if (ev.type == YAML_SEQUENCE_END_EVENT) {
            yaml_event_delete(&ev);
            break;
        }
        Janet item;
        if (!node(d, &ev, depth + 1, &item)) return 0;
        janet_array_push(arr, item);
    }
    *out = janet_wrap_array(arr);
    return 1;
}

static int is_merge_key(const yaml_event_t *ev) {
    return ev->type == YAML_SCALAR_EVENT && ev->data.scalar.style == YAML_PLAIN_SCALAR_STYLE &&
           !ev->data.scalar.tag && ev->data.scalar.length == 2 &&
           memcmp(ev->data.scalar.value, "<<", 2) == 0;
}

static int mapping_value(Dec *d, int depth, Janet *out) {
    JanetTable *t = janet_table(0);
    JanetTable *seen = janet_table(0); /* keys, so duplicates are found even when the value is nil */
    JanetArray *merges = janet_array(0);
    for (;;) {
        yaml_event_t ev;
        if (!next_event(d, &ev)) return 0;
        if (ev.type == YAML_MAPPING_END_EVENT) {
            yaml_event_delete(&ev);
            break;
        }
        yaml_mark_t km = ev.start_mark;
        if (is_merge_key(&ev)) {
            yaml_event_delete(&ev);
            Janet mv;
            if (!next_event(d, &ev) || !node(d, &ev, depth + 1, &mv)) return 0;
            if (janet_checktype(mv, JANET_TABLE)) {
                janet_array_push(merges, mv);
            } else if (janet_checktype(mv, JANET_ARRAY)) {
                JanetArray *list = janet_unwrap_array(mv);
                for (int32_t i = 0; i < list->count; i++) {
                    if (!janet_checktype(list->data[i], JANET_TABLE))
                        return dec_fail(d, km, "merge key needs a mapping or a sequence of mappings");
                    janet_array_push(merges, list->data[i]);
                }
            } else {
                return dec_fail(d, km, "merge key needs a mapping or a sequence of mappings");
            }
            continue;
        }
        Janet key;
        if (!node(d, &ev, depth + 1, &key)) return 0;
        if (janet_checktypes(key, JANET_TFLAG_ARRAY | JANET_TFLAG_TABLE))
            return dec_fail(d, km, "mapping keys must be scalars");
        if (janet_checktype(key, JANET_NIL) ||
            (janet_checktype(key, JANET_NUMBER) && isnan(janet_unwrap_number(key))))
            return dec_fail(d, km, "this mapping key cannot be used in a table");
        if (d->keywords && janet_checktype(key, JANET_STRING)) {
            JanetString ks = janet_unwrap_string(key);
            key = janet_keywordv(ks, janet_string_length(ks));
        }
        Janet val;
        if (!next_event(d, &ev) || !node(d, &ev, depth + 1, &val)) return 0;
        if (!janet_checktype(janet_table_get(seen, key), JANET_NIL))
            return dec_fail(d, km, "duplicate mapping key %s",
                            (const char *) janet_description(key));
        janet_table_put(seen, key, janet_wrap_true());
        janet_table_put(t, key, val);
    }
    /* Merged entries fill only keys the mapping and earlier sources lack. */
    for (int32_t i = 0; i < merges->count; i++) {
        JanetTable *src = janet_unwrap_table(merges->data[i]);
        for (int32_t j = 0; j < src->capacity; j++) {
            JanetKV *kv = src->data + j;
            if (janet_checktype(kv->key, JANET_NIL)) continue;
            if (!janet_checktype(janet_table_get(seen, kv->key), JANET_NIL)) continue;
            janet_table_put(seen, kv->key, janet_wrap_true());
            janet_table_put(t, kv->key, kv->value);
        }
    }
    *out = janet_wrap_table(t);
    return 1;
}

static int node_inner(Dec *d, yaml_event_t *ev, int depth, Janet *out) {
    yaml_mark_t m = ev->start_mark;
    if (depth > MAX_DEPTH)
        return dec_fail(d, m, "nesting is deeper than %d levels", MAX_DEPTH);
    const uint8_t *anchor = NULL;
    Janet v;
    switch (ev->type) {
        case YAML_ALIAS_EVENT: {
            Janet found = janet_table_get(d->anchors,
                                          janet_cstringv((const char *) ev->data.alias.anchor));
            if (janet_checktype(found, JANET_NIL))
                return dec_fail(d, m, "unknown anchor \"%s\"", (const char *) ev->data.alias.anchor);
            return copy_value(d, janet_unwrap_tuple(found)[0], depth, m, out);
        }
        case YAML_SCALAR_EVENT:
            anchor = ev->data.scalar.anchor;
            if (!scalar_value(d, ev, &v)) return 0;
            break;
        case YAML_SEQUENCE_START_EVENT:
            anchor = ev->data.sequence_start.anchor;
            if (!check_collection_tag(d, m, (const char *) ev->data.sequence_start.tag, "seq") ||
                !sequence_value(d, depth, &v))
                return 0;
            break;
        case YAML_MAPPING_START_EVENT:
            anchor = ev->data.mapping_start.anchor;
            if (!check_collection_tag(d, m, (const char *) ev->data.mapping_start.tag, "map") ||
                !mapping_value(d, depth, &v))
                return 0;
            break;
        default:
            return dec_fail(d, m, "unexpected YAML event");
    }
    if (anchor) {
        /* Registered once complete, so an anchor cannot contain itself. */
        janet_table_put(d->anchors, janet_cstringv((const char *) anchor),
                        janet_wrap_tuple(janet_tuple_n(&v, 1)));
    }
    *out = v;
    return 1;
}

/* Takes ownership of ev. */
static int node(Dec *d, yaml_event_t *ev, int depth, Janet *out) {
    int ok = node_inner(d, ev, depth, out);
    yaml_event_delete(ev);
    return ok;
}

static int read_stream(Dec *d, int all, JanetArray *docs, Janet *single) {
    yaml_event_t ev;
    if (!next_event(d, &ev)) return 0;
    yaml_event_delete(&ev); /* stream start */
    int count = 0;
    for (;;) {
        if (!next_event(d, &ev)) return 0;
        if (ev.type == YAML_STREAM_END_EVENT) {
            yaml_event_delete(&ev);
            break;
        }
        if (!all && count == 1) {
            dec_fail(d, ev.start_mark, "the stream has more than one document, use yaml/decode-all");
            yaml_event_delete(&ev);
            return 0;
        }
        yaml_event_delete(&ev); /* document start */
        janet_table_clear(d->anchors);
        Janet v;
        if (!next_event(d, &ev) || !node(d, &ev, 0, &v)) return 0;
        if (!next_event(d, &ev)) return 0;
        yaml_event_delete(&ev); /* document end */
        count++;
        if (all) janet_array_push(docs, v);
        else *single = v;
    }
    if (!all && count == 0) *single = null_value(d);
    return 1;
}

static Janet decode_impl(int32_t argc, Janet *argv, int all) {
    janet_arity(argc, 1, 3);
    JanetByteView src = janet_getbytes(argv, 0);
    Dec d;
    memset(&d, 0, sizeof d);
    d.keywords = argc > 1 && janet_truthy(argv[1]);
    d.nils = argc > 2 && janet_truthy(argv[2]);
    d.anchors = janet_table(0);
    if (!yaml_parser_initialize(&d.parser)) janet_panic("yaml: out of memory");
    yaml_parser_set_input_string(&d.parser, src.bytes, (size_t) src.len);
    JanetArray *docs = all ? janet_array(0) : NULL;
    Janet single = janet_wrap_nil();
    int ok = read_stream(&d, all, docs, &single);
    yaml_parser_delete(&d.parser);
    if (!ok) {
        char msg[ERR_LEN + 8];
        snprintf(msg, sizeof msg, "yaml: %s", d.err);
        janet_panic(msg);
    }
    return all ? janet_wrap_array(docs) : single;
}

JANET_FN(cfun_decode, "(yaml/decode src &opt keywords nils)",
         "Returns a Janet value after parsing one YAML document. Mappings become "
         "tables and sequences become arrays. If keywords is truthy, string keys "
         "will be converted to keywords. Null becomes the keyword :null, as in "
         "spork/json; if nils is truthy it becomes nil instead, and a mapping "
         "entry whose value is null is then left out, because a table cannot "
         "hold nil.\n\n"
         "Plain scalars follow the YAML 1.2 Core schema: null (~, null, Null, "
         "NULL, or empty), true and false in three spellings (so yes, no, on and "
         "off stay strings), integers (decimal, 0o octal, 0x hex) and floats "
         "(1.5, 1e3, .inf, -.inf, .nan). Integers are Janet numbers, so those "
         "beyond 2^53 lose precision. Quoted and block scalars are always "
         "strings. The tags !!str, !!int, !!float, !!bool, !!null, !!map and "
         "!!seq are honoured; any other tag is an error.\n\n"
         "Anchors and aliases work, and so does the << merge key, with a mapping "
         "or a sequence of mappings, where the mapping's own keys win and then "
         "earlier sources. Every alias is expanded into a copy, and an input "
         "whose aliases expand to more than 1,000,000 nodes in total is an "
         "error, as is nesting deeper than 512 levels. A duplicate key in a "
         "mapping is an error. A stream with more than one document is an "
         "error; use yaml/decode-all. An empty stream is null.\n\n"
         "Errors carry libyaml's message with the line and column.") {
    return decode_impl(argc, argv, 0);
}

JANET_FN(cfun_decode_all, "(yaml/decode-all src &opt keywords nils)",
         "Returns an array with every document in the YAML stream src, each "
         "decoded as by yaml/decode, which also describes keywords and nils. "
         "Aliases are cut off at the same total of 1,000,000 expanded nodes for "
         "the whole stream. An empty stream gives an empty array.") {
    return decode_impl(argc, argv, 1);
}

/* Encoding */

typedef struct {
    yaml_emitter_t em;
    char err[ERR_LEN];
} Enc;

static int enc_fail(Enc *e, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(e->err, ERR_LEN, fmt, ap);
    va_end(ap);
    return 0;
}

static int emit(Enc *e, yaml_event_t *ev) {
    if (yaml_emitter_emit(&e->em, ev)) return 1;
    return enc_fail(e, "%s", e->em.problem ? e->em.problem : "emitter error");
}

/* The shortest text that reads back as the same number. Integral values print
 * without a fraction. */
static void format_number(double x, char *buf) {
    if (isnan(x)) {
        strcpy(buf, ".nan");
    } else if (isinf(x)) {
        strcpy(buf, x < 0 ? "-.inf" : ".inf");
    } else if (x == 0 && signbit(x)) {
        strcpy(buf, "-0.0");
    } else if (x == floor(x) && fabs(x) < 9007199254740992.0) {
        snprintf(buf, 40, "%lld", (long long) x);
    } else {
        for (int prec = 1; prec <= 17; prec++) {
            snprintf(buf, 40, "%.*g", prec, x);
            if (strtod(buf, NULL) == x) break;
        }
    }
}

static int is_yaml11_bool(const uint8_t *s, size_t n) {
    return word_is(s, n, "yes", "Yes", "YES") || word_is(s, n, "no", "No", "NO") ||
           word_is(s, n, "on", "On", "ON") || word_is(s, n, "off", "Off", "OFF") ||
           (n == 1 && (s[0] == 'y' || s[0] == 'Y' || s[0] == 'n' || s[0] == 'N'));
}

typedef struct {
    const uint8_t *p;
    size_t n;
    char num[40];
    yaml_scalar_style_t style;
} Sc;

/* Describes a value as a scalar. Returns 0 for anything that is not one. A key
 * never gets a block style, as a block scalar cannot be a simple key. */
static int describe(Janet v, int is_key, Sc *sc) {
    sc->style = YAML_PLAIN_SCALAR_STYLE;
    switch (janet_type(v)) {
        case JANET_NIL:
            sc->p = (const uint8_t *) "null";
            sc->n = 4;
            return 1;
        case JANET_BOOLEAN:
            sc->p = (const uint8_t *) (janet_unwrap_boolean(v) ? "true" : "false");
            sc->n = strlen((const char *) sc->p);
            return 1;
        case JANET_NUMBER:
            format_number(janet_unwrap_number(v), sc->num);
            sc->p = (const uint8_t *) sc->num;
            sc->n = strlen(sc->num);
            return 1;
        case JANET_STRING:
        case JANET_BUFFER:
        case JANET_SYMBOL:
        case JANET_KEYWORD: {
            const uint8_t *p;
            int32_t n;
            janet_bytes_view(v, &p, &n);
            sc->p = p;
            sc->n = (size_t) n;
            if (janet_checktype(v, JANET_KEYWORD) && n == 4 && memcmp(p, "null", 4) == 0)
                return 1;
            /* Text a reader would take for something else, or for a merge key.
             * YAML 1.1 readers, which are common, also take yes and no for booleans. */
            if (classify(p, sc->n, NULL) != K_STR || is_yaml11_bool(p, sc->n) ||
                (n == 2 && memcmp(p, "<<", 2) == 0))
                sc->style = YAML_SINGLE_QUOTED_SCALAR_STYLE;
            else if (memchr(p, '\n', sc->n))
                sc->style = is_key ? YAML_DOUBLE_QUOTED_SCALAR_STYLE : YAML_LITERAL_SCALAR_STYLE;
            return 1;
        }
        default:
            return 0;
    }
}

static int emit_scalar(Enc *e, const Sc *sc) {
    yaml_event_t ev;
    if (!yaml_scalar_event_initialize(&ev, NULL, NULL, (yaml_char_t *) sc->p, (int) sc->n,
                                      1, 1, sc->style))
        return enc_fail(e, "cannot encode a string that is not valid UTF-8");
    return emit(e, &ev);
}

typedef struct {
    Janet key, value;
    Sc sc;
} Pair;

static int compare_pairs(const void *a, const void *b) {
    const Pair *x = *(Pair *const *) a, *y = *(Pair *const *) b;
    size_t m = x->sc.n < y->sc.n ? x->sc.n : y->sc.n;
    int c = memcmp(x->sc.p, y->sc.p, m);
    if (c) return c;
    if (x->sc.n != y->sc.n) return x->sc.n < y->sc.n ? -1 : 1;
    return (int) x->sc.style - (int) y->sc.style;
}

static int encode_value(Enc *e, Janet v, int depth);

static int encode_sequence(Enc *e, Janet v, int depth) {
    const Janet *items;
    int32_t len;
    janet_indexed_view(v, &items, &len);
    yaml_event_t ev;
    if (!yaml_sequence_start_event_initialize(&ev, NULL, NULL, 1, YAML_BLOCK_SEQUENCE_STYLE) ||
        !emit(e, &ev))
        return 0;
    for (int32_t i = 0; i < len; i++)
        if (!encode_value(e, items[i], depth + 1)) return 0;
    if (!yaml_sequence_end_event_initialize(&ev)) return enc_fail(e, "out of memory");
    return emit(e, &ev);
}

static int encode_mapping(Enc *e, Janet v, int depth) {
    const JanetKV *kvs;
    int32_t len, cap;
    janet_dictionary_view(v, &kvs, &len, &cap);
    Pair *pairs = janet_smalloc(sizeof(Pair) * (size_t) (len + 1));
    Pair **order = janet_smalloc(sizeof(Pair *) * (size_t) (len + 1));
    int32_t n = 0, ok = 1;
    for (int32_t i = 0; i < cap && ok; i++) {
        if (janet_checktype(kvs[i].key, JANET_NIL)) continue;
        Pair *p = &pairs[n];
        p->key = kvs[i].key;
        p->value = kvs[i].value;
        if (!describe(p->key, 1, &p->sc)) {
            ok = enc_fail(e, "cannot use a %s as a mapping key",
                          janet_type_names[janet_type(p->key)]);
            break;
        }
        order[n] = p;
        n++;
    }
    if (ok) {
        qsort(order, (size_t) n, sizeof(Pair *), compare_pairs);
        for (int32_t i = 1; i < n && ok; i++) {
            if (compare_pairs(&order[i - 1], &order[i]) == 0)
                ok = enc_fail(e, "two keys of the mapping encode to the same text");
        }
    }
    yaml_event_t ev;
    ok = ok && yaml_mapping_start_event_initialize(&ev, NULL, NULL, 1, YAML_BLOCK_MAPPING_STYLE) &&
         emit(e, &ev);
    for (int32_t i = 0; i < n && ok; i++) {
        ok = emit_scalar(e, &order[i]->sc) && encode_value(e, order[i]->value, depth + 1);
    }
    if (ok) ok = yaml_mapping_end_event_initialize(&ev) ? emit(e, &ev) : enc_fail(e, "out of memory");
    janet_sfree(order);
    janet_sfree(pairs);
    return ok;
}

static int encode_value(Enc *e, Janet v, int depth) {
    if (depth > MAX_DEPTH) return enc_fail(e, "nesting is deeper than %d levels", MAX_DEPTH);
    switch (janet_type(v)) {
        case JANET_ARRAY:
        case JANET_TUPLE:
            return encode_sequence(e, v, depth);
        case JANET_TABLE:
        case JANET_STRUCT:
            return encode_mapping(e, v, depth);
        default: {
            Sc sc;
            if (!describe(v, 0, &sc))
                return enc_fail(e, "cannot encode a %s", janet_type_names[janet_type(v)]);
            return emit_scalar(e, &sc);
        }
    }
}

static int write_handler(void *data, unsigned char *buf, size_t size) {
    janet_buffer_push_bytes((JanetBuffer *) data, buf, (int32_t) size);
    return 1;
}

static int write_stream(Enc *e, Janet v) {
    yaml_event_t ev;
    if (!yaml_stream_start_event_initialize(&ev, YAML_UTF8_ENCODING) || !emit(e, &ev)) return 0;
    if (!yaml_document_start_event_initialize(&ev, NULL, NULL, NULL, 1) || !emit(e, &ev)) return 0;
    if (!encode_value(e, v, 0)) return 0;
    if (!yaml_document_end_event_initialize(&ev, 1) || !emit(e, &ev)) return 0;
    if (!yaml_stream_end_event_initialize(&ev) || !emit(e, &ev)) return 0;
    return 1;
}

JANET_FN(cfun_encode, "(yaml/encode x &opt opts)",
         "Encodes a Janet value as a YAML document (utf-8) and returns it in a "
         "new buffer. Tables and structs become block mappings with their keys "
         "sorted, so the same value always gives the same text. Arrays and "
         "tuples become block sequences. Strings, buffers, keywords and symbols "
         "become strings, quoted when a reader would take them for something "
         "else (true, null, 1.5, ~, the empty string, and yes and no, which "
         "YAML 1.1 readers take for booleans) and as a literal block "
         "when they hold a newline. Numbers print without .0 when integral. "
         "Booleans print as true and false, and nil and :null as null. Any other "
         "value is an error.\n\n"
         "opts is a table or struct. :indent sets the indentation, 2 to 9 "
         "spaces, 2 by default.") {
    janet_arity(argc, 1, 2);
    int indent = 2;
    if (argc > 1 && !janet_checktype(argv[1], JANET_NIL)) {
        const JanetKV *kvs;
        int32_t len, cap;
        if (!janet_dictionary_view(argv[1], &kvs, &len, &cap))
            janet_panic("yaml: opts must be a table or a struct");
        Janet iv = janet_dictionary_get(kvs, cap, janet_ckeywordv("indent"));
        if (!janet_checktype(iv, JANET_NIL)) {
            if (!janet_checkint(iv) || janet_unwrap_integer(iv) < 2 || janet_unwrap_integer(iv) > 9)
                janet_panic("yaml: :indent must be an integer from 2 to 9");
            indent = janet_unwrap_integer(iv);
        }
    }
    JanetBuffer *buf = janet_buffer(256);
    Enc e;
    memset(&e, 0, sizeof e);
    if (!yaml_emitter_initialize(&e.em)) janet_panic("yaml: out of memory");
    yaml_emitter_set_output(&e.em, write_handler, buf);
    yaml_emitter_set_unicode(&e.em, 1);
    yaml_emitter_set_width(&e.em, -1); /* never fold a long scalar over lines */
    yaml_emitter_set_indent(&e.em, indent);
    int ok = write_stream(&e, argv[0]);
    yaml_emitter_delete(&e.em);
    if (!ok) {
        char msg[ERR_LEN + 8];
        snprintf(msg, sizeof msg, "yaml: %s", e.err);
        janet_panic(msg);
    }
    return janet_wrap_buffer(buf);
}

JANET_MODULE_ENTRY(JanetTable *env) {
    static const JanetRegExt cfuns[] = {
        JANET_REG("decode", cfun_decode),
        JANET_REG("decode-all", cfun_decode_all),
        JANET_REG("encode", cfun_encode),
        JANET_REG_END};
    janet_cfuns_ext(env, "yaml", cfuns);
}
