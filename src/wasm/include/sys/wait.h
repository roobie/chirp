/* WASI has no sys/wait.h; Janet includes it unconditionally on posix but only
 * uses it for processes, which the wasm target compiles out. */
#define WEXITSTATUS(x) (x)
