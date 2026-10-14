package com.protiti.protiti

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import androidx.core.content.ContextCompat
import java.util.UUID

/**
 * Sends one SMS per recipient through SmsManager and reports, per recipient,
 * whether the network accepted every part (sentIntent RESULT_OK). No SIM, no
 * credit, no signal or airplane mode come back as false. A recipient with no
 * answer within [timeoutMs] also counts as false.
 *
 * Context-only (no Activity), so a background Service can reuse it.
 * Must be called on the main thread; [onDone] runs there exactly once.
 */
object SmsSender {
    fun send(
        context: Context,
        recipients: List<String>,
        message: String,
        timeoutMs: Long = 30_000,
        onDone: (Map<String, Boolean>) -> Unit,
    ) {
        val app = context.applicationContext
        val targets = recipients.distinct()
        val results = HashMap<String, Boolean>()
        val receivers = mutableListOf<BroadcastReceiver>()
        var finished = false

        fun finish() {
            if (finished) return
            finished = true
            receivers.forEach { runCatching { app.unregisterReceiver(it) } }
            onDone(targets.associateWith { results[it] == true })
        }

        fun record(recipient: String, ok: Boolean) {
            results[recipient] = ok
            if (results.size == targets.size) finish()
        }

        if (targets.isEmpty() || message.isEmpty()) return finish()

        val smsManager: SmsManager =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                app.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
        val parts = smsManager.divideMessage(message)

        for (recipient in targets) {
            val action = "${app.packageName}.SMS_SENT.${UUID.randomUUID()}"
            var waiting = parts.size
            var ok = true
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(c: Context, intent: Intent) {
                    if (resultCode != Activity.RESULT_OK) ok = false
                    waiting -= 1
                    if (waiting == 0) record(recipient, ok)
                }
            }
            ContextCompat.registerReceiver(
                app, receiver, IntentFilter(action), ContextCompat.RECEIVER_NOT_EXPORTED
            )
            receivers.add(receiver)
            val sentIntents = ArrayList(parts.indices.map { part ->
                PendingIntent.getBroadcast(
                    app, part, Intent(action).setPackage(app.packageName),
                    PendingIntent.FLAG_IMMUTABLE
                )
            })
            try {
                smsManager.sendMultipartTextMessage(recipient, null, parts, sentIntents, null)
            } catch (e: Exception) {
                record(recipient, false)
            }
        }
        Handler(Looper.getMainLooper()).postDelayed({ finish() }, timeoutMs)
    }
}
