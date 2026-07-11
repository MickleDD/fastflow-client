package com.fastflow.vpn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.VpnService
import androidx.core.content.ContextCompat

/**
 * Re-arms the tunnel after a reboot (or app update) when the user enabled
 * Always-On / Auto-Connect.
 *
 * Gating is cheap and engine-free: the Dart layer persists an "auto_start" flag
 * (killSwitch || autoConnectInsecureWifi) into SharedPreferences via the
 * fastflow/boot channel; we read it here. We also require that VPN consent was
 * already granted — a boot receiver cannot show the consent dialog.
 *
 * When both hold, we start [AutoConnectService], which spins up a headless
 * Flutter engine to run the same connect logic the UI uses.
 *
 * Note: this is the app-managed path. The OS-native complement is the system
 * "Always-on VPN" setting (Settings → VPN), which restarts our VpnService at
 * boot without any receiver; the app deep-links there via openAlwaysOnSettings.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
            }
            else -> return
        }

        val prefs = context.getSharedPreferences(
            VpnChannels.PREFS, Context.MODE_PRIVATE
        )
        if (!prefs.getBoolean(VpnChannels.PREF_AUTO_START, false)) return

        // Consent must already exist; we can't prompt from a receiver.
        if (VpnService.prepare(context) != null) return

        ContextCompat.startForegroundService(
            context, Intent(context, AutoConnectService::class.java)
        )
    }
}
