package app.rarecreatures.nextcup.data

import android.content.SharedPreferences
import androidx.room.withTransaction

/**
 * Seeds bundled methods and recipes once per `builtInKey`, as on iOS (BuiltInSeeder.swift).
 * Running it again creates nothing; a newer bundle adds only keys it has not offered before; a row the user
 * edited or deleted is never touched or brought back. Offered keys live in preferences.
 */
class BuiltInSeeder(private val db: NextCupDatabase, private val prefs: SharedPreferences) {
    data class Report(val methodsAdded: Int, val recipesAdded: Int)

    companion object {
        const val METHODS_LEDGER_KEY = "builtIn.offeredMethodKeys"
        const val RECIPES_LEDGER_KEY = "builtIn.offeredRecipeKeys"
    }

    suspend fun seed(content: BuiltInContent): Report {
        val offeredMethods = prefs.getStringSet(METHODS_LEDGER_KEY, emptySet())!!.toSet()
        val offeredRecipes = prefs.getStringSet(RECIPES_LEDGER_KEY, emptySet())!!.toSet()
        var report = Report(0, 0)
        db.withTransaction {
            val methods = db.methods().all()
            val methodsByKey = methods.filter { it.builtInKey != null }.associateBy { it.builtInKey!! }.toMutableMap()
            val existingRecipeKeys = db.recipes().all().mapNotNull { it.builtInKey }.toSet()
            var nextSortOrder = (methods.maxOfOrNull { it.sortOrder } ?: -1) + 1
            var methodsAdded = 0
            var recipesAdded = 0

            for (entry in content.methods) {
                if (entry.key in offeredMethods || methodsByKey.containsKey(entry.key)) continue
                val method = BrewMethod(
                    name = entry.name,
                    style = rawOf<BrewStyle>(entry.style)!!,
                    symbol = entry.symbol,
                    trackedParameters = entry.trackedParameters.mapNotNull { rawOf<BrewParameter>(it) },
                    defaultStepKinds = entry.defaultStepKinds.mapNotNull { rawOf<StepKind>(it) },
                    sortOrder = nextSortOrder++,
                    // A method added by an update waits under More methods; the first seed shows all.
                    isHidden = offeredMethods.isNotEmpty(),
                    builtInKey = entry.key,
                )
                db.methods().upsert(method)
                methodsByKey[entry.key] = method
                methodsAdded++
            }

            for (entry in content.recipes) {
                if (entry.key in offeredRecipes || entry.key in existingRecipeKeys) continue
                val recipe = Recipe(
                    name = entry.name, doseG = entry.doseG, waterG = entry.waterG, tempC = entry.tempC, totalTimeS = entry.totalTimeS,
                    tuningNote = entry.tuningNote, includesIce = entry.includesIce, iceG = entry.iceG, credit = entry.credit,
                    creditURL = entry.creditURL, builtInKey = entry.key, methodId = methodsByKey[entry.methodKey]?.id,
                )
                val steps = entry.steps.mapIndexed { index, step ->
                    RecipeStep(
                        order = index, kind = rawOf<StepKind>(step.kind)!!, startOffsetS = step.startOffsetS,
                        targetCumulativeWaterG = step.targetCumulativeWaterG, instruction = step.instruction, recipeId = recipe.id,
                    )
                }
                db.recipes().replaceSteps(recipe, steps)
                recipesAdded++
            }
            report = Report(methodsAdded, recipesAdded)
        }
        // Recorded only after a committed write, so a failed seed retries next launch.
        prefs.edit()
            .putStringSet(METHODS_LEDGER_KEY, offeredMethods + content.methods.map { it.key })
            .putStringSet(RECIPES_LEDGER_KEY, offeredRecipes + content.recipes.map { it.key })
            .apply()
        return report
    }
}
