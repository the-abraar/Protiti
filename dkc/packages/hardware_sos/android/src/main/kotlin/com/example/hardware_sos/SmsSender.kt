package com.example.hardware_sos

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
import android.telephony.SmsMessage
import java.util.UUID

/**
 * Sends one SMS per recipient through SmsManager and reports, per recipient,
 * whether the network accepted every part (sentIntent RESULT_OK). No SIM, no
 * credit, no signal or airplane mode come back as false. A recipient with no
 * answer within [timeoutMs] also counts as false.
 *
 * Later, [onDelivered] fires once per recipient whose delivery reports
 * (deliveryIntent) all came back, or as soon as one part failed for good.
 * Many reports never come; then it never fires and nothing is claimed.
 *
 * Context-only (no Activity), so it works from the background service's
 * engine as well as the app's. Must be called on the main thread; [onDone]
 * runs there exactly once.
 */
object SmsSender {
    /** Delivery reports can take minutes; after this their receivers go. */
    private const val DELIVERY_WAIT_MS = 10 * 60_000L

    fun send(
        context: Context,
        recipients: List<String>,
        message: String,
        timeoutMs: Long = 30_000,
        onDelivered: (String, Boolean) -> Unit = { _, _ -> },
        onDone: (Map<String, Boolean>) -> Unit,
    ) {
        val app = context.applicationContext
        val targets = recipients.distinct()
        val results = HashMap<String, Boolean>()
        val sentReceivers = mutableListOf<BroadcastReceiver>()
        val deliveryReceivers = mutableListOf<BroadcastReceiver>()
        val main = Handler(Looper.getMainLooper())
        var finished = false

        fun finish() {
            if (finished) return
            finished = true
            sentReceivers.forEach { runCatching { app.unregisterReceiver(it) } }
            onDone(targets.associateWith { results[it] == true })
        }

        fun record(recipient: String, ok: Boolean) {
            if (results.containsKey(recipient)) return
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
            val sentAction = "${app.packageName}.SMS_SENT.${UUID.randomUUID()}"
            val deliveredAction = "${app.packageName}.SMS_DELIVERED.${UUID.randomUUID()}"
            val sent = PartTally(parts.size)
            val delivered = PartTally(parts.size)
            val sentReceiver = object : BroadcastReceiver() {
                override fun onReceive(c: Context, intent: Intent) {
                    sent.add(resultCode == Activity.RESULT_OK)?.let { record(recipient, it) }
                }
            }
            val deliveryReceiver = object : BroadcastReceiver() {
                override fun onReceive(c: Context, intent: Intent) {
                    val format = intent.getStringExtra("format")
                    val status = intent.getByteArrayExtra("pdu")?.let { pdu ->
                        runCatching { SmsMessage.createFromPdu(pdu, format).status }.getOrNull()
                    }
                    val outcome = deliveryOutcome(format, status) ?: return
                    delivered.add(outcome)?.let {
                        runCatching { app.unregisterReceiver(this) }
                        onDelivered(recipient, it)
                    }
                }
            }
            registerPrivate(app, sentReceiver, sentAction)
            registerPrivate(app, deliveryReceiver, deliveredAction)
            sentReceivers.add(sentReceiver)
            deliveryReceivers.add(deliveryReceiver)
            val sentIntents = ArrayList(parts.indices.map { part ->
                PendingIntent.getBroadcast(
                    app, part, Intent(sentAction).setPackage(app.packageName),
                    PendingIntent.FLAG_IMMUTABLE
                )
            })
            // Mutable: the radio adds the report ("pdu", "format") as extras,
            // which an immutable PendingIntent would drop.
            val deliveryIntents = ArrayList(parts.indices.map { part ->
                PendingIntent.getBroadcast(
                    app, part, Intent(deliveredAction).setPackage(app.packageName),
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
                )
            })
            try {
                smsManager.sendMultipartTextMessage(recipient, null, parts, sentIntents, deliveryIntents)
            } catch (e: Exception) {
                record(recipient, false)
            }
        }
        main.postDelayed({ finish() }, timeoutMs)
        main.postDelayed({
            deliveryReceivers.forEach { runCatching { app.unregisterReceiver(it) } }
        }, DELIVERY_WAIT_MS)
    }

    private fun registerPrivate(app: Context, receiver: BroadcastReceiver, action: String) {
        val filter = IntentFilter(action)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            app.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            // Before Android 13 there is no flag; the random action keeps it private.
            app.registerReceiver(receiver, filter)
        }
    }
}

/**
 * One recipient's message parts. [add] returns the recipient's result once
 * every part answered, or false at the first failed part; null until then
 * and after.
 */
internal class PartTally(private var waiting: Int) {
    fun add(partOk: Boolean): Boolean? {
        if (waiting <= 0) return null
        if (!partOk) {
            waiting = 0
            return false
        }
        waiting -= 1
        return if (waiting == 0) true else null
    }
}

/**
 * Reads a GSM (3GPP) delivery report's TP-Status: true delivered, false
 * failed for good, null for anything else (the centre is still trying,
 * "forwarded but unconfirmed", or an unreadable or CDMA report), which is
 * never reported as delivered.
 */
internal fun deliveryOutcome(format: String?, status: Int?): Boolean? = when {
    format != "3gpp" || status == null || status < 0 -> null
    status == 0x00 -> true // received by the phone
    status >= 0x40 -> false // permanent error, or temporary with no more tries
    else -> null
}
