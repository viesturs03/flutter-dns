package com.example.dns_switcher

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import java.io.IOException
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import java.nio.channels.DatagramChannel

class MyVpnService : VpnService() {
    companion object {
        private const val VPN_MTU = 1500
        private const val PRIVATE_VLAN4_CLIENT = "10.0.0.2"
        private const val PRIVATE_VLAN4_ROUTER = "10.0.0.1"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "VPN_CHANNEL"
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var isRunning = false
    private var dnsAddresses: List<String> = emptyList()

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP_VPN") {
            stopVPN()
            return START_NOT_STICKY
        }

        val addresses = intent?.getStringArrayListExtra("dnsAddresses")
        if (!addresses.isNullOrEmpty()) {
            dnsAddresses = addresses
            startVPN()
        }

        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VPN Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "DNS Switcher VPN Service"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("DNS Switcher Active")
            .setContentText("Using DNS: ${dnsAddresses.joinToString(", ")}")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun startVPN() {
        try {
            val builder = Builder()
            builder.setMtu(VPN_MTU)
            builder.addAddress(PRIVATE_VLAN4_CLIENT, 32)
            builder.addRoute("0.0.0.0", 0)
            
            // Set DNS servers
            for (dns in dnsAddresses) {
                builder.addDnsServer(dns.trim())
            }
            
            builder.setSession("DNS Switcher VPN")
            builder.setConfigureIntent(
                PendingIntent.getActivity(
                    this, 0,
                    Intent(this, MainActivity::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )

            vpnInterface = builder.establish()
            
            if (vpnInterface != null) {
                isRunning = true
                startForeground(NOTIFICATION_ID, createNotification())
                
                // Start a background thread to handle VPN traffic
                Thread { handleVPNTraffic() }.start()
            }
        } catch (e: Exception) {
            e.printStackTrace()
            stopVPN()
        }
    }

    private fun handleVPNTraffic() {
        try {
            val vpnInput = vpnInterface?.fileDescriptor?.let { 
                java.io.FileInputStream(it) 
            }
            val vpnOutput = vpnInterface?.fileDescriptor?.let { 
                java.io.FileOutputStream(it) 
            }
            
            val packet = ByteArray(VPN_MTU)
            
            while (isRunning && vpnInput != null) {
                val length = vpnInput.read(packet)
                if (length > 0) {
                    // Basic packet handling - in a real implementation,
                    // you would parse and route the packets properly
                    // For DNS switching, we mainly need the VPN to route DNS queries
                    // through our specified DNS servers
                }
            }
        } catch (e: IOException) {
            e.printStackTrace()
        }
    }

    private fun stopVPN() {
        isRunning = false
        
        try {
            vpnInterface?.close()
            vpnInterface = null
        } catch (e: IOException) {
            e.printStackTrace()
        }
        
        stopForeground(true)
        stopSelf()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopVPN()
    }
}