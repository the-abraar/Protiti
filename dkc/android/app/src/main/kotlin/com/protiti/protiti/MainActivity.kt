package com.protiti.protiti

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * SOS (pro-sos): the SMS itself is sent by the hardware_sos plugin, which runs
 * on every engine, the background service's included. Permission prompts
 * need this activity, so they stay here.
 */
class MainActivity : FlutterFragmentActivity() {
    private val smsChannelName = "com.protiti.protiti/sms"
    private val permissionRequestCode = 4001
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
                    "requestSmsPermission" -> request(Manifest.permission.SEND_SMS, result)
                    // The SOS countdown's Cancel button lives in a notification.
                    "requestNotificationPermission" ->
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            request(Manifest.permission.POST_NOTIFICATIONS, result)
                        } else {
                            result.success(NotificationManagerCompat.from(this).areNotificationsEnabled())
                        }
                    else -> result.notImplemented()
                }
            }
    }

    private fun request(permission: String, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
        } else {
            pendingPermissionResult = result
            ActivityCompat.requestPermissions(this, arrayOf(permission), permissionRequestCode)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permissionRequestCode) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }
}
