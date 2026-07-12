package com.fastflow.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.Network
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor

/**
 * The tunnel-owning VpnService. It runs in the app process, so the Go engine
 * (driven from Dart via FFI) shares the fd this service produces.
 *
 * Socket protection is belt-and-braces: the builder adds our own package to the
 * disallowed list (routing-level bypass), and once the Go engine registers its
 * platform hooks (NetifRegisterPlatform), per-socket VpnService.protect() also
 * flows up through NativeBridge.protectSocket.
 *
 * While the service is active, [NativeBridge] runs a [NetworkStateMonitor] that
 * streams underlying-network state down to the Go engine — the platform
 * replacement for the netlink monitor that sing-box's route.NewNetworkManager
 * cannot use inside the VpnService sandbox.
 */
class FastFlowVpnService : VpnService() {

    companion object {
        const val ACTION_START = "com.fastflow.vpn.START"
        const val ACTION_STOP = "com.fastflow.vpn.STOP"

        private const val CHANNEL_ID = "fastflow_vpn"
        private const val NOTIF_ID = 1

        @Volatile
        var instance: FastFlowVpnService? = null

        /** Set by MainActivity before ACTION_START; invoked with the tunnel fd. */
        @Volatile
        var pendingEstablish: ((Int) -> Unit)? = null

        /** Kill-switch preference; applied when (re)building the tunnel. */
        @Volatile
        var killSwitch: Boolean = false
    }

    private var tun: ParcelFileDescriptor? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            NativeBridge.stopMonitor()
            stopTunnel()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        startForegroundInternal()
        // Feed the Go engine's platform interface monitor for the lifetime of
        // the tunnel. Started before establish() so the engine already has the
        // current network state by the time Dart calls StartEngine.
        NativeBridge.startMonitor(this)
        val fd = if (intent != null) establish(intent) else -1
        pendingEstablish?.invoke(fd)
        pendingEstablish = null

        // STICKY so the tunnel (and kill switch) survives a process restart.
        return START_STICKY
    }

    private fun establish(intent: Intent): Int {
        // Always dual-stack: the interface carries a v6 ULA and a `::/0` route so
        // native IPv6 is captured INTO the tunnel instead of leaking out the
        // underlying network. When the user disables IPv6 the in-process sing-box
        // engine blackholes the captured v6 (see RoutingBuilder); dropping the v6
        // route here would send IPv6 straight out the physical NIC, bypassing the
        // tunnel and the kill switch.
        val addresses = intent.getStringArrayListExtra("addresses")
            ?: arrayListOf("172.19.0.1/28", "fdfe:dcba:9876::1/126")
        val routes = intent.getStringArrayListExtra("routes")
            ?: arrayListOf("0.0.0.0/0", "::/0")
        val dns = intent.getStringArrayListExtra("dns") ?: arrayListOf<String>()
        val disallowed = intent.getStringArrayListExtra("disallowedApps") ?: arrayListOf<String>()
        val mtu = intent.getIntExtra("mtu", 9000)

        stopTunnel() // replace any previous interface

        val builder = Builder()
            .setSession("FastFlow")
            .setMtu(mtu)
            .setBlocking(killSwitch) // kill switch: hold packets instead of leaking

        // Add the v6 address first so the subsequent `::/0` route is accepted;
        // runCatching keeps a device that rejects a family from failing establish.
        for (cidr in addresses) {
            val parsed = splitCidr(cidr) ?: continue
            runCatching { builder.addAddress(parsed.first, parsed.second) }
        }
        for (cidr in routes) {
            val parsed = splitCidr(cidr) ?: continue
            runCatching { builder.addRoute(parsed.first, parsed.second) }
        }
        for (server in dns) builder.addDnsServer(server)

        // Exclude ourselves (protect substitute) + any user split-tunnel excludes.
        runCatching { builder.addDisallowedApplication(packageName) }
        for (pkg in disallowed) runCatching { builder.addDisallowedApplication(pkg) }

        val pfd = builder.establish() ?: return -1
        tun = pfd
        return pfd.detachFd() // hand ownership to the engine
    }

    fun setKillSwitch(enabled: Boolean) {
        killSwitch = enabled
        // Takes effect on the next establish; the Dart layer triggers a reconnect.
    }

    fun refreshUnderlyingNetworks() {
        // Reset so the tunnel follows the new default network after roaming.
        runCatching { setUnderlyingNetworks(null) }
    }

    /**
     * Called by [NativeBridge] whenever the monitor's default (underlying)
     * network changes: pins the OS's view of what carries the tunnel, fixing
     * power/data accounting and captive-portal probing after a Wi-Fi <->
     * cellular handover. Null lets the system decide again.
     */
    fun updateUnderlyingNetworks(network: Network?) {
        runCatching { setUnderlyingNetworks(network?.let { arrayOf(it) }) }
    }

    private fun splitCidr(cidr: String): Pair<String, Int>? {
        val parts = cidr.split("/")
        if (parts.size != 2) return null
        val prefix = parts[1].toIntOrNull() ?: return null
        return parts[0] to prefix
    }

    private fun stopTunnel() {
        runCatching { tun?.close() }
        tun = null
    }

    private fun startForegroundInternal() {
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "VPN", NotificationManager.IMPORTANCE_LOW)
            )
        }

        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setContentTitle("FastFlow VPN")
            .setContentText("Tunnel active")
            .setSmallIcon(R.drawable.ic_launcher)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .build()

        // The manifest declares foregroundServiceType="specialUse"; the 2-arg
        // startForeground uses that type across API levels.
        startForeground(NOTIF_ID, notification)
    }

    override fun onRevoke() {
        // System or another VPN app revoked us.
        NativeBridge.stopMonitor()
        stopTunnel()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        super.onRevoke()
    }

    override fun onDestroy() {
        NativeBridge.stopMonitor()
        stopTunnel()
        instance = null
        super.onDestroy()
    }
}
