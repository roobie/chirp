/* chirp's lexbor module: HTML parsed by lexbor and queried with CSS selectors.
 *
 * A document owns every node in it, and lexbor frees them all at once, so a
 * node is a handle that marks its document: the document lives while any of
 * its nodes do. Nothing here changes a document, so a node handle never goes
 * stale.
 *
 * lexbor's callbacks run inside lexbor's frames while lexbor owns memory, so
 * they never raise: they only append. Errors are raised once lexbor's state is
 * freed. */

#include <janet.h>

#include <lexbor/css/css.h>
#include <lexbor/html/html.h>
#include <lexbor/selectors/selectors.h>

#include <stdint.h>
#include <string.h>

/* Documents */

typedef struct {
    lxb_html_document_t *doc;
} Doc;

static int doc_gc(void *p, size_t size) {
    (void)size;
    Doc *d = p;
    if (d->doc) lxb_html_document_destroy(d->doc);
    d->doc = NULL;
    return 0;
}

static const JanetAbstractType doc_type = {
    .name = "lexbor/document",
    .gc = doc_gc,
};

/* Nodes */

typedef struct {
    Doc *doc;
    lxb_dom_node_t *node;
} Node;

static int node_mark(void *p, size_t size) {
    (void)size;
    janet_mark(janet_wrap_abstract(((Node *)p)->doc));
    return 0;
}

static void push_bytes(JanetBuffer *buf, const lxb_char_t *s, size_t len) {
    janet_buffer_push_bytes(buf, (const uint8_t *)s, (int32_t)len);
}

static void node_tostring(void *p, JanetBuffer *buf) {
    lxb_dom_node_t *n = ((Node *)p)->node;
    if (n->type == LXB_DOM_NODE_TYPE_ELEMENT) {
        size_t len;
        const lxb_char_t *name = lxb_dom_element_qualified_name(lxb_dom_interface_element(n), &len);
        push_bytes(buf, name, len);
    }
}

/* Two handles on the same node are equal and hash alike, so nodes can be
 * compared and used as table keys. */
static int node_compare(void *a, void *b) {
    uintptr_t x = (uintptr_t)((Node *)a)->node, y = (uintptr_t)((Node *)b)->node;
    return x < y ? -1 : x > y;
}

static int32_t node_hash(void *p, size_t size) {
    (void)size;
    uint64_t x = (uint64_t)(uintptr_t)((Node *)p)->node;
    return (int32_t)(x ^ (x >> 32));
}

static const JanetAbstractType node_type = {
    .name = "lexbor/node",
    .gcmark = node_mark,
    .tostring = node_tostring,
    .compare = node_compare,
    .hash = node_hash,
};

static Janet wrap_node(Doc *doc, lxb_dom_node_t *n) {
    Node *h = janet_abstract(&node_type, sizeof(Node));
    h->doc = doc;
    h->node = n;
    return janet_wrap_abstract(h);
}

/* A document or a node, as the node to work on; a document stands for its
 * root node. */
static lxb_dom_node_t *get_node(const Janet *argv, int32_t i, Doc **doc) {
    void *a = janet_checkabstract(argv[i], &node_type);
    if (a) {
        *doc = ((Node *)a)->doc;
        return ((Node *)a)->node;
    }
    a = janet_checkabstract(argv[i], &doc_type);
    if (!a) janet_panicf("lexbor: expected a document or a node, got %v", argv[i]);
    *doc = a;
    return lxb_dom_interface_node(((Doc *)a)->doc);
}

/* The element a node stands for, or NULL. A document stands for its <html>. */
static lxb_dom_element_t *get_element(const Janet *argv, int32_t i) {
    Doc *doc;
    lxb_dom_node_t *n = get_node(argv, i, &doc);
    if (n->type == LXB_DOM_NODE_TYPE_DOCUMENT) {
        return lxb_dom_document_element(lxb_dom_interface_document(n));
    }
    return n->type == LXB_DOM_NODE_TYPE_ELEMENT ? lxb_dom_interface_element(n) : NULL;
}

/* Output from lexbor's serializers, gathered without raising. */

typedef struct {
    JanetBuffer *buf;
    int overflow;
} Out;

static lxb_status_t put_output(const lxb_char_t *data, size_t len, void *ctx) {
    Out *o = ctx;
    if (o->overflow) return LXB_STATUS_OK;
    if ((uint64_t)o->buf->count + len > INT32_MAX) {
        o->overflow = 1;
        return LXB_STATUS_OK;
    }
    push_bytes(o->buf, data, len);
    return LXB_STATUS_OK;
}

static Janet out_string(Out *o, lxb_status_t status) {
    if (o->overflow) janet_panic("lexbor: the output is too large for a Janet string");
    if (status != LXB_STATUS_OK) janet_panicf("lexbor: serializing failed (status %d)", (int)status);
    return janet_stringv(o->buf->data, o->buf->count);
}

/* Functions */

JANET_FN(chirp_lexbor_fn_parse, "(lexbor/parse html)",
         "Parses a string or buffer of HTML into a document, as a browser would: "
         "markup that is not valid is repaired the way the HTML standard says, "
         "so parsing never fails on content. The document is freed when it and "
         "every node taken from it are garbage.") {
    janet_fixarity(argc, 1);
    JanetByteView html = janet_getbytes(argv, 0);
    Doc *d = janet_abstract(&doc_type, sizeof(Doc));
    d->doc = lxb_html_document_create();
    if (!d->doc) janet_panic("lexbor: out of memory");
    lxb_status_t st = lxb_html_document_parse(d->doc, html.bytes, (size_t)html.len);
    if (st != LXB_STATUS_OK) {
        lxb_html_document_destroy(d->doc);
        d->doc = NULL;
        janet_panicf("lexbor: the HTML could not be parsed (status %d)", (int)st);
    }
    return janet_wrap_abstract(d);
}

typedef struct {
    Doc *doc;
    JanetArray *found;
    int first;
} Find;

static lxb_status_t found_node(lxb_dom_node_t *n, lxb_css_selector_specificity_t spec, void *ctx) {
    (void)spec;
    Find *f = ctx;
    janet_array_push(f->found, wrap_node(f->doc, n));
    return f->first ? LXB_STATUS_STOP : LXB_STATUS_OK;
}

/* Runs a selector under root; each match is pushed once, in document order.
 * Every lexbor object is freed before anything is raised. */
static void find(const Janet *argv, Find *f) {
    lxb_dom_node_t *root = get_node(argv, 0, &f->doc);
    JanetByteView sel = janet_getbytes(argv, 1);
    lxb_css_parser_t *parser = lxb_css_parser_create();
    lxb_selectors_t *selectors = lxb_selectors_create();
    lxb_css_selector_list_t *list = NULL;
    JanetBuffer *err = NULL;
    lxb_status_t st = LXB_STATUS_ERROR_MEMORY_ALLOCATION;
    if (!parser || !selectors) goto done;
    if ((st = lxb_css_parser_init(parser, NULL)) != LXB_STATUS_OK) goto done;
    if ((st = lxb_selectors_init(selectors)) != LXB_STATUS_OK) goto done;
    lxb_selectors_opt_set(selectors, LXB_SELECTORS_OPT_MATCH_FIRST);
    list = lxb_css_selectors_parse(parser, sel.bytes, (size_t)sel.len);
    if (parser->status != LXB_STATUS_OK || !list) {
        err = janet_buffer(64);
        Out o = {err, 0};
        lxb_css_log_serialize(parser->log, put_output, &o, NULL, 0);
        if (err->count == 0) janet_buffer_push_cstring(err, "it does not parse");
        st = parser->status;
        goto done;
    }
    st = lxb_selectors_find(selectors, root, list, found_node, f);
done:
    if (list) lxb_css_selector_list_destroy_memory(list);
    if (selectors) lxb_selectors_destroy(selectors, true);
    if (parser) lxb_css_parser_destroy(parser, true);
    if (err) janet_panicf("lexbor: bad selector %q: %S", argv[1], janet_string(err->data, err->count));
    if (st != LXB_STATUS_OK && st != LXB_STATUS_STOP) {
        janet_panicf("lexbor: selecting %q failed (status %d)", argv[1], (int)st);
    }
}

JANET_FN(chirp_lexbor_fn_select, "(lexbor/select root selector)",
         "Returns an array of the elements under root (a document or a node) "
         "that match a CSS selector, such as \"a[href]\" or \"nav > ul li:first-child\", "
         "in document order and each once. Root itself is never a match. A "
         "selector that does not parse is an error.") {
    janet_fixarity(argc, 2);
    Find f = {NULL, janet_array(0), 0};
    find(argv, &f);
    return janet_wrap_array(f.found);
}

JANET_FN(chirp_lexbor_fn_select_first, "(lexbor/select-first root selector)",
         "Returns the first element under root (a document or a node) that "
         "matches a CSS selector, in document order, or nil if none does.") {
    janet_fixarity(argc, 2);
    Find f = {NULL, janet_array(1), 1};
    find(argv, &f);
    return f.found->count ? f.found->data[0] : janet_wrap_nil();
}

JANET_FN(chirp_lexbor_fn_text, "(lexbor/text node)",
         "Returns the text of a node and everything in it, as the DOM's "
         "textContent: markup removed, whitespace kept as written. A document "
         "gives the text of its <html>.") {
    janet_fixarity(argc, 1);
    Doc *doc;
    lxb_dom_node_t *n = get_node(argv, 0, &doc);
    if (n->type == LXB_DOM_NODE_TYPE_DOCUMENT) {
        lxb_dom_element_t *root = lxb_dom_document_element(lxb_dom_interface_document(n));
        if (!root) return janet_cstringv("");
        n = lxb_dom_interface_node(root);
    }
    size_t len;
    lxb_char_t *text = lxb_dom_node_text_content(n, &len);
    if (!text) return janet_cstringv("");
    if (len > INT32_MAX) {
        lxb_dom_document_destroy_text(n->owner_document, text);
        janet_panic("lexbor: the text is too large for a Janet string");
    }
    Janet s = janet_stringv(text, (int32_t)len);
    lxb_dom_document_destroy_text(n->owner_document, text);
    return s;
}

JANET_FN(chirp_lexbor_fn_attr, "(lexbor/attr node name)",
         "Returns the value of a node's attribute as a string, or nil if the "
         "node has no such attribute. An attribute written without a value, as "
         "in <input disabled>, gives \"\". HTML attribute names are matched "
         "without regard to case.") {
    janet_fixarity(argc, 2);
    lxb_dom_element_t *el = get_element(argv, 0);
    JanetByteView name = janet_getbytes(argv, 1);
    if (!el) return janet_wrap_nil();
    lxb_dom_attr_t *a = lxb_dom_element_attr_by_name(el, name.bytes, (size_t)name.len);
    if (!a) return janet_wrap_nil();
    size_t len;
    const lxb_char_t *v = lxb_dom_attr_value(a, &len);
    return v ? janet_stringv(v, (int32_t)len) : janet_cstringv("");
}

JANET_FN(chirp_lexbor_fn_attrs, "(lexbor/attrs node)",
         "Returns a struct of a node's attributes, names to string values. A "
         "node that is not an element has none.") {
    janet_fixarity(argc, 1);
    lxb_dom_element_t *el = get_element(argv, 0);
    if (!el) return janet_wrap_struct(janet_struct_end(janet_struct_begin(0)));
    int32_t count = 0;
    for (lxb_dom_attr_t *a = lxb_dom_element_first_attribute(el); a; a = lxb_dom_element_next_attribute(a)) {
        count++;
    }
    JanetKV *st = janet_struct_begin(count);
    for (lxb_dom_attr_t *a = lxb_dom_element_first_attribute(el); a; a = lxb_dom_element_next_attribute(a)) {
        size_t nlen, vlen;
        const lxb_char_t *n = lxb_dom_attr_qualified_name(a, &nlen);
        const lxb_char_t *v = lxb_dom_attr_value(a, &vlen);
        janet_struct_put(st, janet_stringv(n, (int32_t)nlen),
                         v ? janet_stringv(v, (int32_t)vlen) : janet_cstringv(""));
    }
    return janet_wrap_struct(janet_struct_end(st));
}

JANET_FN(chirp_lexbor_fn_tag, "(lexbor/tag node)",
         "Returns a node's tag name in lower case, such as \"div\", or nil for a "
         "node that is not an element. A document gives \"html\".") {
    janet_fixarity(argc, 1);
    lxb_dom_element_t *el = get_element(argv, 0);
    if (!el) return janet_wrap_nil();
    size_t len;
    const lxb_char_t *name = lxb_dom_element_qualified_name(el, &len);
    return janet_stringv(name, (int32_t)len);
}

JANET_FN(chirp_lexbor_fn_html, "(lexbor/html node)",
         "Returns a node and everything in it as HTML (the DOM's outerHTML). A "
         "document gives the whole document, with its doctype. The HTML is what "
         "lexbor parsed, so repaired markup comes back repaired.") {
    janet_fixarity(argc, 1);
    Doc *doc;
    lxb_dom_node_t *n = get_node(argv, 0, &doc);
    Out o = {janet_buffer(256), 0};
    lxb_status_t st = lxb_html_serialize_tree_cb(n, put_output, &o);
    return out_string(&o, st);
}

JANET_FN(chirp_lexbor_fn_inner_html, "(lexbor/inner-html node)",
         "Returns what is inside a node as HTML, without the node's own tags "
         "(the DOM's innerHTML).") {
    janet_fixarity(argc, 1);
    Doc *doc;
    lxb_dom_node_t *n = get_node(argv, 0, &doc);
    Out o = {janet_buffer(256), 0};
    lxb_status_t st = lxb_html_serialize_deep_cb(n, put_output, &o);
    return out_string(&o, st);
}

JANET_FN(chirp_lexbor_fn_version, "(lexbor/version)",
         "Returns the version of the bundled lexbor, such as \"3.0.1\".") {
    janet_fixarity(argc, 0);
    (void)argv;
    return janet_cstringv(CHIRP_LEXBOR_VERSION);
}

JANET_MODULE_ENTRY(JanetTable *env) {
    static const JanetRegExt cfuns[] = {
        JANET_REG("parse", chirp_lexbor_fn_parse),
        JANET_REG("select", chirp_lexbor_fn_select),
        JANET_REG("select-first", chirp_lexbor_fn_select_first),
        JANET_REG("text", chirp_lexbor_fn_text),
        JANET_REG("attr", chirp_lexbor_fn_attr),
        JANET_REG("attrs", chirp_lexbor_fn_attrs),
        JANET_REG("tag", chirp_lexbor_fn_tag),
        JANET_REG("html", chirp_lexbor_fn_html),
        JANET_REG("inner-html", chirp_lexbor_fn_inner_html),
        JANET_REG("version", chirp_lexbor_fn_version),
        JANET_REG_END};
    janet_cfuns_ext(env, "lexbor", cfuns);
}
