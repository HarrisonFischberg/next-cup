package app.rarecreatures.nextcup

import android.content.SharedPreferences
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

    /** The selected tab's raw value (iOS `AppTab`), restored after relaunch. */
    var selectedTab: String
        get() = raw.getString(TAB_KEY, null) ?: "journal"
        set(value) = raw.edit().putString(TAB_KEY, value).apply()

    companion object {
        const val STYLE_KEY = "appStyle"
        const val APPEARANCE_KEY = "appearanceMode"
        const val TAB_KEY = "selectedTab"
    }
}
