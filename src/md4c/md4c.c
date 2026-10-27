/* chirp's md4c module: Markdown rendered to HTML by md4c's md_html.
 *
 * The output callback runs inside md4c's frames while md4c owns memory, so it
 * never raises: it only appends to a buffer, and stops appending once the
 * output would not fit in a Janet buffer. The error is raised after md_html
 * has returned and freed its state. */

#include <janet.h>
#include <md4c-html.h>

#include <stdint.h>
#include <string.h>

/* Options. A true value turns a flag on, false or nil turns it off, so
 * {:github true :footnotes false} is GitHub's dialect without footnotes.
 * Unknown keys are an error, so a misspelt option is not silently ignored. */

static const struct {
    const char *name;
    unsigned flag;
} parser_opts[] = {
    {"github", MD_DIALECT_GITHUB},
    {"tables", MD_FLAG_TABLES},
    {"strikethrough", MD_FLAG_STRIKETHROUGH},
    {"tasklists", MD_FLAG_TASKLISTS},
    {"footnotes", MD_FLAG_FOOTNOTES},
    {"admonitions", MD_FLAG_ADMONITIONS},
    {"autolinks", MD_FLAG_PERMISSIVEAUTOLINKS},
    {"underline", MD_FLAG_UNDERLINE},
    {"latex-math", MD_FLAG_LATEXMATHSPANS},
    {"wikilinks", MD_FLAG_WIKILINKS},
    {"spoilers", MD_FLAG_SPOILERS},
    {"superscripts", MD_FLAG_SUPERSCRIPTS},
    {"subscripts", MD_FLAG_SUBSCRIPTS},
    {"highlight", MD_FLAG_HIGHLIGHT},
    {"insert", MD_FLAG_INSERT},
    {"no-html", MD_FLAG_NOHTML},
    {"no-indented-code", MD_FLAG_NOINDENTEDCODEBLOCKS},
    {"hard-breaks", MD_FLAG_HARD_SOFT_BREAKS},
    {"collapse-whitespace", MD_FLAG_COLLAPSEWHITESPACE},
    {"permissive-atx-headers", MD_FLAG_PERMISSIVEATXHEADERS},
    {NULL, 0}};

static const struct {
    const char *name;
    unsigned flag;
} render_opts[] = {
    {"xhtml", MD_HTML_FLAG_XHTML},
    {"verbatim-entities", MD_HTML_FLAG_VERBATIM_ENTITIES},
    {NULL, 0}};

/* Applied in table order, so a later single flag overrides :github. */
static void read_opts(Janet v, unsigned *parser, unsigned *render) {
    *parser = MD_DIALECT_COMMONMARK;
    *render = MD_HTML_FLAG_SKIP_UTF8_BOM;
    if (janet_checktype(v, JANET_NIL)) return;
    const JanetKV *kvs;
    int32_t len, cap;
    if (!janet_dictionary_view(v, &kvs, &len, &cap)) {
        janet_panic("md4c: opts must be a table or a struct");
    }
    const JanetKV *kv = NULL;
    while ((kv = janet_dictionary_next(kvs, cap, kv))) {
        int known = janet_checktype(kv->key, JANET_KEYWORD);
        for (int i = 0; known && parser_opts[i].name; i++) {
            if (janet_keyeq(kv->key, parser_opts[i].name)) goto next;
        }
        for (int i = 0; known && render_opts[i].name; i++) {
            if (janet_keyeq(kv->key, render_opts[i].name)) goto next;
        }
        janet_panicf("md4c: unknown option %v", kv->key);
    next:;
    }
    for (int i = 0; parser_opts[i].name; i++) {
        Janet f = janet_dictionary_get(kvs, cap, janet_ckeywordv(parser_opts[i].name));
        if (janet_checktype(f, JANET_NIL)) continue;
        if (janet_truthy(f)) *parser |= parser_opts[i].flag;
        else *parser &= ~parser_opts[i].flag;
    }
    for (int i = 0; render_opts[i].name; i++) {
        Janet f = janet_dictionary_get(kvs, cap, janet_ckeywordv(render_opts[i].name));
        if (janet_truthy(f)) *render |= render_opts[i].flag;
    }
}

/* Output */

typedef struct {
    JanetBuffer *buf;
    int overflow;
} Out;

static void put_output(const MD_CHAR *text, MD_SIZE size, void *userdata) {
    Out *o = userdata;
    if (o->overflow) return;
    if ((uint64_t)o->buf->count + size > INT32_MAX) {
        o->overflow = 1;
        return;
    }
    janet_buffer_push_bytes(o->buf, (const uint8_t *)text, (int32_t)size);
}

JANET_FN(chirp_md4c_fn_to_html, "(md4c/to-html markdown &opt opts)",
         "Renders a Markdown string or buffer to an HTML string: the body only, "
         "with no <html> or <head>. The default is plain CommonMark; opts is a "
         "table or struct of flags. :github turns on GitHub's dialect (tables, "
         "strikethrough, task lists, autolinks, admonitions and footnotes), and "
         "each extension can also be set on its own, or turned off after "
         ":github with false: :tables :strikethrough :tasklists :footnotes "
         ":admonitions :autolinks :underline :latex-math :wikilinks :spoilers "
         ":superscripts :subscripts :highlight :insert. :no-html drops raw HTML "
         "from the input, :no-indented-code allows only fenced code, :hard-breaks "
         "makes every line break a <br>, :collapse-whitespace and "
         ":permissive-atx-headers relax the parse. For the output, :xhtml writes "
         "self-closing tags and :verbatim-entities keeps entities as written. "
         "Raw HTML in the input is passed through unless :no-html is set, so use "
         "it for untrusted text. A leading UTF-8 byte order mark is skipped.") {
    janet_arity(argc, 1, 2);
    JanetByteView md = janet_getbytes(argv, 0);
    unsigned parser, render;
    read_opts(argc > 1 ? argv[1] : janet_wrap_nil(), &parser, &render);
    Out o = {janet_buffer(md.len + md.len / 4 + 16), 0};
    int rc = md_html((const MD_CHAR *)md.bytes, (MD_SIZE)md.len, put_output, &o, parser, render);
    if (o.overflow) janet_panic("md4c: the HTML output is too large for a Janet string");
    if (rc != 0) janet_panic("md4c: the Markdown could not be parsed (out of memory)");
    return janet_stringv(o.buf->data, o.buf->count);
}

JANET_FN(chirp_md4c_fn_version, "(md4c/version)",
         "Returns the version of the bundled md4c, such as \"0.6.0\".") {
    janet_fixarity(argc, 0);
    (void)argv;
    return janet_cstringv(CHIRP_MD4C_VERSION);
}

JANET_MODULE_ENTRY(JanetTable *env) {
    static const JanetRegExt cfuns[] = {
        JANET_REG("to-html", chirp_md4c_fn_to_html),
        JANET_REG("version", chirp_md4c_fn_version),
        JANET_REG_END};
    janet_cfuns_ext(env, "md4c", cfuns);
}
