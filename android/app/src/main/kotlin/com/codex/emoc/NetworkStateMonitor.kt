package com.codex.emoc

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper

class NetworkStateMonitor(context: Context, private val changed: (Map<String, Any>) -> Unit) {
    private val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val handler = Handler(Looper.getMainLooper())
    private var registered = false
    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = publish()
        override fun onLost(network: Network) = publish()
        override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) = publish()
    }

    fun snapshot(): Map<String, Any> {
        val capabilities = manager.getNetworkCapabilities(manager.activeNetwork)
        return mapOf(
            "connected" to (capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true),
            "metered" to manager.isActiveNetworkMetered,
            "wifi" to (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true)
        )
    }

    fun start() {
        if (registered) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            manager.registerDefaultNetworkCallback(callback)
        } else {
            manager.registerNetworkCallback(NetworkRequest.Builder().addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET).build(), callback)
        }
        registered = true
    }

    private fun publish() { handler.post { if (registered) changed(snapshot()) } }

    fun close() {
        if (registered) manager.unregisterNetworkCallback(callback)
        registered = false
        handler.removeCallbacksAndMessages(null)
    }
}
