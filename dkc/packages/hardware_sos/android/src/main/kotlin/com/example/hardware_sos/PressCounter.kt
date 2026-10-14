package com.example.hardware_sos

/**
 * Counts power-button presses (seen as screen on/off events). [press] is true
 * when [required] presses fall within [windowMs]; counting then starts afresh.
 * Times come from a monotonic clock.
 */
class PressCounter(private val required: Int, private val windowMs: Long) {
    private val times = ArrayDeque<Long>()

    fun press(nowMs: Long): Boolean {
        times.addLast(nowMs)
        while (nowMs - times.first() > windowMs) times.removeFirst()
        if (times.size < required) return false
        times.clear()
        return true
    }

    fun reset() = times.clear()
}
