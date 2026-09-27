package com.example.hardware_sos

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel

class HardwareSosPlugin : FlutterPlugin, EventChannel.StreamHandler {
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var applicationContext: Context? = null
    private var screenReceiver: BroadcastReceiver? = null

    private val pressTimestamps = mutableListOf<Long>()
    private val REQUIRED_PRESSES = 3
    private val TIME_WINDOW_MS = 2000L

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "hardware_sos_events")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        eventChannel.setStreamHandler(null)
        applicationContext = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        registerReceiver()
    }

    override fun onCancel(arguments: Any?) {
        unregisterReceiver()
        eventSink = null
    }

    private fun registerReceiver() {
        if (screenReceiver == null && applicationContext != null) {
            screenReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == Intent.ACTION_SCREEN_ON || intent?.action == Intent.ACTION_SCREEN_OFF) {
                        handlePress()
                    }
                }
            }
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
            }
            applicationContext?.registerReceiver(screenReceiver, filter)
        }
    }

    private fun unregisterReceiver() {
        if (screenReceiver != null && applicationContext != null) {
            try {
                applicationContext?.unregisterReceiver(screenReceiver)
            } catch (e: Exception) {
                // Ignore if not registered
            }
            screenReceiver = null
        }
    }

    private fun handlePress() {
        val currentTime = System.currentTimeMillis()
        pressTimestamps.add(currentTime)

        // Remove old timestamps outside the window
        pressTimestamps.removeAll { currentTime - it > TIME_WINDOW_MS }

        if (pressTimestamps.size >= REQUIRED_PRESSES) {
            pressTimestamps.clear()
            eventSink?.success("sos_triggered")
        }
    }
}
