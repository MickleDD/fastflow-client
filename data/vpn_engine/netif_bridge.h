/* netif_bridge.h — C ABI between the FastFlow JNI shim (libfastflow_jni.so,
 * android/app/src/main/cpp/fastflow_jni.cpp) and the Go engine
 * (libvpn_engine.so, built from this directory).
 *
 * This header is the single source of truth for the contract:
 *   - the C++ shim includes it through the CMake include path;
 *   - the Go engine includes it from the cgo preamble in platform_android.go
 *     (Part 2) and must //export functions with exactly these names and
 *     type-compatible signatures.
 *
 * ── Memory & lifetime contract ──────────────────────────────────────────────
 *   - Every `const char*` points to a NUL-terminated UTF-8 buffer OWNED BY THE
 *     CALLER and valid ONLY for the duration of the call (they are pinned
 *     jstring buffers). The Go side MUST copy (C.GoString) before returning
 *     and MUST NOT free or retain them.
 *   - FFNetworkInfo is stack-allocated by the caller: copy it, don't keep it.
 *   - `if_name`, `addresses` and `dns_servers` are never NULL (may be "").
 *
 * ── Threading contract ──────────────────────────────────────────────────────
 *   - The Netif* downcalls are serialized on a single platform monitor thread,
 *     but the thread identity is unspecified and may change over the process
 *     lifetime. Handlers must be quick and non-blocking (hand real work to a
 *     goroutine after copying the arguments).
 *   - The function pointers passed to NetifRegisterPlatform may be invoked
 *     from any goroutine/OS thread at any time after registration. They live
 *     in libfastflow_jni.so and stay valid for the life of the process.
 */

#ifndef FASTFLOW_NETIF_BRIDGE_H
#define FASTFLOW_NETIF_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Bit flags for FFNetworkInfo.flags.
 * MUST mirror NetworkStateMonitor.kt (FLAG_*) — change both or neither. */
enum {
    FF_NETIF_WIFI        = 1u << 0,
    FF_NETIF_CELLULAR    = 1u << 1,
    FF_NETIF_ETHERNET    = 1u << 2,
    FF_NETIF_BLUETOOTH   = 1u << 3,
    FF_NETIF_METERED     = 1u << 8,  /* maps to sing-tun "isExpensive"    */
    FF_NETIF_CONSTRAINED = 1u << 9,  /* maps to sing-tun "isConstrained"  */
    FF_NETIF_VALIDATED   = 1u << 10  /* passed captive-portal validation  */
};

/* Sentinel handle meaning "no network". */
#define FF_NETIF_NO_HANDLE (-1)

typedef struct FFNetworkInfo {
    int64_t     net_handle;  /* android.net.Network#getNetworkHandle(); stable identity key */
    int32_t     if_index;    /* Linux ifindex; -1 if unknown                                */
    int32_t     mtu;         /* 0 if unknown (treat as 1500)                                */
    uint32_t    flags;       /* FF_NETIF_* bits                                             */
    const char* if_name;     /* e.g. "wlan0"; never NULL                                    */
    const char* addresses;   /* comma-joined, zone-stripped CIDRs: "10.4.2.1/24,fd00::2/64" */
    const char* dns_servers; /* comma-joined IPs: "8.8.8.8,2001:4860:4860::8888"            */
} FFNetworkInfo;

/* ── Downcalls: exported by the Go engine (Part 2, cgo //export). Resolved by
 *    the shim at runtime with dlopen/dlsym — never linked directly — so the
 *    app keeps building and running against an engine that predates them. ── */

/* A non-VPN network appeared or changed (identity = info->net_handle). */
void NetifUpdate(FFNetworkInfo* info);

/* The network with this handle disappeared. */
void NetifLost(int64_t net_handle);

/* The best underlying (non-VPN) network changed. info carries name/index/flags
 * only (addresses/dns_servers are ""); NULL info = no usable network. */
void NetifDefaultChanged(FFNetworkInfo* info);

/* The platform monitor stopped: drop every cached network. */
void NetifReset(void);

/* ── Upcalls: implemented by the JNI shim, handed to Go at bind time. ─────── */

/* VpnService.protect(fd). Returns 0 on success, <0 on failure. A failed
 * protect MUST fail the dial — failing open creates a routing loop. */
typedef int32_t (*ff_protect_fn)(int32_t fd);

/* Ask the platform to resend the complete current state (NetifUpdate for every
 * live network, then NetifDefaultChanged). Invoke it from the Go monitor's
 * Start() so the engine never begins with an empty view of the world. */
typedef void (*ff_replay_fn)(void);

/* Exported by the Go engine; the shim calls it once after resolving symbols. */
void NetifRegisterPlatform(ff_protect_fn protect, ff_replay_fn replay);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* FASTFLOW_NETIF_BRIDGE_H */
