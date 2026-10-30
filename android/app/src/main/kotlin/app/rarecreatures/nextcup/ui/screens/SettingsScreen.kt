package app.rarecreatures.nextcup.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rarecreatures.nextcup.app
import app.rarecreatures.nextcup.kit.NextCupKit
import app.rarecreatures.nextcup.ui.Kicker
import app.rarecreatures.nextcup.ui.theme.AppStyle
import app.rarecreatures.nextcup.ui.theme.AppearanceMode
import app.rarecreatures.nextcup.ui.theme.Colors
import app.rarecreatures.nextcup.ui.theme.DS

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(back: () -> Unit) {
    val prefs = LocalContext.current.app.prefs
    val style by prefs.style.collectAsStateWithLifecycle()
    val appearance by prefs.appearance.collectAsStateWithLifecycle()
    Column(Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("Settings") },
            navigationIcon = { IconButton(onClick = back) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") } },
            colors = TopAppBarDefaults.topAppBarColors(containerColor = DS.colors.bg, titleContentColor = DS.colors.ink, navigationIconContentColor = DS.colors.ink),
        )
        LazyColumn(Modifier.fillMaxSize(), contentPadding = androidx.compose.foundation.layout.PaddingValues(DS.Space.lg)) {
            item { Kicker("Appearance", Modifier.padding(bottom = DS.Space.sm)) }
            item {
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                    AppearanceMode.entries.forEachIndexed { i, mode ->
                        SegmentedButton(
                            selected = mode == appearance, onClick = { prefs.setAppearance(mode) },
                            shape = SegmentedButtonDefaults.itemShape(i, AppearanceMode.entries.size),
                        ) { Text(mode.title) }
                    }
                }
            }
            item { Kicker("Look", Modifier.padding(top = DS.Space.xl, bottom = DS.Space.sm)) }
            items(AppStyle.entries) { option -> LookRow(option, option == style) { prefs.setStyle(option) } }
            item {
                Text(
                    "Next Cup ${NextCupKit.VERSION} · no accounts, no ads, no tracking.",
                    style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2, modifier = Modifier.padding(top = DS.Space.xl),
                )
            }
        }
    }
}

@Composable
private fun LookRow(style: AppStyle, selected: Boolean, onSelect: () -> Unit) {
    val swatch = Colors.of(style.palette, DS.colors.isDark)
    Surface(
        color = DS.colors.paper, shape = MaterialTheme.shapes.medium,
        border = if (selected) BorderStroke(2.dp, DS.colors.accent) else null,
        modifier = Modifier.fillMaxWidth().padding(vertical = DS.Space.xs)
            .selectable(selected = selected, onClick = onSelect, role = Role.RadioButton),
    ) {
        Row(
            Modifier.heightIn(min = DS.Size.primary).padding(DS.Space.md),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DS.Space.md),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy((-8).dp)) {
                for (c in listOf(swatch.bg, swatch.signal, swatch.accent)) {
                    Surface(color = c, shape = CircleShape, border = BorderStroke(1.dp, DS.colors.line), modifier = Modifier.size(28.dp)) { Box(Modifier) }
                }
            }
            Column(Modifier.weight(1f)) {
                Text(style.title, style = MaterialTheme.typography.titleMedium, color = DS.colors.ink)
                Text(style.mood, style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
            }
            RadioButton(selected = selected, onClick = null)
        }
    }
}
