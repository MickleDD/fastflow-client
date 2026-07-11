package com.fastflow.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * Boot-time reconnect host. It runs a HEADLESS Flutter engine executing the
 * `vpnBoot` Dart entrypoint, which reads persisted settings and — if auto-start
 * conditions hold — connects using the very same use-cases the UI drives.
 *
 * Why a Flutter engine at boot: our VPN engine (Go) is driven from Dart via FFI,
 * so a reconnect needs Dart running. The headless engine loads the plugins
 * (sqflite/path_provider) and our channels, then vpnBoot performs the connect.
 * The actual tunnel is still built by [FastFlowVpnService] via the fastflow/vpn
 * channel — this service only hosts the engine and holds a foreground notification.
 */
class AutoConnectService : Service() {

    private companion object {
        const val CHANNEL_ID = "fastflow_autostart"
        const val NOTIF_ID = 2
        const val ENTRYPOINT = "vpnBoot"
    }

    private var engine: FlutterEngine? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startForegroundNotice()
        startHeadlessEngine()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int =
        START_STICKY

    private fun startHeadlessEngine() {
        if (engine != null) return

        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)

        val flutterEngine = FlutterEngine(applicationContext)
        // Register pub plugins (sqflite, path_provider, …) so the repositories work.
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        // Register our platform channels (headless: no consent Activity available).
        VpnChannels(applicationContext, null)
            .register(flutterEngine.dartExecutor.binaryMessenger)

        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), ENTRYPOINT)
        )
        engine = flutterEngine
    }

    private fun startForegroundNotice() {
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID, "Auto-connect", NotificationManager.IMPORTANCE_LOW
                )
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setContentTitle("FastFlow VPN")
            .setContentText("Reconnecting after boot…")
            .setSmallIcon(R.drawable.ic_launcher)
            .setOngoing(true)
            .build()
        startForeground(NOTIF_ID, notification)
    }

    override fun onDestroy() {
        engine?.destroy()
        engine = null
        super.onDestroy()
    }
}
