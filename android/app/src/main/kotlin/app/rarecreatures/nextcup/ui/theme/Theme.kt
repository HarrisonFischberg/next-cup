package app.rarecreatures.nextcup.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

val LocalColors = staticCompositionLocalOf { Colors.of(AppStyle.DEFAULT.palette, true) }
val LocalStyle = staticCompositionLocalOf { AppStyle.DEFAULT }

/** Design tokens, read inside composables: `DS.colors.accent`. */
object DS {
    val colors: Colors @Composable get() = LocalColors.current
    val style: AppStyle @Composable get() = LocalStyle.current
    val radius @Composable get() = LocalStyle.current.radius.dp

    object Space {
        val xs = 4.dp
        val sm = 8.dp
        val md = 12.dp
        val lg = 16.dp
        val xl = 24.dp
        val xxl = 32.dp
    }

    /** Minimum touch target and the control heights used on the brew station. */
    object Size {
        val minTap = 48.dp
        val control = 48.dp
        val primary = 60.dp
        val timerControl = 64.dp
    }
}

private fun displayFamily(face: DisplayFace) = when (face) {
    DisplayFace.SERIF -> FontFamily.Serif
    DisplayFace.ROUNDED, DisplayFace.SANS -> FontFamily.SansSerif
}

private fun displayWeight(face: DisplayFace) = when (face) {
    DisplayFace.ROUNDED -> FontWeight.Black
    DisplayFace.SERIF -> FontWeight.Medium
    DisplayFace.SANS -> FontWeight.Bold
}

@Composable
fun NextCupTheme(style: AppStyle, appearance: AppearanceMode, content: @Composable () -> Unit) {
    val dark = when (appearance) {
        AppearanceMode.SYSTEM -> isSystemInDarkTheme()
        AppearanceMode.LIGHT -> false
        AppearanceMode.DARK -> true
    }
    val c = Colors.of(style.palette, dark)
    val scheme = (if (dark) darkColorScheme() else lightColorScheme()).copy(
        primary = c.signal, onPrimary = c.onSignal, primaryContainer = c.kraft, onPrimaryContainer = c.onKraft,
        secondary = c.accent, onSecondary = c.bg, secondaryContainer = c.kraft, onSecondaryContainer = c.onKraft,
        tertiary = c.accent, background = c.bg, onBackground = c.ink, surface = c.bg, onSurface = c.ink,
        surfaceVariant = c.paper, onSurfaceVariant = c.ink2, surfaceContainer = c.paper, surfaceContainerLow = c.paper,
        surfaceContainerHigh = c.paper, surfaceContainerHighest = c.paper, surfaceContainerLowest = c.bg,
        outline = c.line, outlineVariant = c.line.copy(alpha = 0.4f), error = c.error,
    )
    val family = displayFamily(style.face)
    val weight = displayWeight(style.face)
    val base = Typography()
    val type = base.copy(
        displaySmall = TextStyle(fontFamily = family, fontWeight = weight, fontSize = 44.sp, lineHeight = 48.sp),
        headlineMedium = TextStyle(fontFamily = family, fontWeight = weight, fontSize = 30.sp, lineHeight = 36.sp),
        headlineSmall = TextStyle(fontFamily = family, fontWeight = weight, fontSize = 24.sp, lineHeight = 30.sp),
        titleLarge = TextStyle(fontFamily = family, fontWeight = weight, fontSize = 21.sp, lineHeight = 26.sp),
        titleMedium = base.titleMedium.copy(fontWeight = FontWeight.SemiBold),
        labelSmall = base.labelSmall.copy(fontWeight = FontWeight.SemiBold, letterSpacing = 1.2.sp),
    )
    val r = style.radius.dp
    val shapes = Shapes(
        extraSmall = RoundedCornerShape(r / 3), small = RoundedCornerShape(r / 2), medium = RoundedCornerShape(r),
        large = RoundedCornerShape(r), extraLarge = RoundedCornerShape(r),
    )
    CompositionLocalProvider(LocalColors provides c, LocalStyle provides style) {
        MaterialTheme(colorScheme = scheme, typography = type, shapes = shapes, content = content)
    }
}
