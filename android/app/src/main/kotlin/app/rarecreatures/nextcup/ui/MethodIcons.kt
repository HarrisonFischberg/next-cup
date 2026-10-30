package app.rarecreatures.nextcup.ui

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AcUnit
import androidx.compose.material.icons.outlined.Coffee
import androidx.compose.material.icons.outlined.CoffeeMaker
import androidx.compose.material.icons.outlined.Compress
import androidx.compose.material.icons.outlined.FilterAlt
import androidx.compose.material.icons.outlined.LocalCafe
import androidx.compose.material.icons.outlined.Speed
import androidx.compose.material.icons.outlined.SwapVert
import androidx.compose.material.icons.outlined.ToggleOn
import androidx.compose.material.icons.outlined.WaterDrop
import androidx.compose.material.icons.outlined.Whatshot
import androidx.compose.ui.graphics.vector.ImageVector

/** The iOS SF Symbol names stored on methods, mapped to the closest Material icon. */
fun methodIcon(symbol: String): ImageVector = when {
    symbol.startsWith("drop") -> Icons.Outlined.WaterDrop
    symbol.startsWith("line.3") -> Icons.Outlined.FilterAlt
    symbol.startsWith("switch") -> Icons.Outlined.ToggleOn
    symbol.startsWith("cylinder") -> Icons.Outlined.Compress
    symbol.startsWith("arrow.up.arrow.down") -> Icons.Outlined.SwapVert
    symbol.startsWith("gauge") -> Icons.Outlined.Speed
    symbol.startsWith("snowflake") || symbol.contains("thermometer.snowflake") -> Icons.Outlined.AcUnit
    symbol.startsWith("flame") -> Icons.Outlined.Whatshot
    symbol.contains("mug") -> Icons.Outlined.Coffee
    symbol.contains("machine") || symbol.startsWith("rectangle") -> Icons.Outlined.CoffeeMaker
    else -> Icons.Outlined.LocalCafe
}
