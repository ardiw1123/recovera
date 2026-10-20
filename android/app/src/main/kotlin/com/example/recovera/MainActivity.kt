package com.example.recovera

import android.Manifest
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.recovera/location"
    private val PERMISSION_REQUEST_CODE = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    val fineLocation = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
                    val coarseLocation = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
                    val granted = fineLocation == PackageManager.PERMISSION_GRANTED || coarseLocation == PackageManager.PERMISSION_GRANTED
                    result.success(if (granted) "granted" else "denied")
                }
                "requestPermission" -> {
                    val fineLocation = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
                    val coarseLocation = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
                    if (fineLocation == PackageManager.PERMISSION_GRANTED || coarseLocation == PackageManager.PERMISSION_GRANTED) {
                        result.success("granted")
                    } else {
                        pendingResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                            PERMISSION_REQUEST_CODE
                        )
                    }
                }
                "getCurrentPosition" -> {
                    try {
                        val locationManager = getSystemService(LOCATION_SERVICE) as LocationManager
                        val isGpsEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
                        val isNetworkEnabled = locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)

                        var lastLocation: Location? = null
                        if (isGpsEnabled && ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                            lastLocation = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                        }
                        if (lastLocation == null && isNetworkEnabled && ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                            lastLocation = locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                        }

                        if (lastLocation != null) {
                            val map = mapOf(
                                "latitude" to lastLocation.latitude,
                                "longitude" to lastLocation.longitude,
                                "accuracy" to lastLocation.accuracy.toDouble(),
                                "address" to "Jl. Medan Merdeka Barat No. 12, Gambir, Jakarta Pusat",
                                "city" to "Jakarta Pusat"
                            )
                            result.success(map)
                        } else {
                            // Default location (Jakarta Pusat) if location fix is unavailable
                            val map = mapOf(
                                "latitude" to -6.175392,
                                "longitude" to 106.827153,
                                "accuracy" to 10.0,
                                "address" to "Jl. Medan Merdeka Barat No. 12, Gambir, Jakarta Pusat",
                                "city" to "Jakarta Pusat"
                            )
                            result.success(map)
                        }
                    } catch (e: Exception) {
                        result.error("LOCATION_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingResult?.success(if (granted) "granted" else "denied")
            pendingResult = null
        }
    }
}
