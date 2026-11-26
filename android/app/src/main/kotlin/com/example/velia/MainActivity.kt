package com.example.velia

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "velia/direct_call"
    private val callPermissionRequest = 7314
    private var pendingPhone: String? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "call") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val phone = call.argument<String>("phone")?.trim()
                if (phone.isNullOrEmpty()) {
                    result.error("invalid_phone", "No hay un teléfono de emergencia configurado.", null)
                    return@setMethodCallHandler
                }
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) ==
                    PackageManager.PERMISSION_GRANTED
                ) {
                    makeCall(phone, result)
                } else {
                    pendingPhone = phone
                    pendingResult = result
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.CALL_PHONE),
                        callPermissionRequest
                    )
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != callPermissionRequest) return
        val phone = pendingPhone
        val result = pendingResult
        pendingPhone = null
        pendingResult = null
        if (phone != null && result != null && grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            makeCall(phone, result)
        } else {
            result?.error("permission_denied", "Se requiere permiso para llamar al contacto principal.", null)
        }
    }

    private fun makeCall(phone: String, result: MethodChannel.Result) {
        try {
            startActivity(Intent(Intent.ACTION_CALL, Uri.parse("tel:$phone")))
            result.success(true)
        } catch (error: Exception) {
            result.error("call_failed", error.message, null)
        }
    }
}
