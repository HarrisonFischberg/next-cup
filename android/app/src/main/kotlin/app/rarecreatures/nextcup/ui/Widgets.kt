package app.rarecreatures.nextcup.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import app.rarecreatures.nextcup.ui.theme.DS

/** A pushed screen's bar: back on the left, the title, actions on the right. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BackBar(title: String, back: () -> Unit, actions: @Composable () -> Unit = {}) {
    TopAppBar(
        title = { Text(title, maxLines = 1) },
        navigationIcon = { IconButton(onClick = back) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") } },
        actions = { actions() },
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor = DS.colors.bg, titleContentColor = DS.colors.ink, navigationIconContentColor = DS.colors.ink, actionIconContentColor = DS.colors.ink,
        ),
    )
}

/** A rounded panel in the look's paper colour, with an optional kicker. */
@Composable
fun Panel(kicker: String? = null, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Surface(color = DS.colors.paper, contentColor = DS.colors.ink, shape = MaterialTheme.shapes.medium, modifier = modifier.fillMaxWidth()) {
        Column(Modifier.padding(DS.Space.lg), verticalArrangement = Arrangement.spacedBy(DS.Space.sm)) {
            if (kicker != null) Kicker(kicker)
            content()
        }
    }
}

/** A value with minus and plus buttons; TalkBack reads it as one element. */
@Composable
fun StepperRow(label: String, value: String, onMinus: () -> Unit, onPlus: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier.fillMaxWidth().heightIn(min = DS.Size.minTap),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Space.sm),
    ) {
        Column(Modifier.weight(1f).semantics(mergeDescendants = true) { contentDescription = "$label, $value" }) {
            Text(label, style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
            Text(value, style = MaterialTheme.typography.titleLarge, color = DS.colors.ink)
        }
        val colors = IconButtonDefaults.filledTonalIconButtonColors(containerColor = DS.colors.kraft, contentColor = DS.colors.onKraft)
        FilledTonalIconButton(onClick = onMinus, colors = colors, modifier = Modifier.size(DS.Size.minTap)) { Icon(Icons.Filled.Remove, "Less $label") }
        FilledTonalIconButton(onClick = onPlus, colors = colors, modifier = Modifier.size(DS.Size.minTap)) { Icon(Icons.Filled.Add, "More $label") }
    }
}

/** A big number with its label. */
@Composable
fun Figure(label: String, value: String, modifier: Modifier = Modifier) {
    Column(modifier.semantics(mergeDescendants = true) {}.padding(vertical = DS.Space.xs)) {
        Text(label, style = MaterialTheme.typography.bodySmall, color = DS.colors.ink2)
        Text(value, style = MaterialTheme.typography.headlineSmall, color = DS.colors.ink)
    }
}

val ScreenPadding = Modifier.padding(horizontal = 16.dp)
