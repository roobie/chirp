/* The start of the stubs source that build.janet writes for a :stub-missing
 * target; it appends one stub(env, name) call per name the target lacks. */
#include <janet.h>

static Janet chirp_unavailable(int32_t argc, Janet *argv) {
    (void) argc; (void) argv;
    janet_panic("not available in this build of chirp");
}

static void stub(JanetTable *env, const char *name) {
    Janet stub = janet_wrap_cfunction(chirp_unavailable);
    Janet entry = janet_table_get(env, janet_csymbolv(name));
    if (!janet_checktype(entry, JANET_TABLE)) {
        janet_def(env, name, stub, NULL);
        return;
    }
    /* Keep the entry, and so its docstring; fill in only a missing value. */
    JanetTable *t = janet_unwrap_table(entry);
    if (janet_checktype(janet_table_get(t, janet_ckeywordv("value")), JANET_NIL))
        janet_table_put(t, janet_ckeywordv("value"), stub);
}

