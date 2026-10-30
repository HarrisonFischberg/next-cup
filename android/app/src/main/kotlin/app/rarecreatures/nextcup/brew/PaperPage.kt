package app.rarecreatures.nextcup.brew

import app.rarecreatures.nextcup.data.BrewMethod
import app.rarecreatures.nextcup.kit.BrewDraft
import app.rarecreatures.nextcup.kit.PaperImport
import app.rarecreatures.nextcup.kit.PaperLine
import java.util.UUID

/** A photographed journal page, read on device, as a brew form draft to check and save. */
object PaperPage {
    /** On-device recognition gives no per-line confidence here, so every line counts as fairly sure. */
    private const val LINE_CONFIDENCE = 0.8

    fun draft(lines: List<String>, methods: List<BrewMethod>): BrewDraft? {
        val page = PaperImport.parse(lines.map { PaperLine(it, LINE_CONFIDENCE) })
        if (page.isEmpty) return null
        val method = page.method.takeIf { it.isNotBlank() }?.let { name ->
            methods.firstOrNull { it.name.equals(name, true) } ?: methods.firstOrNull { name.contains(it.name, true) || it.name.contains(name, true) }
        }
        // A bean or method name that matches nothing is kept in the notes, so nothing written is lost.
        val extra = listOfNotNull(page.bean.takeIf { it.isNotBlank() }?.let { "Beans: $it" }, page.method.takeIf { it.isNotBlank() && method == null }?.let { "Method: $it" })
        return BrewDraft(
            methodID = method?.id?.let(UUID::fromString), doseG = page.doseG, waterG = page.waterG, tempC = page.tempC, totalTimeS = page.totalTimeS,
            grindSetting = page.grind, ratingTenths = page.ratingTenths ?: 0, notes = (extra + page.notes).filter { it.isNotBlank() }.joinToString("\n"),
        )
    }
}
