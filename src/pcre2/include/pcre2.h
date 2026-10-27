/* PCRE2 ships its public header as pcre2.h.generic and expects a build system
 * to copy it to pcre2.h. This forwards to the pin's copy instead, so nothing is
 * copied into the pinned checkout. The pin's src directory is on the include
 * path. */
#include "pcre2.h.generic"
