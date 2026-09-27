package com.protiti.protiti

import android.Manifest
import android.content.pm.PackageManager
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Exposes a small native SMS channel so the offline SOS fallback can hand a
 * message to the cellular radio via SmsManager directly, without opening the
 * Messages app's visible compose UI (which would show the outgoing alert to
 * anyone watching the survivor's screen).
 */
class MainActivity : FlutterFragmentActivity() {
    private val smsChannelName = "com.protiti.protiti/sms"
    private val smsPermissionRequestCode = 4001
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, smsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasSmsPermission" -> result.success(hasSmsPermission())
                    "requestSmsPermission" -> {
                        if (hasSmsPermission()) {
                            result.success(true)
                        } else {
                            pendingPermissionResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.SEND_SMS),
                                smsPermissionRequestCode
                            )
                        }
                    }
                    "sendSilentSms" -> {
                        if (!hasSmsPermission()) {
                            result.success(false)
                        } else {
                            @Suppress("UNCHECKED_CAST")
                            val recipients = call.argument<List<String>>("recipients") ?: emptyList()
                            val message = call.argument<String>("message") ?: ""
                            result.success(sendSilentSms(recipients, message))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasSmsPermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun sendSilentSms(recipients: List<String>, message: String): Boolean {
        if (recipients.isEmpty() || message.isEmpty()) return false
        return try {
            val smsManager = SmsManager.getDefault()
            for (recipient in recipients) {
                val parts = smsManager.divideMessage(message)
                smsManager.sendMultipartTextMessage(recipient, null, parts, null, null)
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == smsPermissionRequestCode) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }
}
