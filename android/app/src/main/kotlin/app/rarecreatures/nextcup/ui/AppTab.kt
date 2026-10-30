package app.rarecreatures.nextcup.ui

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material.icons.outlined.Eco
import androidx.compose.material.icons.outlined.Explore
import androidx.compose.material.icons.outlined.LocalCafe
import androidx.compose.ui.graphics.vector.ImageVector

/** The four tabs, as iOS's AppTab. Raw values are persisted and must never change; Brew keeps "recipes". */
enum class AppTab(val raw: String, val title: String, val icon: ImageVector) {
    RECIPES("recipes", "Brew", Icons.Outlined.LocalCafe),
    JOURNAL("journal", "Journal", Icons.AutoMirrored.Outlined.MenuBook),
    BEANS("beans", "Beans", Icons.Outlined.Eco),
    EXPLORE("explore", "Explore", Icons.Outlined.Explore);

    companion object {
        fun of(raw: String?) = entries.firstOrNull { it.raw == raw } ?: JOURNAL
    }
}
