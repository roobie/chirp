/* chirp's osroots module: the roots the OS trusts for TLS servers, as PEM.
 *
 * OpenSSL only reads trust from files, and macOS and windows keep theirs in
 * stores of their own, so chirp exports those stores for OpenSSL. Nothing here
 * ships trust of its own: an OS without such a store gets nil.
 *
 * macOS: the trust settings of the user, admin and system domains, highest
 * first, as the keychain applies them. A certificate counts as a root when its
 * first decisive setting for the SSL policy is TrustRoot or TrustAsRoot; Deny
 * excludes it, Unspecified leaves it to the next domain, and no settings at
 * all means trusted as a root. Security.framework is opened with dlopen and
 * its few functions declared here, because the build has no Apple SDK.
 *
 * windows: the ROOT store of the current user, which includes the machine's,
 * without certificates also in the Disallowed store or whose usages exclude
 * server authentication. */

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <janet.h>

#if defined(__APPLE__) || defined(_WIN32)

/* PEM ---------------------------------------------------------------------*/

static void chirp_osroots_pem_append(JanetBuffer *b, const uint8_t *der, size_t len) {
    static const char tab[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    janet_buffer_push_cstring(b, "-----BEGIN CERTIFICATE-----\n");
    int col = 0;
    for (size_t i = 0; i < len; i += 3) {
        uint32_t v = (uint32_t)der[i] << 16;
        if (i + 1 < len) v |= (uint32_t)der[i + 1] << 8;
        if (i + 2 < len) v |= der[i + 2];
        uint8_t out[4] = {
            (uint8_t)tab[(v >> 18) & 63], (uint8_t)tab[(v >> 12) & 63],
            (uint8_t)(i + 1 < len ? tab[(v >> 6) & 63] : '='),
            (uint8_t)(i + 2 < len ? tab[v & 63] : '=')};
        janet_buffer_push_bytes(b, out, 4);
        col += 4;
        if (col == 64) {
            janet_buffer_push_u8(b, '\n');
            col = 0;
        }
    }
    if (col) janet_buffer_push_u8(b, '\n');
    janet_buffer_push_cstring(b, "-----END CERTIFICATE-----\n");
}

#endif

#if defined(__APPLE__)

#include <dlfcn.h>

typedef const void *CFTypeRef;
typedef long CFIndex;
typedef int32_t OSStatus;
typedef unsigned char Boolean;

enum { DOMAIN_USER = 0, DOMAIN_ADMIN = 1, DOMAIN_SYSTEM = 2 };
enum { RESULT_INVALID = 0, RESULT_TRUST_ROOT = 1, RESULT_TRUST_AS_ROOT = 2,
       RESULT_DENY = 3, RESULT_UNSPECIFIED = 4 };
#define CF_NUMBER_SINT32 3

static struct {
    OSStatus (*copy_certificates)(uint32_t, CFTypeRef *);
    OSStatus (*copy_trust_settings)(CFTypeRef, uint32_t, CFTypeRef *);
    CFTypeRef (*copy_data)(CFTypeRef);
    CFTypeRef (*policy_properties)(CFTypeRef);
    CFIndex (*array_count)(CFTypeRef);
    CFTypeRef (*array_at)(CFTypeRef, CFIndex);
    const uint8_t *(*data_bytes)(CFTypeRef);
    CFIndex (*data_length)(CFTypeRef);
    CFTypeRef (*dict_get)(CFTypeRef, CFTypeRef);
    Boolean (*number_get)(CFTypeRef, CFIndex, void *);
    Boolean (*equal)(CFTypeRef, CFTypeRef);
    void (*release)(CFTypeRef);
    CFTypeRef key_result, key_policy, key_oid, oid_ssl;
} sec;

/* NULL once Security.framework is usable, else what is missing. */
static const char *chirp_osroots_load(void) {
    static int loaded = 0;
    static const char *failed = NULL;
    if (loaded) return failed;
    loaded = 1;
    void *cf = dlopen("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation",
                      RTLD_LAZY);
    void *s = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY);
    if (!cf) return failed = "cannot open CoreFoundation";
    if (!s) return failed = "cannot open Security.framework";
    CFTypeRef (*cfstring)(CFTypeRef, const char *, uint32_t) = NULL;
#define SYM(lib, field, name) \
    if (!(*(void **)&sec.field = dlsym(lib, name))) return failed = "no " name;
/* SecTrustSettings.h makes its keys CFSTR literals, not exported symbols. */
#define STR(field, text) \
    if (!(sec.field = cfstring(NULL, text, 0x08000100 /* UTF-8 */))) return failed = "no " text;
#define KEY(field, name)                                                  \
    {                                                                     \
        CFTypeRef *p = (CFTypeRef *)dlsym(s, name);                       \
        if (!p || !*p) return failed = "no " name;                        \
        sec.field = *p;                                                   \
    }
    SYM(s, copy_certificates, "SecTrustSettingsCopyCertificates")
    SYM(s, copy_trust_settings, "SecTrustSettingsCopyTrustSettings")
    SYM(s, copy_data, "SecCertificateCopyData")
    SYM(s, policy_properties, "SecPolicyCopyProperties")
    SYM(cf, array_count, "CFArrayGetCount")
    SYM(cf, array_at, "CFArrayGetValueAtIndex")
    SYM(cf, data_bytes, "CFDataGetBytePtr")
    SYM(cf, data_length, "CFDataGetLength")
    SYM(cf, dict_get, "CFDictionaryGetValue")
    SYM(cf, number_get, "CFNumberGetValue")
    SYM(cf, equal, "CFEqual")
    SYM(cf, release, "CFRelease")
    if (!(*(void **)&cfstring = dlsym(cf, "CFStringCreateWithCString")))
        return failed = "no CFStringCreateWithCString";
    STR(key_result, "kSecTrustSettingsResult")
    STR(key_policy, "kSecTrustSettingsPolicy")
    KEY(key_oid, "kSecPolicyOid")
    KEY(oid_ssl, "kSecPolicyAppleSSL")
#undef SYM
#undef STR
#undef KEY
    return NULL;
}

/* The first decisive setting of cert in domain for the SSL policy, or
 * RESULT_UNSPECIFIED when the domain leaves it open, or -1 on error. */
static int chirp_osroots_decision(CFTypeRef cert, uint32_t domain) {
    CFTypeRef settings = NULL;
    OSStatus st = sec.copy_trust_settings(cert, domain, &settings);
    /* errSecItemNotFound: no settings here. A system anchor without any is
     * still an anchor; elsewhere the next domain decides. */
    if (st == -25300) return domain == DOMAIN_SYSTEM ? RESULT_TRUST_ROOT : RESULT_UNSPECIFIED;
    if (st != 0 || !settings) return -1;
    CFIndex n = sec.array_count(settings);
    int out = n == 0 ? RESULT_TRUST_ROOT : RESULT_UNSPECIFIED;
    for (CFIndex i = 0; i < n; i++) {
        CFTypeRef d = sec.array_at(settings, i);
        CFTypeRef policy = sec.dict_get(d, sec.key_policy);
        if (policy) {
            CFTypeRef props = sec.policy_properties(policy);
            CFTypeRef oid = props ? sec.dict_get(props, sec.key_oid) : NULL;
            int ssl = oid && sec.equal(oid, sec.oid_ssl);
            if (props) sec.release(props);
            if (!ssl) continue;
        }
        int32_t r = RESULT_TRUST_ROOT;
        CFTypeRef num = sec.dict_get(d, sec.key_result);
        if (num && !sec.number_get(num, CF_NUMBER_SINT32, &r)) continue;
        if (r == RESULT_TRUST_ROOT || r == RESULT_TRUST_AS_ROOT || r == RESULT_DENY) {
            out = r;
            break;
        }
    }
    sec.release(settings);
    return out;
}

typedef struct { CFTypeRef data; int decision; } chirp_osroots_seen;

static Janet chirp_osroots_export(int *count) {
    const char *failed = chirp_osroots_load();
    if (failed) janet_panicf("keychain: %s", failed);
    chirp_osroots_seen *seen = NULL;
    size_t nseen = 0, cap = 0;
    const uint32_t domains[] = {DOMAIN_USER, DOMAIN_ADMIN, DOMAIN_SYSTEM};
    for (int di = 0; di < 3; di++) {
        CFTypeRef certs = NULL;
        if (sec.copy_certificates(domains[di], &certs) != 0 || !certs) continue;
        CFIndex n = sec.array_count(certs);
        for (CFIndex i = 0; i < n; i++) {
            CFTypeRef cert = sec.array_at(certs, i);
            CFTypeRef data = sec.copy_data(cert);
            if (!data) continue;
            const uint8_t *bytes = sec.data_bytes(data);
            size_t len = (size_t)sec.data_length(data);
            /* A higher domain that already decided wins. */
            size_t k = 0;
            for (; k < nseen; k++) {
                if ((size_t)sec.data_length(seen[k].data) == len &&
                    !memcmp(sec.data_bytes(seen[k].data), bytes, len)) break;
            }
            int dec = k < nseen && seen[k].decision != RESULT_UNSPECIFIED
                          ? -2 : chirp_osroots_decision(cert, domains[di]);
            if (dec == -2 || dec < 0) {
                sec.release(data);
                continue;
            }
            if (k < nseen) {
                seen[k].decision = dec;
                sec.release(data);
                continue;
            }
            if (nseen == cap) {
                cap = cap ? cap * 2 : 256;
                chirp_osroots_seen *grown = realloc(seen, cap * sizeof *seen);
                if (!grown) {
                    sec.release(data);
                    break;
                }
                seen = grown;
            }
            seen[nseen].data = data;
            seen[nseen].decision = dec;
            nseen++;
        }
        sec.release(certs);
    }
    JanetBuffer *b = janet_buffer(256 * 1024);
    for (size_t k = 0; k < nseen; k++) {
        if (seen[k].decision == RESULT_TRUST_ROOT || seen[k].decision == RESULT_TRUST_AS_ROOT) {
            chirp_osroots_pem_append(b, sec.data_bytes(seen[k].data),
                                     (size_t)sec.data_length(seen[k].data));
            (*count)++;
        }
        sec.release(seen[k].data);
    }
    free(seen);
    if (!*count) janet_panic("keychain: no roots trusted for TLS servers");
    return janet_stringv(b->data, b->count);
}

#elif defined(_WIN32)

#include <windows.h>
#include <wincrypt.h>

/* Whether the certificate's usages, as the store records them, allow server
 * authentication. No restriction at all allows every usage. */
static int chirp_osroots_server_auth(PCCERT_CONTEXT c) {
    DWORD size = 0;
    if (!CertGetEnhancedKeyUsage(c, 0, NULL, &size))
        return GetLastError() == (DWORD)CRYPT_E_NOT_FOUND;
    PCERT_ENHKEY_USAGE u = malloc(size);
    if (!u) return 0;
    int ok = 0;
    if (CertGetEnhancedKeyUsage(c, 0, u, &size)) {
        if (u->cUsageIdentifier == 0) {
            ok = GetLastError() == (DWORD)CRYPT_E_NOT_FOUND;
        } else {
            for (DWORD i = 0; i < u->cUsageIdentifier; i++)
                if (!strcmp(u->rgpszUsageIdentifier[i], szOID_PKIX_KP_SERVER_AUTH)) ok = 1;
        }
    }
    free(u);
    return ok;
}

static Janet chirp_osroots_export(int *count) {
    HCERTSTORE root = CertOpenSystemStoreA(0, "ROOT");
    if (!root) janet_panicf("windows store: cannot open ROOT (error %lu)", (unsigned long)GetLastError());
    HCERTSTORE denied = CertOpenSystemStoreA(0, "Disallowed");
    JanetBuffer *b = janet_buffer(256 * 1024);
    PCCERT_CONTEXT c = NULL;
    while ((c = CertEnumCertificatesInStore(root, c))) {
        if (denied) {
            PCCERT_CONTEXT d = CertFindCertificateInStore(
                denied, X509_ASN_ENCODING | PKCS_7_ASN_ENCODING, 0, CERT_FIND_EXISTING, c, NULL);
            if (d) {
                CertFreeCertificateContext(d);
                continue;
            }
        }
        if (!chirp_osroots_server_auth(c)) continue;
        chirp_osroots_pem_append(b, c->pbCertEncoded, c->cbCertEncoded);
        (*count)++;
    }
    if (denied) CertCloseStore(denied, 0);
    CertCloseStore(root, 0);
    if (!*count) janet_panic("windows store: no roots trusted for TLS servers");
    return janet_stringv(b->data, b->count);
}

#else

static Janet chirp_osroots_export(int *count) {
    (void)count;
    return janet_wrap_nil();
}

#endif

JANET_FN(chirp_osroots_fn_export,
         "(osroots/export)",
         "The roots the OS trusts for TLS servers as [pem count]: the macOS keychain's "
         "trust settings or the windows ROOT store. nil where the OS keeps no such "
         "store (Linux and the BSDs keep files). Errors, naming what failed, when the "
         "store cannot be read or trusts no roots.") {
    janet_fixarity(argc, 0);
    (void)argv;
    int count = 0;
    Janet pem = chirp_osroots_export(&count);
    if (janet_checktype(pem, JANET_NIL)) return pem;
    Janet t[2] = {pem, janet_wrap_integer(count)};
    return janet_wrap_tuple(janet_tuple_n(t, 2));
}

JANET_MODULE_ENTRY(JanetTable *env) {
    JanetRegExt cfuns[] = {
        JANET_REG("export", chirp_osroots_fn_export),
        JANET_REG_END};
    janet_cfuns_ext(env, "osroots", cfuns);
}
