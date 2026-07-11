package com.fastflow.vpn

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Backs wifi_monitor_android.dart. Streams {isWifi, ssid, isSecure} maps on every
 * default-network change (ConnectivityManager) and answers one-shot `current`.
 *
 * Security detection: API 31+ reads WifiInfo.currentSecurityType (OPEN => insecure).
 * On older APIs the security type is not available, so we fail safe to "secure"
 * (auto-connect on open Wi-Fi is a no-op there rather than a false trigger).
 * Reading the SSID / security type requires ACCESS_FINE_LOCATION at runtime.
 */
class WifiStateProvider(private val context: Context) : EventChannel.StreamHandler {

    private val cm =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = emit()
        override fun onLost(network: Network) = emit()
        override fun onCapabilitiesChanged(
            network: Network,
            networkCapabilities: NetworkCapabilities
        ) = emit()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        runCatching { cm.registerDefaultNetworkCallback(callback) }
        emit()
    }

    override fun onCancel(arguments: Any?) {
        runCatching { cm.unregisterNetworkCallback(callback) }
        sink = null
    }

    fun current(): Map<String, Any?> = readState()

    private fun emit() {
        val state = readState()
        main.post { sink?.success(state) }
    }

    private fun readState(): Map<String, Any?> {
        val caps = cm.getNetworkCapabilities(cm.activeNetwork)
        val isWifi = caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
        if (!isWifi) {
            return mapOf("isWifi" to false, "ssid" to null, "isSecure" to true)
        }

        var ssid: String? = null
        var isSecure = true // fail-safe default

        val transportInfo = caps?.transportInfo
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && transportInfo is WifiInfo) {
            ssid = transportInfo.ssid?.trim('"')
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                isSecure = transportInfo.currentSecurityType != WifiInfo.SECURITY_TYPE_OPEN
            }
        } else {
            @Suppress("DEPRECATION")
            val wm = context.applicationContext
                .getSystemService(Context.WIFI_SERVICE) as WifiManager
            @Suppress("DEPRECATION")
            ssid = wm.connectionInfo?.ssid?.trim('"')
        }

        return mapOf("isWifi" to true, "ssid" to ssid, "isSecure" to isSecure)
    }
}
