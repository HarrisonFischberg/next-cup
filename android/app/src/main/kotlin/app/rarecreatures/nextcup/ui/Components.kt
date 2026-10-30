package app.rarecreatures.nextcup.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.rarecreatures.nextcup.ui.theme.DS

/** Small tracked label in the accent: a kicker over a title. */
@Composable
fun Kicker(text: String, modifier: Modifier = Modifier) {
    Text(text.uppercase(), style = MaterialTheme.typography.labelSmall, color = DS.colors.accent, modifier = modifier)
}

/** "NEXT CUP" over a big title, with room on the right for actions. */
@Composable
fun PageHeader(title: String, kicker: String = "Next Cup", trailing: @Composable () -> Unit = {}) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = DS.Space.lg, vertical = DS.Space.md),
        verticalAlignment = Alignment.Bottom,
    ) {
        Column(Modifier.weight(1f)) {
            Kicker(kicker)
            Text(
                title, style = MaterialTheme.typography.displaySmall, color = DS.colors.ink, maxLines = 1,
                overflow = TextOverflow.Ellipsis, modifier = Modifier.semantics { heading() },
            )
        }
        trailing()
    }
}

/** Settings, from the top of every tab. */
@Composable
fun SettingsGear(onClick: () -> Unit) {
    IconButton(onClick = onClick) { Icon(Icons.Outlined.Settings, contentDescription = "Settings", tint = DS.colors.ink) }
}

/** An empty screen that says what goes here and offers the next action. */
@Composable
fun EmptyState(title: String, message: String, action: String? = null, onAction: () -> Unit = {}) {
    Column(
        Modifier.fillMaxWidth().padding(DS.Space.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(DS.Space.sm),
    ) {
        Spacer(Modifier.padding(top = 32.dp))
        Text(title, style = MaterialTheme.typography.titleLarge, color = DS.colors.ink, textAlign = TextAlign.Center)
        Text(message, style = MaterialTheme.typography.bodyMedium, color = DS.colors.ink2, textAlign = TextAlign.Center, modifier = Modifier.widthIn(max = 420.dp))
        if (action != null) Button(onClick = onAction, modifier = Modifier.padding(top = DS.Space.sm)) { Text(action) }
    }
}
