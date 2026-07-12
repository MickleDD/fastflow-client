package com.fastflow.vpn

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import java.net.NetworkInterface

/**
 * Watches the underlying (non-VPN) networks through ConnectivityManager and
 * feeds every change to [sink] as flat, JNI-friendly values. This is the
 * platform half of the sing-box "platform interface monitor": inside the
 * VpnService sandbox the Go core cannot open netlink sockets, so
 * route.NewNetworkManager must be driven from here instead.
 *
 * Two registrations, two jobs:
 *  - `registerNetworkCallback(INTERNET)` tracks EVERY candidate network
 *    (Wi-Fi and cellular simultaneously, interface names, addresses, MTU) —
 *    this backs the engine's `Interfaces()` platform getter.
 *  - `requestNetwork` / `registerBestMatchingNetworkCallback` (API 31+) tracks
 *    the BEST network — this backs the engine's default-interface monitor.
 *    Deliberately NOT `registerDefaultNetworkCallback`: once our tunnel is up,
 *    the app's own default network IS the VPN, which would feed `tun0` back
 *    into the engine and create a feedback loop. `NetworkRequest.Builder()`
 *    carries NOT_VPN by default, so both registrations only ever see
 *    underlying networks.
 *
 * Threading: all callback bodies hop onto one HandlerThread, so state is
 * single-threaded and downcalls into JNI arrive strictly ordered. Snapshots
 * are deduplicated (capability callbacks fire on every signal-strength tick).
 */
class NetworkStateMonitor(
    context: Context,
    private val sink: Sink,
    private val onDefaultNetworkObject: ((Network?) -> Unit)? = null,
) {

    /** Receiver of flattened network state; implemented by [NativeBridge]. */
    interface Sink {
        fun onNetworkUpdate(
            handle: Long, ifName: String, ifIndex: Int, mtu: Int,
            flags: Int, addresses: String, dnsServers: String,
        )
        fun onNetworkLost(handle: Long)
        fun onDefaultNetworkChanged(handle: Long, ifName: String, ifIndex: Int, flags: Int)
        fun onReset()
    }

    companion object {
        private const val TAG = "FFNetifMonitor"

        /** Bit flags — MUST mirror FF_NETIF_* in data/vpn_engine/netif_bridge.h. */
        const val FLAG_WIFI = 1 shl 0
        const val FLAG_CELLULAR = 1 shl 1
        const val FLAG_ETHERNET = 1 shl 2
        const val FLAG_BLUETOOTH = 1 shl 3
        const val FLAG_METERED = 1 shl 8
        const val FLAG_CONSTRAINED = 1 shl 9
        const val FLAG_VALIDATED = 1 shl 10

        /** Mirrors FF_NETIF_NO_HANDLE. */
        const val NO_NETWORK_HANDLE = -1L
    }

    private val connectivity = context.applicationContext
        .getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    /** Per-network accumulator; a snapshot is emitted once both halves exist. */
    private class TrackedNetwork(val network: Network) {
        var caps: NetworkCapabilities? = null
        var props: LinkProperties? = null
        var lastSent: NetifSnapshot? = null
    }

    // All fields below are touched only on the monitor thread.
    private val tracked = HashMap<Long, TrackedNetwork>()
    private var defaultNetwork: Network? = null
    private var defaultCaps: NetworkCapabilities? = null
    private var defaultProps: LinkProperties? = null
    private var lastDefaultSent: DefaultSnapshot? = null

    @Volatile private var running = false
    @Volatile private var handler: Handler? = null
    private var thread: HandlerThread? = null

    /** Serialize onto the monitor thread; drop after stop(); never throw out. */
    private fun post(block: () -> Unit) {
        handler?.post {
            if (!running) return@post
            try {
                block()
            } catch (t: Throwable) {
                Log.e(TAG, "monitor task failed", t)
            }
        }
    }

    // ── All candidate networks (backs the platform interface getter) ────────

    private val networksCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = post {
            tracked.getOrPut(network.networkHandle) { TrackedNetwork(network) }
            // Emitted once capabilities + link properties arrive; the framework
            // delivers both immediately after onAvailable.
        }

        override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) = post {
            val t = tracked.getOrPut(network.networkHandle) { TrackedNetwork(network) }
            t.caps = caps
            emitIfComplete(t)
        }

        override fun onLinkPropertiesChanged(network: Network, props: LinkProperties) = post {
            val t = tracked.getOrPut(network.networkHandle) { TrackedNetwork(network) }
            t.props = props
            emitIfComplete(t)
        }

        override fun onLost(network: Network) = post {
            val handle = network.networkHandle
            // Only announce the loss of networks we actually announced.
            if (tracked.remove(handle)?.lastSent != null) sink.onNetworkLost(handle)
        }
    }

    // ── Best underlying network (backs the default-interface monitor) ───────

    private val defaultCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = post {
            defaultNetwork = network
            // Seed synchronously; the change callbacks refine right afterwards
            // (guaranteed on API 26+, best-effort seed covers 24/25).
            defaultCaps = connectivity.getNetworkCapabilities(network)
            defaultProps = connectivity.getLinkProperties(network)
            onDefaultNetworkObject?.invoke(network)
            emitDefault()
        }

        override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) = post {
            if (network == defaultNetwork) {
                defaultCaps = caps
                emitDefault()
            }
        }

        override fun onLinkPropertiesChanged(network: Network, props: LinkProperties) = post {
            if (network == defaultNetwork) {
                defaultProps = props
                emitDefault()
            }
        }

        override fun onLost(network: Network) = post {
            if (network == defaultNetwork) clearDefault()
        }

        override fun onUnavailable() = post { clearDefault() }
    }

    // ── Lifecycle ────────────────────────────────────────────────────────────

    fun start() {
        synchronized(this) {
            if (running) return
            running = true
            thread = HandlerThread("ff-netif-monitor").also {
                it.start()
                handler = Handler(it.looper)
            }
        }

        // Builder() implies NOT_VPN | TRUSTED | NOT_RESTRICTED: our own TUN
        // can never match either registration.
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        runCatching { connectivity.registerNetworkCallback(request, networksCallback) }
            .onFailure { Log.e(TAG, "registerNetworkCallback failed", it) }
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                connectivity.registerBestMatchingNetworkCallback(
                    request, defaultCallback, handler!!
                )
            } else {
                // Pre-S equivalent; needs CHANGE_NETWORK_STATE (manifest).
                connectivity.requestNetwork(request, defaultCallback)
            }
        }.onFailure { Log.e(TAG, "default-network callback registration failed", it) }
    }

    fun stop() {
        val h: Handler?
        synchronized(this) {
            if (!running) return
            running = false
            h = handler
        }
        runCatching { connectivity.unregisterNetworkCallback(networksCallback) }
        runCatching { connectivity.unregisterNetworkCallback(defaultCallback) }
        // Bypass the running gate for our own final cleanup, then wind down.
        h?.post {
            tracked.clear()
            defaultNetwork = null
            defaultCaps = null
            defaultProps = null
            lastDefaultSent = null
            runCatching { sink.onReset() }
        }
        synchronized(this) {
            thread?.quitSafely() // queued work (incl. the cleanup above) still runs
            thread = null
            handler = null
        }
    }

    /**
     * Re-emits the full current state (every network + the default), ignoring
     * deduplication. Invoked — via Go → JNI → [NativeBridge.replayNetworkState]
     * — when the engine's monitor starts, so it never begins from an empty view
     * even though it binds after this monitor started.
     */
    fun replay() {
        post {
            for (t in tracked.values) {
                t.lastSent = null
                emitIfComplete(t)
            }
            lastDefaultSent = null
            emitDefault()
        }
    }

    // ── Snapshot construction & emission (monitor thread only) ──────────────

    private fun emitIfComplete(t: TrackedNetwork) {
        val caps = t.caps ?: return
        val props = t.props ?: return
        // Paranoia: requests already exclude VPNs via the builder defaults.
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) return
        val snapshot = buildSnapshot(t.network.networkHandle, caps, props) ?: return
        if (snapshot == t.lastSent) return
        t.lastSent = snapshot
        sink.onNetworkUpdate(
            snapshot.handle, snapshot.ifName, snapshot.ifIndex, snapshot.mtu,
            snapshot.flags, snapshot.addresses, snapshot.dnsServers,
        )
    }

    private fun emitDefault() {
        val network = defaultNetwork ?: return
        val ifName = defaultProps?.interfaceName ?: return // wait for link props
        val ifIndex = interfaceIndexOf(ifName)
        val flags = defaultCaps?.let { flagsOf(it) } ?: 0
        val snapshot = DefaultSnapshot(network.networkHandle, ifName, ifIndex, flags)
        if (snapshot == lastDefaultSent) return
        lastDefaultSent = snapshot
        sink.onDefaultNetworkChanged(snapshot.handle, snapshot.ifName, snapshot.ifIndex, snapshot.flags)
    }

    private fun clearDefault() {
        defaultNetwork = null
        defaultCaps = null
        defaultProps = null
        onDefaultNetworkObject?.invoke(null)
        val snapshot = DefaultSnapshot(NO_NETWORK_HANDLE, "", -1, 0)
        if (snapshot != lastDefaultSent) {
            lastDefaultSent = snapshot
            sink.onDefaultNetworkChanged(snapshot.handle, snapshot.ifName, snapshot.ifIndex, snapshot.flags)
        }
    }

    private fun buildSnapshot(
        handle: Long,
        caps: NetworkCapabilities,
        props: LinkProperties,
    ): NetifSnapshot? {
        val ifName = props.interfaceName ?: return null
        val javaIf = runCatching { NetworkInterface.getByName(ifName) }.getOrNull()
        val ifIndex = javaIf?.index ?: -1
        var mtu = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) props.mtu else 0
        if (mtu <= 0) mtu = runCatching { javaIf?.mtu ?: 0 }.getOrDefault(0)

        // Zone identifiers ("fe80::1%wlan0") break Go's netip parsers; strip
        // them — the Go side can re-derive the zone from if_index.
        val addresses = props.linkAddresses.mapNotNull { la ->
            la.address?.hostAddress?.substringBefore('%')?.let { "$it/${la.prefixLength}" }
        }.joinToString(",")
        val dns = props.dnsServers
            .mapNotNull { it.hostAddress?.substringBefore('%') }
            .joinToString(",")

        return NetifSnapshot(handle, ifName, ifIndex, mtu, flagsOf(caps), addresses, dns)
    }

    private fun interfaceIndexOf(ifName: String): Int =
        runCatching { NetworkInterface.getByName(ifName)?.index }.getOrNull() ?: -1

    private fun flagsOf(caps: NetworkCapabilities): Int {
        var flags = 0
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) flags = flags or FLAG_WIFI
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) flags = flags or FLAG_CELLULAR
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) flags = flags or FLAG_ETHERNET
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH)) flags = flags or FLAG_BLUETOOTH
        if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)) {
            flags = flags or FLAG_METERED
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
            !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_CONGESTED)
        ) {
            flags = flags or FLAG_CONSTRAINED
        }
        if (caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)) {
            flags = flags or FLAG_VALIDATED
        }
        return flags
    }

    private data class NetifSnapshot(
        val handle: Long,
        val ifName: String,
        val ifIndex: Int,
        val mtu: Int,
        val flags: Int,
        val addresses: String,
        val dnsServers: String,
    )

    private data class DefaultSnapshot(
        val handle: Long,
        val ifName: String,
        val ifIndex: Int,
        val flags: Int,
    )
}
