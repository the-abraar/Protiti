package com.example.hardware_sos

/**
 * Battery and auto-start screens to try on the phone makers that most often
 * stop background apps in Bangladesh, best first. They are other apps'
 * internals and may be missing on a given ROM version, so the caller falls
 * back to this app's own settings page.
 */
internal fun oemBatteryScreens(manufacturer: String): List<Pair<String, String>> =
    when (manufacturer.trim().lowercase()) {
        "xiaomi", "redmi", "poco" -> listOf(
            "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
            "com.miui.powerkeeper" to "com.miui.powerkeeper.ui.HiddenAppsConfigActivity",
        )
        "oppo", "realme" -> listOf(
            "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
        )
        "vivo", "iqoo" -> listOf(
            "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
        )
        else -> emptyList()
    }
