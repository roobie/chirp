/* The runtime half of setjmp/longjmp on wasm, which LLVM lowers to the wasm
 * exception-handling proposal under -mllvm -wasm-enable-sjlj. wasi-libc ships
 * it as libsetjmp, which zig does not build, so chirp carries the same three
 * functions. The layout must match what LLVM's lowering passes: the jmp_buf
 * holds the setjmp call site's identity and label, and longjmp throws the
 * C++-tag exception carrying (env, val). */
#include <stdint.h>

struct chirp_jmp_arg { void *env; int val; };
struct chirp_jmp_buf { void *func_invocation_id; uint32_t label; struct chirp_jmp_arg arg; };

void __wasm_setjmp(void *env, uint32_t label, void *func_invocation_id) {
    struct chirp_jmp_buf *jb = env;
    jb->func_invocation_id = func_invocation_id;
    jb->label = label;
}

uint32_t __wasm_setjmp_test(void *env, void *func_invocation_id) {
    struct chirp_jmp_buf *jb = env;
    return jb->func_invocation_id == func_invocation_id ? jb->label : 0;
}

void __wasm_longjmp(void *env, int val) {
    struct chirp_jmp_buf *jb = env;
    jb->arg.env = env;
    jb->arg.val = val ? val : 1;
    __builtin_wasm_throw(1, &jb->arg);
}
