/* Force-included into every C file of the wasm32-wasi target (see the target in
 * tools/build/config.jdn). wasi-libc lacks a few POSIX bits that Janet 1.43
 * references even with processes, threads and the event loop compiled out.
 * These belong upstream in Janet; until then they live here, not in a patch. */
#ifndef CHIRP_WASM_COMPAT_H
#define CHIRP_WASM_COMPAT_H
#include <time.h>
#include <unistd.h>
static inline void tzset(void) {}
#ifndef CLOCK_PROCESS_CPUTIME_ID
#define CLOCK_PROCESS_CPUTIME_ID CLOCK_MONOTONIC
#endif
/* WASI has no descriptor duplication; Janet's io.c only needs it for file/open on fds. */
static inline int dup(int fd) { (void) fd; return -1; }
#endif
