package app.rarecreatures.nextcup.kit

/** Roast level as the starter recipes see it; raw values match the app's `RoastLevel`. */
enum class StarterRoast(val raw: String) {
    ULTRA_LIGHT("ultraLight"), LIGHT("light"), MEDIUM_LIGHT("mediumLight"), MEDIUM("medium"), MEDIUM_DARK("mediumDark"), DARK("dark");

    /** Three bands drive every number: light roasts get hotter water and longer contact, dark roasts the opposite. */
    internal val band: Int get() = when (this) {
        ULTRA_LIGHT, LIGHT -> 0
        MEDIUM_LIGHT, MEDIUM -> 1
        MEDIUM_DARK, DARK -> 2
    }

    companion object {
        fun of(raw: String?) = entries.firstOrNull { it.raw == raw }
    }
}

/** Raw values match the app's `BrewStyle`. */
enum class StarterStyle(val raw: String) { POUR_OVER("pourOver"), IMMERSION("immersion"), ESPRESSO("espresso"), COLD("cold") }

/** A step as the app stores it; `kind` is the raw value of the app's `StepKind`. */
data class StarterStep(val kind: String, val startOffsetS: Int, val targetCumulativeWaterG: Double?, val instruction: String)

/** One generated starting recipe. Next Cup's own, never the roaster's. */
data class StarterRecipe(
    val style: StarterStyle,
    /** The built-in method (`methods.json` key) the recipe is brewed with. */
    val methodKey: String,
    val name: String,
    val doseG: Double,
    val waterG: Double,
    val tempC: Double?,
    val totalTimeS: Int,
    /** What the numbers were based on, and what to change first. */
    val note: String,
    val steps: List<StarterStep>,
)

/** Pure starting recipes from a coffee's roast level and process: one per brew style. */
object StarterRecipes {
    fun recipes(roast: StarterRoast?, process: String?): List<StarterRecipe> =
        StarterStyle.entries.map { recipe(it, roast, process) }

    fun recipe(style: StarterStyle, roast: StarterRoast?, process: String?): StarterRecipe {
        val i = (roast ?: StarterRoast.MEDIUM).band
        // Fruit-forward processes taste harsh quickly when hot, so they start 1 °C cooler.
        val cooler = if (isFermented(process)) 1.0 else 0.0
        val recipe = when (style) {
            StarterStyle.POUR_OVER -> {
                val dose = 20.0
                val water = (dose * listOf(16.5, 16.0, 15.5)[i]).roundHalfAway()
                StarterRecipe(
                    style, "cone-dripper", "Next Cup starting pour over", dose, water, listOf(96.0, 93.0, 90.0)[i] - cooler,
                    listOf(210, 180, 165)[i], "",
                    listOf(
                        step("bloom", 0, dose * 2, "Wet every ground with twice the dose in water; swirl once."),
                        step("pour", 40, (water * 0.6).roundHalfAway(), "Pour in slow circles to 60% of the water."),
                        step("pour", 85, water, "Pour the rest, keeping the bed level."),
                        step("drawdown", 130, null, "Let it drain. Finish by the end of the timer."),
                    ),
                )
            }
            StarterStyle.IMMERSION -> {
                val dose = 20.0
                val water = (dose * listOf(16.0, 15.0, 14.0)[i]).roundHalfAway()
                val steep = listOf(270, 240, 210)[i]
                StarterRecipe(
                    style, "press", "Next Cup starting immersion", dose, water, listOf(96.0, 93.0, 90.0)[i] - cooler, steep + 45, "",
                    listOf(
                        step("pour", 0, water, "Add all the water, wetting every ground."),
                        step("stir", 30, null, "Stir once to break the crust, then cover."),
                        step("wait", 60, null, "Let it steep undisturbed."),
                        step("press", steep, null, "Press slowly and pour at once."),
                    ),
                )
            }
            StarterStyle.ESPRESSO -> {
                val yield = listOf(45.0, 36.0, 32.0)[i]
                StarterRecipe(
                    style, "espresso", "Next Cup starting espresso", 18.0, yield, listOf(95.0, 93.0, 90.0)[i] - cooler,
                    listOf(32, 28, 25)[i], "",
                    listOf(step("pour", 0, yield, "Start the shot; stop when the cup reaches the yield on the scale.")),
                )
            }
            StarterStyle.COLD -> {
                val dose = 60.0
                val water = dose * 10
                val steep = listOf(57_600, 50_400, 43_200)[i]
                StarterRecipe(
                    style, "cold-brew", "Next Cup starting cold brew", dose, water, null, steep, "",
                    listOf(
                        step("pour", 0, water, "Add cold water and wet every ground."),
                        step("stir", 60, null, "Stir, cover, and move it to the fridge."),
                        step("wait", 300, null, "Steep cold. Check back at the end of the timer."),
                        step("drawdown", steep - 600, null, "Filter the concentrate; dilute to taste."),
                    ),
                )
            }
        }
        return recipe.copy(note = note(style, roast, process))
    }

    private fun step(kind: String, offset: Int, target: Double?, text: String) = StarterStep(kind, offset, target, text)

    private fun isFermented(process: String?): Boolean {
        val p = process?.lowercase() ?: return false
        return listOf("natural", "honey", "anaerobic", "carbonic").any { p.contains(it) }
    }

    private fun note(style: StarterStyle, roast: StarterRoast?, process: String?): String {
        val basis = when {
            roast != null && process != null -> "${label(roast)} roast, $process process"
            roast != null -> "${label(roast)} roast"
            else -> "no roast level listed, so a medium roast is assumed"
        }
        val fix = if (style == StarterStyle.COLD) "Too weak: use less water. Too harsh: steep shorter."
        else "Sour: grind finer or brew hotter. Bitter: grind coarser or cool the water."
        return "Next Cup's starting point from $basis. $fix"
    }

    private fun label(roast: StarterRoast) = when (roast) {
        StarterRoast.ULTRA_LIGHT -> "Ultra-light"
        StarterRoast.LIGHT -> "Light"
        StarterRoast.MEDIUM_LIGHT -> "Medium-light"
        StarterRoast.MEDIUM -> "Medium"
        StarterRoast.MEDIUM_DARK -> "Medium-dark"
        StarterRoast.DARK -> "Dark"
    }
}
