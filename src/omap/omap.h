/* chirp's ordered map: the type behind the omap module, shared by every native
 * that builds or reads one (omap, yaml, json-omap).
 *
 * All of it is static, so each native carries its own copy of the code and no
 * native needs another to be loaded. The copies still share one type: the first
 * to need it registers its table of callbacks under the name "omap" and the
 * others look it up, so a map made by any native is a map to all of them.
 *
 * Layout: entries are kept in insertion order in an array. A hash index of
 * entry numbers (open addressing, at most half full) finds a key. A removed
 * entry keeps its key and loses its value, so the index never needs to be
 * unpicked and an iteration that removes the current key can carry on. The
 * array is compacted, and the index rebuilt, only when an insert finds it full,
 * which makes insert and lookup O(1) amortized. */

#ifndef CHIRP_OMAP_H
#define CHIRP_OMAP_H

#include <janet.h>

#include <stdint.h>
#include <string.h>

#if defined(__GNUC__)
#define OMAP_UNUSED __attribute__((unused))
#else
#define OMAP_UNUSED
#endif

#define OMAP_NAME "omap"
#define OMAP_MIN_CAP 8

typedef struct {
    Janet key;
    Janet value; /* nil marks a removed entry; a live value is never nil */
} OmapEntry;

typedef struct {
    OmapEntry *entries;
    int32_t *slots; /* entry number per slot, -1 when empty; 2 * cap slots */
    int32_t used;   /* entries in use, removed ones included */
    int32_t live;
    int32_t cap;
    int32_t mask;
} Omap;

static int omap_live(const OmapEntry *e) {
    return !janet_checktype(e->value, JANET_NIL);
}

/* Entry number of key, or -1. *slot is where the probe ended: the slot holding
 * the entry, or the empty slot an insert would take. */
static int32_t omap_probe(const Omap *o, Janet key, int32_t *slot) {
    if (!o->slots) {
        *slot = -1;
        return -1;
    }
    uint32_t i = (uint32_t) janet_hash(key) & (uint32_t) o->mask;
    for (;;) {
        int32_t e = o->slots[i];
        if (e < 0) {
            *slot = (int32_t) i;
            return -1;
        }
        if (janet_equals(o->entries[e].key, key)) {
            *slot = (int32_t) i;
            return e;
        }
        i = (i + 1) & (uint32_t) o->mask;
    }
}

/* Drops removed entries, makes room for cap entries (never fewer than now) and
 * rebuilds the index. */
static void omap_rebuild_to(Omap *o, int32_t cap) {
    int32_t n = 0;
    for (int32_t i = 0; i < o->used; i++) {
        if (!omap_live(&o->entries[i])) continue;
        if (n != i) o->entries[n] = o->entries[i];
        n++;
    }
    o->used = n;
    if (cap < o->cap) cap = o->cap;
    if (cap > INT32_MAX / 4) janet_panic("omap: too many entries");
    if (cap != o->cap) {
        OmapEntry *ne = janet_realloc(o->entries, sizeof(OmapEntry) * (size_t) cap);
        if (!ne) JANET_OUT_OF_MEMORY;
        janet_gcpressure(sizeof(OmapEntry) * (size_t) (cap - o->cap));
        o->entries = ne;
        o->cap = cap;
    }
    int32_t nslots = cap * 2;
    if (!o->slots || o->mask + 1 != nslots) {
        int32_t *ns = janet_realloc(o->slots, sizeof(int32_t) * (size_t) nslots);
        if (!ns) JANET_OUT_OF_MEMORY;
        o->slots = ns;
        o->mask = nslots - 1;
    }
    for (int32_t i = 0; i < nslots; i++) o->slots[i] = -1;
    for (int32_t e = 0; e < n; e++) {
        uint32_t i = (uint32_t) janet_hash(o->entries[e].key) & (uint32_t) o->mask;
        while (o->slots[i] >= 0) i = (i + 1) & (uint32_t) o->mask;
        o->slots[i] = e;
    }
}

/* Called when an insert finds the entries full: compacts, and doubles when more
 * than half the entries are live, so the work is paid for by the inserts since. */
static void omap_rebuild(Omap *o) {
    int32_t cap = o->cap == 0 ? OMAP_MIN_CAP : (o->live >= o->cap / 2 ? o->cap * 2 : o->cap);
    omap_rebuild_to(o, cap);
}

/* Like a table: a key that is present keeps its place, nil removes it. */
OMAP_UNUSED static void omap_put(Omap *o, Janet key, Janet value) {
    if (janet_checktype(key, JANET_NIL) ||
        (janet_checktype(key, JANET_NUMBER) && janet_unwrap_number(key) != janet_unwrap_number(key)))
        janet_panic("omap: a key cannot be nil or nan");
    int32_t slot;
    int32_t e = omap_probe(o, key, &slot);
    int removing = janet_checktype(value, JANET_NIL);
    if (e >= 0 && omap_live(&o->entries[e])) {
        o->entries[e].value = value;
        if (removing) o->live--;
        return;
    }
    if (removing) return;
    if (o->used == o->cap) {
        omap_rebuild(o);
        omap_probe(o, key, &slot);
    }
    /* An earlier, removed entry of this key is bypassed: the key re-enters last. */
    o->entries[o->used].key = key;
    o->entries[o->used].value = value;
    o->slots[slot] = o->used++;
    o->live++;
}

/* nil when the key is absent. */
OMAP_UNUSED static Janet omap_lookup(const Omap *o, Janet key) {
    int32_t slot;
    int32_t e = omap_probe(o, key, &slot);
    return e >= 0 ? o->entries[e].value : janet_wrap_nil();
}

/* The key after key in order, or nil at the end. A nil key starts. */
static Janet omap_next_key(const Omap *o, Janet key) {
    int32_t i = 0;
    if (!janet_checktype(key, JANET_NIL)) {
        int32_t slot;
        int32_t e = omap_probe(o, key, &slot);
        if (e < 0) janet_panicf("key %v not found in omap", key);
        i = e + 1;
    }
    for (; i < o->used; i++)
        if (omap_live(&o->entries[i])) return o->entries[i].key;
    return janet_wrap_nil();
}

/* Callbacks of the abstract type */

static int omap_cb_gc(void *p, size_t len) {
    Omap *o = p;
    (void) len;
    janet_free(o->entries);
    janet_free(o->slots);
    return 0;
}

static int omap_cb_gcmark(void *p, size_t len) {
    Omap *o = p;
    (void) len;
    for (int32_t i = 0; i < o->used; i++) {
        janet_mark(o->entries[i].key);
        janet_mark(o->entries[i].value);
    }
    return 0;
}

/* An absent key reads as nil, as it does on a table. */
static int omap_cb_get(void *p, Janet key, Janet *out) {
    *out = omap_lookup(p, key);
    return 1;
}

static void omap_cb_put(void *p, Janet key, Janet value) {
    omap_put(p, key, value);
}

static Janet omap_cb_next(void *p, Janet key) {
    return omap_next_key(p, key);
}

static size_t omap_cb_length(void *p, size_t len) {
    (void) len;
    return (size_t) ((Omap *) p)->live;
}

/* A map holding itself would print forever. */
static int omap_print_depth = 0;

static void omap_cb_tostring(void *p, JanetBuffer *buffer) {
    Omap *o = p;
    if (++omap_print_depth > JANET_RECURSION_GUARD) {
        omap_print_depth = 0;
        janet_panic("omap: nested too deeply to print");
    }
    janet_buffer_push_u8(buffer, '{');
    int first = 1;
    for (int32_t i = 0; i < o->used; i++) {
        if (!omap_live(&o->entries[i])) continue;
        if (!first) janet_buffer_push_u8(buffer, ' ');
        first = 0;
        const uint8_t *k = janet_description(o->entries[i].key);
        janet_buffer_push_bytes(buffer, k, janet_string_length(k));
        janet_buffer_push_u8(buffer, ' ');
        const uint8_t *v = janet_description(o->entries[i].value);
        janet_buffer_push_bytes(buffer, v, janet_string_length(v));
    }
    janet_buffer_push_u8(buffer, '}');
    omap_print_depth--;
}

/* (m key) and (m key default), as a lookup. */
static Janet omap_cb_call(void *p, int32_t argc, Janet *argv) {
    janet_arity(argc, 1, 2);
    Janet v = omap_lookup(p, argv[0]);
    if (janet_checktype(v, JANET_NIL) && argc == 2) return argv[1];
    return v;
}

static const JanetAbstractType omap_local_type = {
    .name = OMAP_NAME,
    .gc = omap_cb_gc,
    .gcmark = omap_cb_gcmark,
    .get = omap_cb_get,
    .put = omap_cb_put,
    .tostring = omap_cb_tostring,
    .next = omap_cb_next,
    .call = omap_cb_call,
    .length = omap_cb_length,
};

/* The registered type, which is this copy's on first use. */
static const JanetAbstractType *omap_type(void) {
    const JanetAbstractType *t = janet_get_abstract_type(janet_csymbolv(OMAP_NAME));
    if (t) return t;
    janet_register_abstract_type(&omap_local_type);
    return &omap_local_type;
}

OMAP_UNUSED static int omap_is(Janet v) {
    return janet_checktype(v, JANET_ABSTRACT) && janet_abstract_type(janet_unwrap_abstract(v)) == omap_type();
}

/* hint is how many entries are expected; 0 allocates nothing yet. */
OMAP_UNUSED static Omap *omap_create(int32_t hint) {
    Omap *o = janet_abstract(omap_type(), sizeof(Omap));
    memset(o, 0, sizeof *o);
    if (hint > 0) {
        int32_t cap = OMAP_MIN_CAP;
        while (cap < hint && cap <= INT32_MAX / 8) cap *= 2;
        omap_rebuild_to(o, cap);
    }
    return o;
}

#endif
