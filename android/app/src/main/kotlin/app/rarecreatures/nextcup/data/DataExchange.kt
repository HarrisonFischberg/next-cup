package app.rarecreatures.nextcup.data

import androidx.room.withTransaction
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/** Export, merge import and delete-all, as iOS's DataExchange. */
class DataExchange(private val db: NextCupDatabase) {
    suspend fun archive(): DataArchive {
        fun <T> List<T>.ordered(created: (T) -> Long, id: (T) -> String) = sortedWith(compareBy(created, id))
        return DataArchive(
            methods = db.methods().all().ordered({ it.createdAt }, { it.id }),
            grinders = db.gear().grinders().ordered({ it.createdAt }, { it.id }),
            roasters = db.roasters().all().ordered({ it.createdAt }, { it.id }),
            waterProfiles = db.gear().waterProfiles().ordered({ it.createdAt }, { it.id }),
            aliases = db.gear().aliases().ordered({ it.createdAt }, { it.id }),
            recipes = db.recipes().all().ordered({ it.createdAt }, { it.id }),
            steps = db.recipes().allSteps().ordered({ it.createdAt }, { it.id }),
            beans = db.beans().all().ordered({ it.createdAt }, { it.id }),
            brews = db.brews().all().ordered({ it.createdAt }, { it.id }),
            brewBeans = db.brews().allBrewBeans().ordered({ it.createdAt }, { it.id }),
            suggestions = db.suggestions().all().ordered({ it.createdAt }, { it.id }),
        )
    }

    suspend fun exportJSON(): String = DataArchive.encode(archive())

    suspend fun brewsCSV(): String {
        val methods = db.methods().all().associateBy { it.id }
        val recipes = db.recipes().all().associateBy { it.id }
        val grinders = db.gear().grinders().associateBy { it.id }
        val beans = db.beans().all().associateBy { it.id }
        val uses = db.brews().allBrewBeans().groupBy { it.brewId }
        val rows = mutableListOf(listOf("id", "date", "method", "recipe", "beans", "grinder", "dose_g", "water_g", "temp_c", "time_s", "grind", "tds", "rating", "verdict", "notes"))
        for (b in db.brews().all().sortedBy { it.date }) rows += listOf(
            b.id, iso(b.date), methods[b.methodId]?.name ?: "", recipes[b.recipeId]?.name ?: "",
            uses[b.id].orEmpty().map { beans[it.beanId]?.name ?: it.beanNameSnapshot }.sorted().joinToString("; "),
            grinders[b.grinderId]?.name ?: "", num(b.doseG), num(b.waterG), num(b.tempC), b.totalTimeS?.toString() ?: "", b.grindSetting ?: "",
            num(b.tds), b.ratingTenths?.let { num(it / 10.0) } ?: "", b.verdicts.joinToString("; ") { it.raw }, b.notes,
        )
        return csv(rows, setOf(2, 3, 4, 5, 10, 14))
    }

    suspend fun beansCSV(): String {
        val roasters = db.roasters().all().associateBy { it.id }
        val rows = mutableListOf(listOf("id", "name", "roaster", "country", "region", "process", "varietal", "roast", "roast_date", "bag_g", "status", "decaf", "rating"))
        for (b in db.beans().all().sortedBy { it.name }) rows += listOf(
            b.id, b.name, roasters[b.roasterId]?.name ?: "", b.originCountry ?: "", b.region ?: "", b.process ?: "", b.varietal ?: "",
            b.roastLevel?.raw ?: "", b.roastDate?.let(::iso) ?: "", num(b.bagWeightG), b.status.raw, if (b.isDecaf) "yes" else "no",
            b.ratingTenths?.let { num(it / 10.0) } ?: "",
        )
        return csv(rows, setOf(1, 2, 3, 4, 5, 6))
    }

    enum class Status { NEW, SAME, CONFLICT }
    data class Item(val id: String, val label: String, val title: String, val status: Status)
    data class Plan(val archive: DataArchive, val items: List<Item>) {
        val newCount get() = items.count { it.status == Status.NEW }
        val sameCount get() = items.count { it.status == Status.SAME }
        val conflicts get() = items.filter { it.status == Status.CONFLICT }
    }
    data class Summary(val added: Int, val replaced: Int)

    /**
     * Matches the incoming archive against what is here. Built-in methods and recipes match by key, so the
     * same built-in from another phone is one row. Rows compare without their timestamps.
     */
    suspend fun plan(incoming: DataArchive): Plan {
        val methodByKey = db.methods().all().filter { it.builtInKey != null }.associate { it.builtInKey!! to it.id }
        val recipeByKey = db.recipes().all().filter { it.builtInKey != null }.associate { it.builtInKey!! to it.id }
        val idMap = mutableMapOf<String, String>()
        incoming.methods.forEach { m -> m.builtInKey?.let(methodByKey::get)?.let { idMap[m.id] = it } }
        incoming.recipes.forEach { r -> r.builtInKey?.let(recipeByKey::get)?.let { idMap[r.id] = it } }
        fun map(id: String?) = id?.let { idMap[it] ?: it }
        val adoptedRecipes = incoming.recipes.mapNotNull { idMap[it.id] }.toSet()
        val a = incoming.copy(
            methods = incoming.methods.map { it.copy(id = map(it.id)!!) },
            recipes = incoming.recipes.map { it.copy(id = map(it.id)!!, methodId = map(it.methodId)) },
            // Steps of a built-in recipe that is already here stay as they are here.
            steps = incoming.steps.map { it.copy(recipeId = map(it.recipeId)) }.filter { it.recipeId !in adoptedRecipes },
            brews = incoming.brews.map { it.copy(methodId = map(it.methodId), recipeId = map(it.recipeId)) },
        )
        val items = mutableListOf<Item>()
        fun <T : Any> check(label: String, rows: List<T>, existing: Map<String, T>, id: (T) -> String, title: (T) -> String, core: (T) -> T) {
            for (r in rows) {
                val here = existing[id(r)]
                val status = when {
                    here == null -> Status.NEW
                    same(core(here), core(r)) -> Status.SAME
                    else -> Status.CONFLICT
                }
                items += Item(id(r), label, title(r), status)
            }
        }
        check("Methods", a.methods, db.methods().all().associateBy { it.id }, { it.id }, { it.name }) { it.copy(createdAt = 0, updatedAt = 0) }
        check("Grinders", a.grinders, db.gear().grinders().associateBy { it.id }, { it.id }, { it.name }) { it.copy(createdAt = 0, updatedAt = 0) }
        check("Roasters", a.roasters, db.roasters().all().associateBy { it.id }, { it.id }, { it.name }) { it.copy(createdAt = 0, updatedAt = 0) }
        check("Water profiles", a.waterProfiles, db.gear().waterProfiles().associateBy { it.id }, { it.id }, { it.name }) { it.copy(createdAt = 0, updatedAt = 0) }
        check("Taxonomy aliases", a.aliases, db.gear().aliases().associateBy { it.id }, { it.id }, { it.rawValue }) { it.copy(createdAt = 0, updatedAt = 0) }
        check("Recipes", a.recipes, db.recipes().all().associateBy { it.id }, { it.id }, { it.name }) { it.copy(createdAt = 0, updatedAt = 0) }
        check("Recipe steps", a.steps, db.recipes().allSteps().associateBy { it.id }, { it.id }, { it.instruction.ifEmpty { it.kind.raw } }) { it.copy(createdAt = 0, updatedAt = 0) }
        check("Beans", a.beans, db.beans().all().associateBy { it.id }, { it.id }, { it.name }) { it.copy(createdAt = 0, updatedAt = 0) }
        check("Brews", a.brews, db.brews().all().associateBy { it.id }, { it.id }, { iso(it.date) }) { it.copy(createdAt = 0, updatedAt = 0) }
        check("Beans in brews", a.brewBeans, db.brews().allBrewBeans().associateBy { it.id }, { it.id }, { it.beanNameSnapshot }) { it.copy(createdAt = 0, updatedAt = 0) }
        check("Suggestions", a.suggestions, db.suggestions().all().associateBy { it.id }, { it.id }, { "${it.field.raw}: ${it.fromValue} → ${it.toValue}" }) { it.copy(createdAt = 0, updatedAt = 0) }
        return Plan(a, items)
    }

    /** Rows with byte arrays compare by content. */
    private fun same(a: Any, b: Any): Boolean = when {
        a is Brew && b is Brew -> a.copy(photo = null).toString() == b.copy(photo = null).toString() && a.photo.contentEq(b.photo)
        a is Bean && b is Bean -> a.copy(photo = null).toString() == b.copy(photo = null).toString() && a.photo.contentEq(b.photo)
        else -> a == b
    }

    private fun ByteArray?.contentEq(o: ByteArray?) = if (this == null || o == null) this === o else contentEquals(o)

    /** Writes the plan: new rows are added; differing rows are replaced only when their id is in [overwrite]. All or nothing. */
    suspend fun apply(plan: Plan, overwrite: Set<String>): Summary = db.withTransaction {
        val status = plan.items.associate { it.id to it.status }
        var added = 0
        var replaced = 0
        fun <T> keep(rows: List<T>, id: (T) -> String) = rows.filter {
            when (status[id(it)]) {
                Status.NEW -> { added++; true }
                Status.CONFLICT -> (id(it) in overwrite).also { r -> if (r) replaced++ }
                else -> false
            }
        }
        val a = plan.archive
        db.methods().upsertAll(keep(a.methods) { it.id })
        db.gear().upsertGrinders(keep(a.grinders) { it.id })
        db.roasters().upsertAll(keep(a.roasters) { it.id })
        db.gear().upsertWaterProfiles(keep(a.waterProfiles) { it.id })
        db.gear().upsertAliases(keep(a.aliases) { it.id })
        db.recipes().upsertAll(keep(a.recipes) { it.id })
        db.recipes().upsertSteps(keep(a.steps) { it.id })
        // A relationship pointing at a row neither here nor in the file is dropped rather than failing the import.
        val beanIds = (db.beans().all().map { it.id } + a.beans.map { it.id }).toSet()
        val roasterIds = db.roasters().all().map { it.id }.toSet()
        db.beans().upsertAll(keep(a.beans) { it.id }.map { if (it.roasterId in roasterIds) it else it.copy(roasterId = null) })
        val methodIds = db.methods().all().map { it.id }.toSet()
        val recipeIds = db.recipes().all().map { it.id }.toSet()
        val grinderIds = db.gear().grinders().map { it.id }.toSet()
        val waterIds = db.gear().waterProfiles().map { it.id }.toSet()
        db.brews().upsertAll(keep(a.brews) { it.id }.map {
            it.copy(
                methodId = it.methodId?.takeIf(methodIds::contains), recipeId = it.recipeId?.takeIf(recipeIds::contains),
                grinderId = it.grinderId?.takeIf(grinderIds::contains), waterProfileId = it.waterProfileId?.takeIf(waterIds::contains),
            )
        })
        val brewIds = db.brews().all().map { it.id }.toSet()
        db.brews().upsertBeans(keep(a.brewBeans) { it.id }.filter { it.brewId in brewIds }.map { if (it.beanId in beanIds) it else it.copy(beanId = null) })
        db.suggestions().upsertAll(keep(a.suggestions) { it.id }.filter { it.sourceBrewId == null || it.sourceBrewId in brewIds })
        Summary(added, replaced)
    }

    /** Deletes every row. The caller clears preferences and reseeds the built-ins. */
    suspend fun deleteAll() = db.withTransaction { db.clearAllTables() }

    companion object {
        fun iso(millis: Long): String = DateTimeFormatter.ISO_OFFSET_DATE_TIME.format(Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()))
        private fun num(v: Double?) = v?.let { java.math.BigDecimal(it).setScale(2, java.math.RoundingMode.HALF_UP).stripTrailingZeros().toPlainString() } ?: ""

        /** RFC 4180 quoting; free text that starts like a formula is prefixed with an apostrophe (CSV injection). */
        fun csv(rows: List<List<String>>, textColumns: Set<Int>): String = rows.mapIndexed { r, row ->
            row.mapIndexed { c, cell ->
                var text = cell
                if (r > 0 && c in textColumns && text.firstOrNull()?.let { it in "=+-@\t\r" } == true) text = "'$text"
                if (text.any { it in ",\"\n\r" }) "\"" + text.replace("\"", "\"\"") + "\"" else text
            }.joinToString(",")
        }.joinToString("\r\n") + "\r\n"
    }
}
