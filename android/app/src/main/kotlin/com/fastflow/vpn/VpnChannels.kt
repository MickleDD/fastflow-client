package com.fastflow.vpn

import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Registers every platform channel the Dart infrastructure layer uses. Shared by
 * [MainActivity] (interactive) and [AutoConnectService] (headless boot engine),
 * so a boot-time reconnect goes through exactly the same code as a user connect.
 *
 * @param context      an app/service context used to start services and read state.
 * @param prepareConsent invoked only when the VPN consent dialog is required and an
 *        Activity is available to show it. Null in the headless case — consent must
 *        already have been granted, otherwise `prepare` reports false.
 */
class VpnChannels(
    private val context: Context,
    private val prepareConsent: ((MethodChannel.Result) -> Unit)?,
) {
    companion object {
        const val VPN_CHANNEL = "fastflow/vpn"
        const val ROUTE_CHANNEL = "fastflow/route"
        const val WIFI_METHOD_CHANNEL = "fastflow/wifi"
        const val WIFI_EVENT_CHANNEL = "fastflow/wifi_events"
        const val BOOT_CHANNEL = "fastflow/boot"

        const val PREFS = "fastflow_prefs"
        const val PREF_AUTO_START = "auto_start"
    }

    private var wifiProvider: WifiStateProvider? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, VPN_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "prepare" -> onPrepare(result)
                "establish" -> onEstablish(call.arguments, result)
                "stop" -> {
                    context.startService(
                        Intent(context, FastFlowVpnService::class.java)
                            .setAction(FastFlowVpnService.ACTION_STOP)
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, ROUTE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setKillSwitch" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    FastFlowVpnService.killSwitch = enabled
                    FastFlowVpnService.instance?.setKillSwitch(enabled)
                    result.success(null)
                }
                "openAlwaysOnSettings" -> {
                    runCatching {
                        context.startActivity(
                            Intent(Settings.ACTION_VPN_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                    }
                    result.success(null)
                }
                "isAlwaysOnEnabled" -> result.success(false) // no public query API
                "refreshNetworks" -> {
                    FastFlowVpnService.instance?.refreshUnderlyingNetworks()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        val provider = WifiStateProvider(context).also { wifiProvider = it }
        MethodChannel(messenger, WIFI_METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "current" -> result.success(provider.current())
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, WIFI_EVENT_CHANNEL).setStreamHandler(provider)

        // Lets the Dart layer persist whether to re-arm the tunnel after reboot;
        // BootReceiver reads this flag without needing a running Flutter engine.
        MethodChannel(messenger, BOOT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAutoStart" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                        .edit().putBoolean(PREF_AUTO_START, enabled).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun onPrepare(result: MethodChannel.Result) {
        val consent = VpnService.prepare(context)
        when {
            consent == null -> result.success(true) // already granted
            prepareConsent != null -> prepareConsent.invoke(result) // show dialog
            else -> result.success(false) // headless: cannot prompt at boot
        }
    }

    private fun onEstablish(arguments: Any?, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val args = arguments as? Map<String, Any?> ?: emptyMap()
        val addresses = (args["addresses"] as? List<*>)?.map { it.toString() }
            ?: listOf("172.19.0.1/28")
        val dns = (args["dns"] as? List<*>)?.map { it.toString() } ?: emptyList()
        val routes = (args["routes"] as? List<*>)?.map { it.toString() }
            ?: listOf("0.0.0.0/0")
        val disallowed =
            (args["disallowedApps"] as? List<*>)?.map { it.toString() } ?: emptyList()
        val mtu = (args["mtu"] as? Int) ?: 9000
        val ipv6 = (args["ipv6"] as? Boolean) ?: false

        FastFlowVpnService.pendingEstablish = { fd ->
            // Reply on the platform thread; MethodChannel results are not
            // thread-affine but we keep responses ordered from a single thread.
            if (fd >= 0) {
                result.success(fd)
            } else {
                result.error("establish_failed", "VpnService.establish() returned null", null)
            }
        }

        val intent = Intent(context, FastFlowVpnService::class.java).apply {
            action = FastFlowVpnService.ACTION_START
            putStringArrayListExtra("addresses", ArrayList(addresses))
            putStringArrayListExtra("dns", ArrayList(dns))
            putStringArrayListExtra("routes", ArrayList(routes))
            putStringArrayListExtra("disallowedApps", ArrayList(disallowed))
            putExtra("mtu", mtu)
            putExtra("ipv6", ipv6)
        }
        ContextCompat.startForegroundService(context, intent)
    }
}
