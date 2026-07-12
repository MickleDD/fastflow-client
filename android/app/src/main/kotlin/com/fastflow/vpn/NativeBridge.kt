package com.fastflow.vpn

import android.content.Context
import android.util.Log
import androidx.annotation.Keep

/**
 * The JNI seam between the Kotlin platform layer and the Go engine
 * (libvpn_engine.so), through the C++ shim libfastflow_jni.so.
 *
 * Downward — [NetworkStateMonitor] state flows through the `nativeNetif*`
 * externals into the engine's `Netif*` cgo exports (contract:
 * data/vpn_engine/netif_bridge.h), replacing the netlink monitor that
 * sing-box's route.NewNetworkManager cannot run inside the VpnService sandbox.
 *
 * Upward — Go calls back through function pointers it receives from the shim
 * at bind time: [protectSocket] (VpnService.protect for upstream sockets) and
 * [replayNetworkState] (full state resend when the engine's monitor starts).
 *
 * Everything degrades gracefully: if the shim or the engine exports are
 * missing (e.g. an engine built before the platform-monitor support), the
 * monitor simply doesn't feed anything and the app keeps running.
 *
 * @Keep + proguard-rules.pro protect the reflective JNI lookups: the shim's
 * JNI_OnLoad resolves this object and its members strictly by name
 * (RegisterNatives for the externals, GetStaticMethodID for the upcalls).
 */
@Keep
object NativeBridge : NetworkStateMonitor.Sink {

    private const val TAG = "FFNativeBridge"

    /** soname of the Go engine; also loaded by Dart FFI (dlopen is refcounted). */
    private const val ENGINE_SONAME = "libvpn_engine.so"

    @Volatile private var jniLoaded = false
    @Volatile private var engineBound = false
    @Volatile private var monitor: NetworkStateMonitor? = null

    // ── Lifecycle (called by FastFlowVpnService) ─────────────────────────────

    /** Idempotently starts the network monitor that feeds the Go engine. */
    @Synchronized
    fun startMonitor(context: Context) {
        ensureEngineBound() // best effort; retried on every start
        if (!jniLoaded) {
            Log.w(TAG, "JNI shim unavailable; platform network monitor disabled")
            return
        }
        if (monitor != null) return
        monitor = NetworkStateMonitor(
            context.applicationContext,
            sink = this,
            onDefaultNetworkObject = { network ->
                // Keep the OS's picture of what carries the tunnel current.
                FastFlowVpnService.instance?.updateUnderlyingNetworks(network)
            },
        ).also { it.start() }
    }

    /** Stops the monitor; onReset tells Go to drop all cached interfaces. */
    @Synchronized
    fun stopMonitor() {
        monitor?.stop()
        monitor = null
    }

    // ── Loading / binding ────────────────────────────────────────────────────

    @Synchronized
    private fun ensureLoaded(): Boolean {
        if (jniLoaded) return true
        // Engine first, so the shim's dlopen() resolves an already-mapped
        // library. Tolerate absence: Dart FFI may load it later, and the shim
        // retries binding on every startMonitor().
        runCatching { System.loadLibrary("vpn_engine") }
            .onFailure { Log.w(TAG, "libvpn_engine.so not loadable: ${it.message}") }
        return runCatching { System.loadLibrary("fastflow_jni") }
            .onSuccess { jniLoaded = true }
            .onFailure { Log.e(TAG, "libfastflow_jni.so missing", it) }
            .isSuccess
    }

    @Synchronized
    private fun ensureEngineBound(): Boolean {
        if (engineBound) return true
        if (!ensureLoaded()) return false
        engineBound = nativeInit(ENGINE_SONAME)
        if (!engineBound) {
            Log.w(
                TAG,
                "engine Netif* exports not bound; network updates are dropped " +
                    "until an engine with platform-monitor support is shipped",
            )
        }
        return engineBound
    }

    // ── Upcalls from native (Go threads; names/signatures fixed by the shim) ─

    /** VpnService.protect for the engine's upstream sockets. Must never throw. */
    @JvmStatic
    fun protectSocket(fd: Int): Boolean = try {
        // With no live VpnService there is no tunnel to loop through
        // (proxy-only mode): report success so dials proceed.
        FastFlowVpnService.instance?.protect(fd) ?: true
    } catch (t: Throwable) {
        Log.e(TAG, "protectSocket($fd) failed", t)
        false
    }

    /** The Go monitor started: resend every live network plus the default. */
    @JvmStatic
    fun replayNetworkState() {
        try {
            monitor?.replay()
        } catch (t: Throwable) {
            Log.e(TAG, "replayNetworkState failed", t)
        }
    }

    // ── Sink: monitor thread → JNI downcalls ─────────────────────────────────

    override fun onNetworkUpdate(
        handle: Long, ifName: String, ifIndex: Int, mtu: Int,
        flags: Int, addresses: String, dnsServers: String,
    ) {
        if (jniLoaded) nativeNetifUpdate(handle, ifName, ifIndex, mtu, flags, addresses, dnsServers)
    }

    override fun onNetworkLost(handle: Long) {
        if (jniLoaded) nativeNetifLost(handle)
    }

    override fun onDefaultNetworkChanged(handle: Long, ifName: String, ifIndex: Int, flags: Int) {
        if (jniLoaded) nativeNetifDefaultChanged(handle, ifName, ifIndex, flags)
    }

    override fun onReset() {
        if (jniLoaded) nativeNetifReset()
    }

    // ── Externals (bound via RegisterNatives in fastflow_jni.cpp JNI_OnLoad) ─

    @JvmStatic
    private external fun nativeInit(engineSoname: String): Boolean

    @JvmStatic
    private external fun nativeNetifUpdate(
        handle: Long, ifName: String, ifIndex: Int, mtu: Int,
        flags: Int, addresses: String, dnsServers: String,
    )

    @JvmStatic
    private external fun nativeNetifLost(handle: Long)

    @JvmStatic
    private external fun nativeNetifDefaultChanged(
        handle: Long, ifName: String, ifIndex: Int, flags: Int,
    )

    @JvmStatic
    private external fun nativeNetifReset()
}
