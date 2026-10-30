package app.rarecreatures.nextcup.ui.theme

import androidx.compose.ui.graphics.Color

/** A light/dark hex pair, as iOS's `P` in Tokens.swift. */
data class P(val light: Long, val dark: Long) {
    fun pick(dark: Boolean) = Color(0xFF000000 or if (dark) this.dark else light)
}

/** Every colour role the design system uses, for one look. Names are roles, not colours. */
data class Palette(
    val bg: P, val paper: P, val steel: P, val onSteel: P, val ink: P, val ink2: P, val line: P,
    val signal: P, val onSignal: P, val signalOnSteel: P, val kraft: P, val onKraft: P, val error: P, val ok: P,
    /** Labels, icons, digits and progress, where it differs from the button colour. */
    val accent: P? = null,
)

/** One look's colours resolved for light or dark. */
data class Colors(
    val bg: Color, val paper: Color, val steel: Color, val onSteel: Color, val ink: Color, val ink2: Color, val line: Color,
    val signal: Color, val onSignal: Color, val signalOnSteel: Color, val kraft: Color, val onKraft: Color,
    val error: Color, val ok: Color, val accent: Color, val isDark: Boolean,
) {
    companion object {
        fun of(p: Palette, dark: Boolean) = Colors(
            p.bg.pick(dark), p.paper.pick(dark), p.steel.pick(dark), p.onSteel.pick(dark), p.ink.pick(dark), p.ink2.pick(dark),
            p.line.pick(dark), p.signal.pick(dark), p.onSignal.pick(dark), p.signalOnSteel.pick(dark), p.kraft.pick(dark),
            p.onKraft.pick(dark), p.error.pick(dark), p.ok.pick(dark), (p.accent ?: p.signal).pick(dark), dark,
        )
    }
}

enum class DisplayFace { ROUNDED, SERIF, SANS }

/**
 * The looks Settings offers, in iOS's order (AppStyle.offered). Raw values match iOS's stored `appStyle`.
 * Sunday Studio is the default. On Android its light side drops iOS's butter and brown for navy, white and
 * cobalt; the dark side is navy with white buttons and orange accents, as on iOS.
 */
enum class AppStyle(val raw: String, val title: String, val mood: String, val face: DisplayFace, val radius: Int, val palette: Palette) {
    SUNDAY_STUDIO(
        "sundayStudio", "Sunday Studio", "Navy and white, orange accents, bold rounded type", DisplayFace.ROUNDED, 22,
        Palette(
            bg = P(0xFFFFFF, 0x0E1230), paper = P(0xF3F5FC, 0x171D45), steel = P(0x1B2F7A, 0x2448C8),
            onSteel = P(0xFFFFFF, 0xFFFDF3), ink = P(0x0E1230, 0xFFFDF3), ink2 = P(0x4A5175, 0xC9CCE6),
            line = P(0x7B82A8, 0x7B82B8), signal = P(0x2448C8, 0xFFFDF3), onSignal = P(0xFFFFFF, 0x0E1230),
            signalOnSteel = P(0xFFB27A, 0xFF9F5A), kraft = P(0xE8ECFB, 0x14204F), onKraft = P(0x0E1230, 0xFFFDF3),
            error = P(0x9A1B0A, 0xFFA08C), ok = P(0x2A6A2A, 0x9FE0A8), accent = P(0x2448C8, 0xFF9F5A),
        ),
    ),
    MORNING_EDITION(
        "morningEdition", "Brass", "Ink and brass, editorial serif", DisplayFace.SERIF, 8,
        Palette(
            bg = P(0xF7F7F4, 0x10151B), paper = P(0xFFFFFF, 0x18202A), steel = P(0x1A2129, 0x1F2935),
            onSteel = P(0xF7F7F4, 0xF2F0EA), ink = P(0x1A2129, 0xF2F0EA), ink2 = P(0x55606B, 0xB4BCC6),
            line = P(0x85909B, 0x6E7A87), signal = P(0x1A2129, 0xF2F0EA), onSignal = P(0xF7F7F4, 0x10151B),
            signalOnSteel = P(0xC9D3DE, 0xC9D3DE), kraft = P(0xE9ECEF, 0x1F2935), onKraft = P(0x1A2129, 0xF2F0EA),
            error = P(0x9A1B0A, 0xFF9C85), ok = P(0x2A6A2A, 0x9FE0A8), accent = P(0x7A5C14, 0xD9B36A),
        ),
    ),
    STEEL_BLUE(
        "steelBlue", "Steel Blue", "Ink and steel blue, editorial serif", DisplayFace.SERIF, 8,
        Palette(
            bg = P(0xF7F7F4, 0x10151B), paper = P(0xFFFFFF, 0x18202A), steel = P(0x1A2129, 0x1F2935),
            onSteel = P(0xF7F7F4, 0xF2F0EA), ink = P(0x1A2129, 0xF2F0EA), ink2 = P(0x55606B, 0xB4BCC6),
            line = P(0x85909B, 0x6E7A87), signal = P(0x1A2129, 0xF2F0EA), onSignal = P(0xF7F7F4, 0x10151B),
            signalOnSteel = P(0xC9D3DE, 0xC9D3DE), kraft = P(0xE9ECEF, 0x1F2935), onKraft = P(0x1A2129, 0xF2F0EA),
            error = P(0x9A1B0A, 0xFF9C85), ok = P(0x2A6A2A, 0x9FE0A8), accent = P(0x2F5E9E, 0x8FB3E8),
        ),
    ),
    DAILY(
        "daily", "Daily", "Clean white cards, serif, one amber", DisplayFace.SERIF, 24,
        Palette(
            bg = P(0xF7F5F1, 0x0F0F10), paper = P(0xFFFFFF, 0x1C1C1E), steel = P(0x1C1A17, 0x2A2A2D),
            onSteel = P(0xFFFFFF, 0xF2EFEA), ink = P(0x1C1A17, 0xF2EFEA), ink2 = P(0x6B645C, 0xA8A39C),
            line = P(0x8C847A, 0x6E6A64), signal = P(0x93591A, 0xE3A75C), onSignal = P(0xFFFFFF, 0x1A1208),
            signalOnSteel = P(0xE3A75C, 0xE3A75C), kraft = P(0xF3E9DC, 0x2A2117), onKraft = P(0x1C1A17, 0xF2EFEA),
            error = P(0x9A1B0A, 0xFF9C85), ok = P(0x55684A, 0xA9BC97),
        ),
    ),
    CAFE_PAGE(
        "cafePage", "Café Page", "Serif headings on paper", DisplayFace.SERIF, 12,
        Palette(
            bg = P(0xFBF8F3, 0x1A1816), paper = P(0xF3EEE6, 0x24211E), steel = P(0x2E2A33, 0x2F2B33),
            onSteel = P(0xF3EEE6, 0xEDE7DD), ink = P(0x22201C, 0xEDE7DD), ink2 = P(0x625C52, 0xABA396),
            line = P(0x625C52, 0xABA396), signal = P(0x7A4A8C, 0xD6B3E3), onSignal = P(0xFFFFFF, 0x1A1816),
            signalOnSteel = P(0xD6B3E3, 0xD6B3E3), kraft = P(0xE6DAEC, 0x3A3140), onKraft = P(0x22201C, 0xEDE7DD),
            error = P(0x9A1B0A, 0xFF9C85), ok = P(0x2A6A2A, 0x7FD18A),
        ),
    ),
    ROASTER_POSTER(
        "roasterPoster", "Roaster Poster", "Loud stickers with offset shadow", DisplayFace.SANS, 6,
        Palette(
            bg = P(0xFFFFFF, 0x121413), paper = P(0xF1F7F2, 0x1C201D), steel = P(0x0B0B0B, 0x1C201D),
            onSteel = P(0xF2F5F2, 0xF2F5F2), ink = P(0x0B0B0B, 0xF2F5F2), ink2 = P(0x4A4F4B, 0xA7AFA9),
            line = P(0x0B0B0B, 0xF2F5F2), signal = P(0x1E7A3E, 0x8FF0A4), onSignal = P(0xFFFFFF, 0x0B0B0B),
            signalOnSteel = P(0x8FF0A4, 0x8FF0A4), kraft = P(0xD9F2DF, 0x233326), onKraft = P(0x0B0B0B, 0xF2F5F2),
            error = P(0x9A1B0A, 0xFF9C85), ok = P(0x2A6A2A, 0x7FD18A),
        ),
    );

    companion object {
        val DEFAULT = SUNDAY_STUDIO
        /** A look iOS has that Android does not offer falls back to the default. */
        fun of(raw: String?) = entries.firstOrNull { it.raw == raw } ?: DEFAULT
    }
}

/** The owner's choice of Light, Dark or the system setting. Raw values match iOS. */
enum class AppearanceMode(val raw: String, val title: String) {
    SYSTEM("system", "System"), LIGHT("light", "Light"), DARK("dark", "Dark");

    companion object {
        fun of(raw: String?) = entries.firstOrNull { it.raw == raw } ?: SYSTEM
    }
}
