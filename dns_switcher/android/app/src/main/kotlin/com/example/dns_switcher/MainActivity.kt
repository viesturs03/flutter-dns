package com.example.dns_switcher

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import androidx.activity.result.ActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    // Fixed: Changed channel name to match Flutter side
    private val CHANNEL = "com.example.dns_switcher/vpn"
    private var startVpnResult: MethodChannel.Result? = null
    private var currentCall: MethodCall? = null

    private val vpnPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result: ActivityResult ->
        if (result.resultCode == Activity.RESULT_OK) {
            // VPN permission granted, start the service
            val dnsAddress = currentCall?.argument<String>("dnsAddress")
            if (dnsAddress != null) {
                val intent = Intent(this, MyVpnService::class.java)
                intent.putStringArrayListExtra("dnsAddresses", ArrayList(dnsAddress.split(",").map { it.trim() }))
                startForegroundService(intent)
                startVpnResult?.success(null)
            } else {
                startVpnResult?.error("INVALID_ARGUMENT", "DNS address is required", null)
            }
        } else {
            // VPN permission denied
            startVpnResult?.error("PERMISSION_DENIED", "User denied VPN permission", null)
        }
        startVpnResult = null
        currentCall = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    val dnsAddress = call.argument<String>("dnsAddress")
                    if (dnsAddress != null) {
                        startVpnResult = result
                        currentCall = call
                        
                        // Check if VPN permission is needed
                        val intent = VpnService.prepare(this)
                        if (intent != null) {
                            // Permission needed, launch permission request
                            vpnPermissionLauncher.launch(intent)
                        } else {
                            // Permission already granted, start service directly
                            val serviceIntent = Intent(this, MyVpnService::class.java)
                            serviceIntent.putStringArrayListExtra("dnsAddresses", ArrayList(dnsAddress.split(",").map { it.trim() }))
                            startForegroundService(serviceIntent)
                            result.success(null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "DNS address is required", null)
                    }
                }
                "stopVpn" -> {
                    val intent = Intent(this, MyVpnService::class.java)
                    intent.action = "STOP_VPN"
                    startService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}