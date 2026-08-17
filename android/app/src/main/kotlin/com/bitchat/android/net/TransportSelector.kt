package com.bitchat.android.net

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class ActiveTransportMode {
    INTERNET_BRIDGE,
    BLE_MESH
}

class TransportSelector(private val context: Context) {

    companion object {
        private const val TAG = "TransportSelector"
    }

    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    private val _transportMode = MutableStateFlow(ActiveTransportMode.BLE_MESH)
    val transportMode: StateFlow<ActiveTransportMode> = _transportMode.asStateFlow()

    private val _isInternetAvailable = MutableStateFlow(false)
    val isInternetAvailable: StateFlow<Boolean> = _isInternetAvailable.asStateFlow()

    var onConnectivityRestoredListener: (() -> Unit)? = null

    init {
        registerNetworkCallback()
    }

    fun isOnline(): Boolean {
        val activeNetwork = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
               capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }

    private fun registerNetworkCallback() {
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        connectivityManager.registerNetworkCallback(request, object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                Log.i(TAG, "🌐 Internet connectivity RESTORED - switching transport to INTERNET_BRIDGE")
                _isInternetAvailable.value = true
                _transportMode.value = ActiveTransportMode.INTERNET_BRIDGE
                onConnectivityRestoredListener?.invoke()
            }

            override fun onLost(network: Network) {
                Log.w(TAG, "📡 Internet connectivity LOST - falling back to BLE_MESH transport")
                _isInternetAvailable.value = false
                _transportMode.value = ActiveTransportMode.BLE_MESH
            }
        })
    }
}
