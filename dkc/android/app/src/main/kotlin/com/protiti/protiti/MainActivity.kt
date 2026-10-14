package com.protiti.protiti

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.WindowManager
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

    override fun onCreate(savedInstanceState: Bundle?) {
        // Whole app, every route, before the first frame: no screenshots, no
        // screen recording, no readable Recents thumbnail.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        super.onCreate(savedInstanceState)
    }

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
                        val recipients = call.argument<List<String>>("recipients") ?: emptyList()
                        val message = call.argument<String>("message") ?: ""
                        if (!hasSmsPermission()) {
                            result.success(recipients.associateWith { false })
                        } else {
                            SmsSender.send(this, recipients, message) { result.success(it) }
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
