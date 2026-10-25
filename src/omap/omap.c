/* chirp's omap module: a map that remembers the order its keys were first put
 * in. The type lives in omap.h so yaml and the json overlay's decoder can make
 * one too. */

#include "omap.h"

static Omap *get_omap(Janet *argv, int32_t n) {
    if (!omap_is(argv[n])) janet_panicf("bad slot #%d, expected omap, got %v", n, argv[n]);
    return janet_unwrap_abstract(argv[n]);
}

JANET_FN(omap_fn_new, "(omap/new & kvs)",
         "Returns a new ordered map holding the given keys and values, in the "
         "order given: (omap/new :b 1 :a 2) lists :b before :a. A key given "
         "twice keeps its first place, and a nil value leaves the key out.") {
    if (argc & 1) janet_panic("expected an even number of arguments");
    Omap *o = omap_create(argc / 2);
    for (int32_t i = 0; i < argc; i += 2) omap_put(o, argv[i], argv[i + 1]);
    return janet_wrap_abstract(o);
}

JANET_FN(omap_fn_from_pairs, "(omap/from-pairs pairs)",
         "Returns a new ordered map from an array or tuple of [key value] "
         "pairs, in that order, as (omap/from-pairs [[:b 1] [:a 2]]).") {
    janet_fixarity(argc, 1);
    JanetView pairs = janet_getindexed(argv, 0);
    Omap *o = omap_create(pairs.len);
    for (int32_t i = 0; i < pairs.len; i++) {
        const Janet *kv;
        int32_t n;
        if (!janet_indexed_view(pairs.items[i], &kv, &n) || n != 2)
            janet_panicf("expected a [key value] pair, got %v", pairs.items[i]);
        omap_put(o, kv[0], kv[1]);
    }
    return janet_wrap_abstract(o);
}

JANET_FN(omap_fn_pairs, "(omap/pairs m)",
         "Returns an array of [key value] tuples of the ordered map m, in its "
         "order. omap/from-pairs reads it back.") {
    janet_fixarity(argc, 1);
    Omap *o = get_omap(argv, 0);
    JanetArray *out = janet_array(o->live);
    for (int32_t i = 0; i < o->used; i++) {
        if (!omap_live(&o->entries[i])) continue;
        Janet kv[2] = {o->entries[i].key, o->entries[i].value};
        janet_array_push(out, janet_wrap_tuple(janet_tuple_n(kv, 2)));
    }
    return janet_wrap_array(out);
}

JANET_FN(omap_fn_is, "(omap/omap? x)", "Returns true if x is an ordered map.") {
    janet_fixarity(argc, 1);
    return janet_wrap_boolean(omap_is(argv[0]));
}

JANET_MODULE_ENTRY(JanetTable *env) {
    static const JanetRegExt cfuns[] = {
        JANET_REG("new", omap_fn_new),
        JANET_REG("from-pairs", omap_fn_from_pairs),
        JANET_REG("pairs", omap_fn_pairs),
        JANET_REG("omap?", omap_fn_is),
        JANET_REG_END};
    janet_cfuns_ext(env, "omap", cfuns);
    omap_type(); /* registered now, so the type exists before any map does */
}
