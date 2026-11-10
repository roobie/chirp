/* Functions the wasm target's libraries call that wasi-libc or the SQLite
 * amalgamation leave out. Each fails the way the real one does when the
 * feature is unavailable. */
#include <stdio.h>
#include <string.h>

/* WASI has no temporary files; Janet's file/temp then reports an error. */
FILE *tmpfile(void) { return NULL; }

/* sqlite3.c omits extension loading on wasi, but janet-lang/sqlite3's binding
 * still calls it. The message must come from sqlite3_malloc, as the caller
 * frees it with sqlite3_free. */
void *sqlite3_malloc(int);
int sqlite3_load_extension(void *db, const char *file, const char *proc, char **err) {
    (void) db; (void) file; (void) proc;
    if (err) {
        static const char msg[] = "extension loading is not available in chirp's wasm build";
        *err = sqlite3_malloc((int) sizeof msg);
        if (*err) memcpy(*err, msg, sizeof msg);
    }
    return 1;
}
