package app.rarecreatures.nextcup

import android.content.SharedPreferences
import app.rarecreatures.nextcup.kit.TemperatureUnit
import app.rarecreatures.nextcup.kit.UnitPreferences
import app.rarecreatures.nextcup.kit.WeightUnit
import app.rarecreatures.nextcup.ui.theme.AppStyle
import app.rarecreatures.nextcup.ui.theme.AppearanceMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** Client preferences (iOS UserDefaults). Keys match iOS where the setting exists there. */
class Prefs(val raw: SharedPreferences) {
    private fun <T> flow(read: () -> T): MutableStateFlow<T> = MutableStateFlow(read())

    private val _style = flow { AppStyle.of(raw.getString(STYLE_KEY, null)) }
    val style: StateFlow<AppStyle> = _style
    fun setStyle(style: AppStyle) { raw.edit().putString(STYLE_KEY, style.raw).apply(); _style.value = style }

    private val _appearance = flow { AppearanceMode.of(raw.getString(APPEARANCE_KEY, null)) }
    val appearance: StateFlow<AppearanceMode> = _appearance
    fun setAppearance(mode: AppearanceMode) { raw.edit().putString(APPEARANCE_KEY, mode.raw).apply(); _appearance.value = mode }

    private fun readUnits() = UnitPreferences(
        WeightUnit.entries.firstOrNull { it.raw == raw.getString(WEIGHT_KEY, null) } ?: WeightUnit.GRAMS,
        TemperatureUnit.entries.firstOrNull { it.raw == raw.getString(TEMPERATURE_KEY, null) } ?: TemperatureUnit.CELSIUS,
    )
    private val _units = flow { readUnits() }
    val units: StateFlow<UnitPreferences> = _units
    fun setUnits(units: UnitPreferences) {
        raw.edit().putString(WEIGHT_KEY, units.weight.raw).putString(TEMPERATURE_KEY, units.temperature.raw).apply()
        _units.value = units
    }

    /** The method and grinder used last, so a new brew starts from them. */
    var lastMethodId: String?
        get() = raw.getString("brew.lastMethodID", null)
        set(value) = raw.edit().putString("brew.lastMethodID", value).apply()
    var lastGrinderId: String?
        get() = raw.getString("brew.lastGrinderID", null)
        set(value) = raw.edit().putString("brew.lastGrinderID", value).apply()

    /** Haptics and the step chime while a brew runs. */
    var timerSound: Boolean
        get() = raw.getBoolean("nextcup.timer.sound", true)
        set(value) = raw.edit().putBoolean("nextcup.timer.sound", value).apply()

    /** The selected tab's raw value (iOS `AppTab`), restored after relaunch. */
    var selectedTab: String
        get() = raw.getString(TAB_KEY, null) ?: "journal"
        set(value) = raw.edit().putString(TAB_KEY, value).apply()

    companion object {
        const val STYLE_KEY = "appStyle"
        const val APPEARANCE_KEY = "appearanceMode"
        const val TAB_KEY = "selectedTab"
        const val WEIGHT_KEY = "units.weight"
        const val TEMPERATURE_KEY = "units.temperature"
    }
}
