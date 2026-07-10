package org.localsend.localsend_app

import android.content.Context
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.NetworkInterface

private const val CHANNEL = "localsend/wifi_direct"

/**
 * Handles WiFi Direct / Local-Only Hotspot via:
 *  - WifiManager.startLocalOnlyHotspot() — Android 8+ (API 26)
 *  - WifiNetworkSpecifier — Android 10+ (API 29) for joining
 *
 * Register in MainActivity.configureFlutterEngine by calling
 *   WifiDirectPlugin.register(flutterEngine, this)
 */
object WifiDirectPlugin {
    private var hotspotCallback: WifiManager.LocalOnlyHotspotCallback? = null
    private var hotspotReservation: WifiManager.LocalOnlyHotspotReservation? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    fun register(flutterEngine: FlutterEngine, context: Context) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startHotspot" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            handleStartHotspot(context, result)
                        } else {
                            result.error("UNSUPPORTED", "WiFi hotspot requires Android 8.0 (API 26) or higher", null)
                        }
                    }
                    "stopHotspot"  -> handleStopHotspot(result)
                    "joinHotspot"  -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            handleJoinHotspot(context, call, result)
                        } else {
                            result.error("UNSUPPORTED", "Joining hotspot requires Android 10 (API 29) or higher", null)
                        }
                    }
                    "leaveHotspot" -> handleLeaveHotspot(context, result)
                    else           -> result.notImplemented()
                }
            }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun handleStartHotspot(context: Context, result: MethodChannel.Result) {
        val wifiManager = context.applicationContext
            .getSystemService(Context.WIFI_SERVICE) as WifiManager

        hotspotReservation?.close()
        hotspotReservation = null

        val callback = object : WifiManager.LocalOnlyHotspotCallback() {
            override fun onStarted(reservation: WifiManager.LocalOnlyHotspotReservation) {
                hotspotReservation = reservation
                val ssid = reservation.wifiConfiguration?.SSID
                    ?: reservation.softApConfiguration?.ssid
                val pass = reservation.wifiConfiguration?.preSharedKey
                    ?: reservation.softApConfiguration?.passphrase

                if (ssid != null && pass != null) {
                    // The AP interface may take a moment to acquire its address,
                    // so resolve the host IP with a short retry before replying.
                    resolveHotspotIpWithRetry(3) { hostIp ->
                        Handler(Looper.getMainLooper()).post {
                            val payload = mutableMapOf("ssid" to ssid, "passphrase" to pass)
                            if (hostIp != null) payload["host"] = hostIp
                            result.success(payload)
                        }
                    }
                } else {
                    Handler(Looper.getMainLooper()).post {
                        result.error("NO_CREDENTIALS", "Could not read hotspot credentials", null)
                    }
                }
            }

            override fun onFailed(reason: Int) {
                Handler(Looper.getMainLooper()).post {
                    result.error("START_FAILED", "Hotspot start failed: reason=$reason", null)
                }
            }

            override fun onStopped() {
                hotspotReservation = null
            }
        }

        hotspotCallback = callback
        wifiManager.startLocalOnlyHotspot(callback, Handler(Looper.getMainLooper()))
    }

    /**
     * Resolves the host's own IPv4 on the local-only hotspot (SoftAP) interface.
     * Prefers AP-like interfaces (ap, swlan, softap, wlan1, p2p); otherwise falls
     * back to any non-loopback site-local IPv4. Retries because the AP interface
     * may not have its address immediately after the hotspot starts.
     */
    private fun resolveHotspotIpWithRetry(attemptsLeft: Int, callback: (String?) -> Unit) {
        val ip = resolveHotspotIp()
        if (ip != null || attemptsLeft <= 0) {
            callback(ip)
        } else {
            Handler(Looper.getMainLooper()).postDelayed({
                resolveHotspotIpWithRetry(attemptsLeft - 1, callback)
            }, 500)
        }
    }

    private fun resolveHotspotIp(): String? {
        return try {
            val interfaces = NetworkInterface.getNetworkInterfaces() ?: return null
            var fallback: String? = null
            for (intf in interfaces) {
                if (!intf.isUp || intf.isLoopback) continue
                val name = intf.name.lowercase()
                val isApLike = name.startsWith("ap") || name.startsWith("swlan") ||
                    name.startsWith("softap") || name == "wlan1" || name.contains("p2p")
                for (addr in intf.inetAddresses) {
                    if (addr is Inet4Address && !addr.isLoopbackAddress && addr.isSiteLocalAddress) {
                        val host = addr.hostAddress ?: continue
                        if (isApLike) return host
                        if (fallback == null) fallback = host
                    }
                }
            }
            fallback
        } catch (e: Exception) {
            null
        }
    }

    private fun handleStopHotspot(result: MethodChannel.Result) {
        hotspotReservation?.close()
        hotspotReservation = null
        hotspotCallback = null
        result.success(null)
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun handleJoinHotspot(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val ssid = call.argument<String>("ssid") ?: run {
            result.error("MISSING_SSID", "ssid is required", null)
            return
        }
        val passphrase = call.argument<String>("passphrase") ?: run {
            result.error("MISSING_PASS", "passphrase is required", null)
            return
        }

        val specifier = WifiNetworkSpecifier.Builder()
            .setSsid(ssid)
            .setWpa2Passphrase(passphrase)
            .build()

        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(specifier)
            .build()

        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        networkCallback?.let { cm.unregisterNetworkCallback(it) }

        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                cm.bindProcessToNetwork(network)
                Handler(Looper.getMainLooper()).post { result.success(null) }
            }

            override fun onUnavailable() {
                Handler(Looper.getMainLooper()).post {
                    result.error("UNAVAILABLE", "Could not connect to $ssid", null)
                }
            }
        }

        networkCallback = callback
        cm.requestNetwork(request, callback)
    }

    private fun handleLeaveHotspot(context: Context, result: MethodChannel.Result) {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        networkCallback?.let {
            cm.unregisterNetworkCallback(it)
            networkCallback = null
        }
        cm.bindProcessToNetwork(null)
        result.success(null)
    }
}
