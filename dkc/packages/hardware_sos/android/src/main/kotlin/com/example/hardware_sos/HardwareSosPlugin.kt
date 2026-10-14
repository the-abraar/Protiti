package com.example.hardware_sos

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/**
 * Registered by Flutter on every engine, the background service's included,
 * so the SOS works with the app closed (B8).
 *
 * - EventChannel `hardware_sos_events`: "sos_triggered" after [REQUIRED_PRESSES]
 *   power presses, "sos_cancelled" when she taps Cancel on the countdown notice.
 * - MethodChannel `hardware_sos`: SMS with per-recipient sent and delivered
 *   results, vibration, the status notice, and battery-settings links.
 */
class HardwareSosPlugin : FlutterPlugin, EventChannel.StreamHandler, MethodChannel.MethodCallHandler {
    private lateinit var eventChannel: EventChannel
    private lateinit var methodChannel: MethodChannel
    private var eventSink: EventChannel.EventSink? = null
    private var applicationContext: Context? = null
    private var screenReceiver: BroadcastReceiver? = null
    private var cancelReceiver: BroadcastReceiver? = null
    // Random per process, so no other app can cancel her alert.
    private val cancelAction = "hardware_sos.CANCEL.${UUID.randomUUID()}"

    private val presses = PressCounter(REQUIRED_PRESSES, PRESS_WINDOW_MS)

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "hardware_sos_events")
        eventChannel.setStreamHandler(this)
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "hardware_sos")
        methodChannel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        unregisterReceivers()
        eventChannel.setStreamHandler(null)
        methodChannel.setMethodCallHandler(null)
        applicationContext = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        registerReceivers()
    }

    override fun onCancel(arguments: Any?) {
        unregisterReceivers()
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = applicationContext ?: return result.error("detached", null, null)
        when (call.method) {
            "hasSmsPermission" -> result.success(canSendSms(ctx))
            "hasNotificationPermission" ->
                result.success(ctx.getSystemService(NotificationManager::class.java).areNotificationsEnabled())
            "sendSms" -> {
                val recipients = call.argument<List<String>>("recipients") ?: emptyList()
                val message = call.argument<String>("message") ?: ""
                if (!canSendSms(ctx)) {
                    result.success(recipients.associateWith { false })
                } else {
                    SmsSender.send(
                        ctx, recipients, message,
                        onDelivered = { recipient, ok ->
                            runCatching {
                                methodChannel.invokeMethod(
                                    "delivered", mapOf("recipient" to recipient, "delivered" to ok)
                                )
                            }
                        },
                        onDone = { result.success(it) },
                    )
                }
            }
            "vibrate" -> {
                vibrate(ctx, (call.argument<List<Number>>("pattern") ?: emptyList()).map { it.toLong() })
                result.success(null)
            }
            "notify" -> {
                notice(
                    ctx,
                    call.argument<String>("text") ?: "",
                    cancel = call.argument<Boolean>("cancel") == true,
                    call999 = call.argument<Boolean>("call999") == true,
                )
                result.success(null)
            }
            "clearNotice" -> {
                ctx.getSystemService(NotificationManager::class.java).cancel(NOTICE_ID)
                result.success(null)
            }
            "appLabel" -> result.success(appLabel(ctx))
            "deviceMaker" -> result.success(Build.MANUFACTURER)
            "openBatterySettings" -> result.success(openBatterySettings(ctx))
            else -> result.notImplemented()
        }
    }

    private fun registerReceivers() {
        val ctx = applicationContext ?: return
        if (screenReceiver == null) {
            screenReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == Intent.ACTION_SCREEN_ON || intent?.action == Intent.ACTION_SCREEN_OFF) {
                        handlePress(ctx)
                    }
                }
            }
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
            }
            registerPrivate(ctx, screenReceiver!!, filter)
        }
        if (cancelReceiver == null) {
            cancelReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    eventSink?.success("sos_cancelled")
                }
            }
            registerPrivate(ctx, cancelReceiver!!, IntentFilter(cancelAction))
        }
    }

    private fun unregisterReceivers() {
        val ctx = applicationContext ?: return
        listOfNotNull(screenReceiver, cancelReceiver).forEach { runCatching { ctx.unregisterReceiver(it) } }
        screenReceiver = null
        cancelReceiver = null
    }

    private fun handlePress(ctx: Context) {
        // In a call the proximity sensor turns the screen off and on as the
        // phone moves to and from her ear: those are not presses.
        val mode = ctx.getSystemService(AudioManager::class.java)?.mode
        if (mode == AudioManager.MODE_IN_CALL || mode == AudioManager.MODE_IN_COMMUNICATION ||
            mode == AudioManager.MODE_RINGTONE
        ) {
            presses.reset()
            return
        }
        if (presses.press(SystemClock.elapsedRealtime())) eventSink?.success("sos_triggered")
    }

    private fun canSendSms(ctx: Context) =
        ctx.checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED

    /** Alarm usage, so it still buzzes when notification vibration is off. */
    private fun vibrate(ctx: Context, pattern: List<Long>) {
        if (pattern.isEmpty()) return
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ctx.getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            ctx.getSystemService(Vibrator::class.java)
        }
        val alarm = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build()
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                @Suppress("DEPRECATION")
                vibrator.vibrate(VibrationEffect.createWaveform(pattern.toLongArray(), -1), alarm)
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern.toLongArray(), -1, alarm)
            }
        }
    }

    /**
     * The one status notice: titled with this app's own label (whatever the
     * disguise sets it to), never another app's or the system's name. Quiet
     * (N4): no sound, no heads-up pop-up, and nothing of it on a secure lock
     * screen, so someone holding the phone does not see a countdown or a
     * result. The buzz from [vibrate] is how she knows; Cancel and Call are
     * in the notification shade once the phone is unlocked.
     */
    private fun notice(ctx: Context, text: String, cancel: Boolean, call999: Boolean) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // A channel's importance cannot change once created, so the old loud one goes.
            nm.deleteNotificationChannel(OLD_NOTICE_CHANNEL)
            val channel = NotificationChannel(NOTICE_CHANNEL, "Status", NotificationManager.IMPORTANCE_LOW).apply {
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_SECRET
            }
            nm.createNotificationChannel(channel)
            Notification.Builder(ctx, NOTICE_CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(ctx).setPriority(Notification.PRIORITY_LOW)
        }
        builder.setSmallIcon(ctx.applicationInfo.icon)
            .setContentTitle(appLabel(ctx))
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setVisibility(Notification.VISIBILITY_SECRET)
            .setOnlyAlertOnce(false)
        if (cancel) {
            val pi = PendingIntent.getBroadcast(
                ctx, 0, Intent(cancelAction).setPackage(ctx.packageName),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            @Suppress("DEPRECATION")
            builder.addAction(Notification.Action.Builder(0, "Cancel", pi).build())
        }
        if (call999) {
            // ACTION_DIAL opens the dialer with 999 typed in; she presses call.
            // The button just says "Call", so the shade does not name 999.
            val pi = PendingIntent.getActivity(
                ctx, 1, Intent(Intent.ACTION_DIAL, Uri.parse("tel:999")),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            @Suppress("DEPRECATION")
            builder.addAction(Notification.Action.Builder(0, "Call", pi).build())
        }
        runCatching { nm.notify(NOTICE_ID, builder.build()) }
    }

    private fun appLabel(ctx: Context) = ctx.applicationInfo.loadLabel(ctx.packageManager).toString()

    /** True if a maker's own screen opened; else this app's settings page. */
    private fun openBatterySettings(ctx: Context): Boolean {
        for ((pkg, cls) in oemBatteryScreens(Build.MANUFACTURER)) {
            val intent = Intent().setClassName(pkg, cls)
                .putExtra("package_name", ctx.packageName)
                .putExtra("package_label", appLabel(ctx))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (runCatching { ctx.startActivity(intent) }.isSuccess) return true
        }
        runCatching {
            ctx.startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${ctx.packageName}"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
        return false
    }

    private fun registerPrivate(ctx: Context, receiver: BroadcastReceiver, filter: IntentFilter) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ctx.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            ctx.registerReceiver(receiver, filter)
        }
    }

    companion object {
        /**
         * Four presses within 3 s. Three in 2 s fired in normal use: a press
         * in a bag or pocket, a notification waking the screen, a quick
         * on-off-on to check the time. Field-test on real phones (owner TODO).
         */
        const val REQUIRED_PRESSES = 4
        const val PRESS_WINDOW_MS = 3_000L
        private const val OLD_NOTICE_CHANNEL = "status"
        private const val NOTICE_CHANNEL = "status_quiet"
        private const val NOTICE_ID = 889
    }
}
