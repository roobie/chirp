/* The configuration chirp builds PCRE2 with: 8-bit code units, Unicode
 * support, no JIT. Everything else keeps the defaults in config.h.generic,
 * which is the pin's copy and is found on the include path. */
#define SUPPORT_PCRE2_8 1
#define SUPPORT_UNICODE 1
#define HAVE_STDINT_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_MEMMOVE 1
#define HAVE_STRERROR 1
#include "config.h.generic"
