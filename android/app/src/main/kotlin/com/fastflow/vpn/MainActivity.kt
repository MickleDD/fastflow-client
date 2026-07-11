package com.fastflow.vpn

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the interactive Flutter engine and registers the platform channels via
 * [VpnChannels]. The only Activity-specific concern here is the VPN consent
 * dialog, which must be shown from an Activity and completed in onActivityResult.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val REQUEST_VPN_PREPARE = 0x1001
    }

    private var pendingPrepare: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        VpnChannels(this) { result ->
            // Consent is required (VpnService.prepare returned non-null); show it.
            val consent = VpnService.prepare(this)
            if (consent == null) {
                result.success(true)
            } else {
                pendingPrepare = result
                startActivityForResult(consent, REQUEST_VPN_PREPARE)
            }
        }.register(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_VPN_PREPARE) {
            pendingPrepare?.success(resultCode == Activity.RESULT_OK)
            pendingPrepare = null
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
