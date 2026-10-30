package app.rarecreatures.nextcup.beans

import app.rarecreatures.nextcup.data.Bean
import app.rarecreatures.nextcup.data.Brew
import app.rarecreatures.nextcup.data.BrewBean
import app.rarecreatures.nextcup.data.BrewMethod
import app.rarecreatures.nextcup.data.Grinder
import app.rarecreatures.nextcup.data.Recipe
import app.rarecreatures.nextcup.data.TaxonomyAlias
import app.rarecreatures.nextcup.kit.BestSoFar
import app.rarecreatures.nextcup.kit.BestSoFarSummary
import app.rarecreatures.nextcup.kit.BrewSample
import app.rarecreatures.nextcup.kit.BucketRef
import app.rarecreatures.nextcup.kit.RecommendationResult
import app.rarecreatures.nextcup.kit.Recommender
import app.rarecreatures.nextcup.kit.RecommenderBrew
import app.rarecreatures.nextcup.kit.Taxonomy
import java.time.Instant

/** Joins the database rows the bean screens read into the core's value types. */
object BeanInsights {
    fun aliases(rows: List<TaxonomyAlias>) = rows.mapNotNull { a -> Taxonomy.Dimension.of(a.dimension.raw)?.let { Taxonomy.Alias(it, a.rawValue, a.bucketKey) } }

    /** The origin, process and roast buckets of a bean, plus its flavor notes. */
    fun buckets(bean: Bean, taxonomy: Taxonomy, aliases: List<Taxonomy.Alias>): List<BucketRef> {
        fun refs(raws: List<String?>, d: Taxonomy.Dimension) = taxonomy.buckets(raws.filterNotNull(), d, aliases).map { BucketRef(it, d) }
        return refs(listOf(bean.originCountry, bean.region), Taxonomy.Dimension.ORIGIN) +
            refs(listOf(bean.process), Taxonomy.Dimension.PROCESS) +
            refs(listOf(bean.roastLevel?.label), Taxonomy.Dimension.ROAST) +
            refs(bean.bagFlavorNotes, Taxonomy.Dimension.FLAVOR)
    }

    fun bestSoFar(bean: Bean, brews: List<Brew>, uses: List<BrewBean>, grinders: List<Grinder>): BestSoFarSummary {
        val ids = uses.filter { it.beanId == bean.id }.mapNotNull { it.brewId }.toSet()
        return BestSoFar.summarize(
            brews.filter { it.id in ids }.map { b ->
                BrewSample(Instant.ofEpochMilli(b.date), b.ratingTenths, b.doseG, b.waterG, b.tempC, b.totalTimeS, b.grindSetting, grinders.firstOrNull { it.id == b.grinderId }?.name)
            },
        )
    }

    fun recommend(
        bean: Bean, beans: List<Bean>, brews: List<Brew>, uses: List<BrewBean>, methods: List<BrewMethod>, recipes: List<Recipe>,
        taxonomy: Taxonomy, aliases: List<Taxonomy.Alias>,
    ): RecommendationResult {
        val history = brews.mapNotNull { b ->
            val method = methods.firstOrNull { it.id == b.methodId } ?: return@mapNotNull null
            val brewBeans = uses.filter { it.brewId == b.id }.mapNotNull { u -> beans.firstOrNull { it.id == u.beanId } }
            RecommenderBrew(
                Instant.ofEpochMilli(b.date), b.ratingTenths, method.builtInKey, method.name, recipes.firstOrNull { it.id == b.recipeId }?.name,
                b.doseG, b.waterG, b.tempC, b.totalTimeS, b.grindSetting, brewBeans.flatMap { buckets(it, taxonomy, aliases) }.distinct(),
            )
        }
        return Recommender.recommend(buckets(bean, taxonomy, aliases), history)
    }
}
