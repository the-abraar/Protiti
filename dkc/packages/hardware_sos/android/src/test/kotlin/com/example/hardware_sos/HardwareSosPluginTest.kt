package com.example.hardware_sos

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/*
 * Pure logic only (no Android framework). Run from dkc/android:
 *   ./gradlew --offline :hardware_sos:testDebugUnitTest
 */
internal class HardwareSosPluginTest {
    private val counter get() = PressCounter(HardwareSosPlugin.REQUIRED_PRESSES, HardwareSosPlugin.PRESS_WINDOW_MS)

    @Test
    fun fourQuickPressesTrigger_threeDoNot() {
        val c = counter
        assertFalse(c.press(0))
        assertFalse(c.press(400))
        assertFalse(c.press(800))
        assertTrue(c.press(1200))
        // Counting starts afresh: the next press is a first press again.
        assertFalse(c.press(1300))
    }

    @Test
    fun slowPressesNeverTrigger() {
        val c = counter
        // A screen wake every 1.1 s (notifications, checking the time).
        for (i in 0 until 20) assertFalse(c.press(i * 1_100L))
    }

    @Test
    fun resetForgetsPressesDuringACall() {
        val c = counter
        c.press(0); c.press(100); c.press(200)
        c.reset()
        assertFalse(c.press(300))
    }

    @Test
    fun partTallyNeedsEveryPart_failsAtFirstBadPart() {
        val ok = PartTally(2)
        assertNull(ok.add(true))
        assertEquals(true, ok.add(true))
        assertNull(ok.add(true)) // answered once only

        val bad = PartTally(3)
        assertEquals(false, bad.add(false))
        assertNull(bad.add(true))
    }

    @Test
    fun deliveryOutcomeClaimsDeliveryOnlyOnStatusZero() {
        assertEquals(true, deliveryOutcome("3gpp", 0x00))
        assertNull(deliveryOutcome("3gpp", 0x01)) // forwarded, not confirmed
        assertNull(deliveryOutcome("3gpp", 0x20)) // centre still trying
        assertEquals(false, deliveryOutcome("3gpp", 0x40))
        assertEquals(false, deliveryOutcome("3gpp", 0x62))
        assertNull(deliveryOutcome("3gpp2", 0x00)) // CDMA: not read
        assertNull(deliveryOutcome("3gpp", null))
        assertNull(deliveryOutcome("3gpp", -1))
    }

    @Test
    fun batteryScreensForTheFourMakers() {
        for (maker in listOf("Xiaomi", "Redmi", "POCO", "OPPO", "realme", "vivo", "iQOO")) {
            assertTrue(maker, oemBatteryScreens(maker).isNotEmpty())
        }
        assertTrue(oemBatteryScreens("samsung").isEmpty())
        assertEquals("com.miui.securitycenter", oemBatteryScreens(" Xiaomi ").first().first)
    }
}
