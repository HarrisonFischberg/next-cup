package app.rarecreatures.nextcup.data

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

@Dao
interface MethodDao {
    @Query("SELECT * FROM brew_method ORDER BY sortOrder, name") fun observeAll(): Flow<List<BrewMethod>>
    @Query("SELECT * FROM brew_method ORDER BY sortOrder, name") suspend fun all(): List<BrewMethod>
    @Query("SELECT * FROM brew_method WHERE id = :id") suspend fun find(id: String): BrewMethod?
    @Query("SELECT * FROM brew_method WHERE id = :id") fun observe(id: String): Flow<BrewMethod?>
    @Upsert suspend fun upsert(method: BrewMethod)
    @Upsert suspend fun upsertAll(methods: List<BrewMethod>)
    @Delete suspend fun delete(method: BrewMethod)
}

@Dao
interface RecipeDao {
    @Query("SELECT * FROM recipe ORDER BY name") fun observeAll(): Flow<List<Recipe>>
    @Query("SELECT * FROM recipe ORDER BY name") suspend fun all(): List<Recipe>
    @Query("SELECT * FROM recipe WHERE methodId = :methodId ORDER BY name") fun observeForMethod(methodId: String): Flow<List<Recipe>>
    @Query("SELECT * FROM recipe WHERE id = :id") suspend fun find(id: String): Recipe?
    @Query("SELECT * FROM recipe WHERE id = :id") fun observe(id: String): Flow<Recipe?>
    @Query("SELECT * FROM recipe_step WHERE recipeId = :recipeId ORDER BY startOffsetS, `order`") suspend fun steps(recipeId: String): List<RecipeStep>
    @Query("SELECT * FROM recipe_step WHERE recipeId = :recipeId ORDER BY startOffsetS, `order`") fun observeSteps(recipeId: String): Flow<List<RecipeStep>>
    @Query("SELECT * FROM recipe_step") suspend fun allSteps(): List<RecipeStep>
    @Upsert suspend fun upsert(recipe: Recipe)
    @Upsert suspend fun upsertAll(recipes: List<Recipe>)
    @Upsert suspend fun upsertSteps(steps: List<RecipeStep>)
    @Query("DELETE FROM recipe_step WHERE recipeId = :recipeId") suspend fun deleteSteps(recipeId: String)
    @Delete suspend fun delete(recipe: Recipe)

    @Transaction
    suspend fun replaceSteps(recipe: Recipe, steps: List<RecipeStep>) {
        upsert(recipe)
        deleteSteps(recipe.id)
        upsertSteps(steps.map { it.copy(recipeId = recipe.id) })
    }
}

@Dao
interface BrewDao {
    @Query("SELECT * FROM brew ORDER BY date DESC") fun observeAll(): Flow<List<Brew>>
    @Query("SELECT * FROM brew ORDER BY date DESC") suspend fun all(): List<Brew>
    @Query("SELECT COUNT(*) FROM brew") suspend fun count(): Int
    @Query("SELECT COUNT(*) FROM brew") fun observeCount(): Flow<Int>
    @Query("SELECT * FROM brew WHERE id = :id") suspend fun find(id: String): Brew?
    @Query("SELECT * FROM brew WHERE id = :id") fun observe(id: String): Flow<Brew?>
    @Query("SELECT * FROM brew_bean") fun observeAllBeans(): Flow<List<BrewBean>>
    @Query("SELECT * FROM brew_bean") suspend fun allBrewBeans(): List<BrewBean>
    @Query("SELECT * FROM brew_bean WHERE brewId = :brewId") suspend fun beans(brewId: String): List<BrewBean>
    @Upsert suspend fun upsert(brew: Brew)
    @Upsert suspend fun upsertAll(brews: List<Brew>)
    @Upsert suspend fun upsertBeans(beans: List<BrewBean>)
    @Query("DELETE FROM brew_bean WHERE brewId = :brewId") suspend fun deleteBeans(brewId: String)
    @Delete suspend fun delete(brew: Brew)

    @Transaction
    suspend fun save(brew: Brew, beans: List<BrewBean>?) {
        upsert(brew)
        if (beans != null) {
            deleteBeans(brew.id)
            upsertBeans(beans.map { it.copy(brewId = brew.id) })
        }
    }
}

@Dao
interface BeanDao {
    @Query("SELECT * FROM bean ORDER BY name COLLATE NOCASE") fun observeAll(): Flow<List<Bean>>
    @Query("SELECT * FROM bean ORDER BY name COLLATE NOCASE") suspend fun all(): List<Bean>
    @Query("SELECT * FROM bean WHERE id = :id") suspend fun find(id: String): Bean?
    @Query("SELECT * FROM bean WHERE id = :id") fun observe(id: String): Flow<Bean?>
    @Upsert suspend fun upsert(bean: Bean)
    @Upsert suspend fun upsertAll(beans: List<Bean>)
    @Delete suspend fun delete(bean: Bean)
}

@Dao
interface RoasterDao {
    @Query("SELECT * FROM roaster ORDER BY name COLLATE NOCASE") fun observeAll(): Flow<List<Roaster>>
    @Query("SELECT * FROM roaster ORDER BY name COLLATE NOCASE") suspend fun all(): List<Roaster>
    @Query("SELECT * FROM roaster WHERE id = :id") suspend fun find(id: String): Roaster?
    @Upsert suspend fun upsert(roaster: Roaster)
    @Upsert suspend fun upsertAll(roasters: List<Roaster>)
    @Delete suspend fun delete(roaster: Roaster)
}

@Dao
interface GearDao {
    @Query("SELECT * FROM grinder ORDER BY name COLLATE NOCASE") fun observeGrinders(): Flow<List<Grinder>>
    @Query("SELECT * FROM grinder ORDER BY name COLLATE NOCASE") suspend fun grinders(): List<Grinder>
    @Upsert suspend fun upsertGrinder(grinder: Grinder)
    @Upsert suspend fun upsertGrinders(grinders: List<Grinder>)
    @Delete suspend fun deleteGrinder(grinder: Grinder)
    @Query("SELECT * FROM water_profile ORDER BY name COLLATE NOCASE") fun observeWaterProfiles(): Flow<List<WaterProfile>>
    @Query("SELECT * FROM water_profile ORDER BY name COLLATE NOCASE") suspend fun waterProfiles(): List<WaterProfile>
    @Upsert suspend fun upsertWaterProfile(profile: WaterProfile)
    @Upsert suspend fun upsertWaterProfiles(profiles: List<WaterProfile>)
    @Delete suspend fun deleteWaterProfile(profile: WaterProfile)
    @Query("SELECT * FROM taxonomy_alias") fun observeAliases(): Flow<List<TaxonomyAlias>>
    @Query("SELECT * FROM taxonomy_alias") suspend fun aliases(): List<TaxonomyAlias>
    @Upsert suspend fun upsertAlias(alias: TaxonomyAlias)
    @Upsert suspend fun upsertAliases(aliases: List<TaxonomyAlias>)
    @Delete suspend fun deleteAlias(alias: TaxonomyAlias)
}

@Dao
interface SuggestionDao {
    @Query("SELECT * FROM suggestion WHERE sourceBrewId = :brewId ORDER BY createdAt DESC") fun observeForBrew(brewId: String): Flow<List<Suggestion>>
    @Query("SELECT * FROM suggestion") suspend fun all(): List<Suggestion>
    @Query("SELECT * FROM suggestion WHERE id = :id") suspend fun find(id: String): Suggestion?
    @Upsert suspend fun upsert(suggestion: Suggestion)
    @Upsert suspend fun upsertAll(suggestions: List<Suggestion>)
}

@Dao
interface AIRequestDao {
    @Query("SELECT * FROM ai_request ORDER BY createdAt DESC") fun observeAll(): Flow<List<AIRequest>>
    @Query("SELECT * FROM ai_request ORDER BY createdAt") suspend fun all(): List<AIRequest>
    @Query("SELECT * FROM ai_request WHERE status = 'queued' ORDER BY createdAt") suspend fun queued(): List<AIRequest>
    @Query("SELECT * FROM ai_request WHERE id = :id") fun observe(id: String): Flow<AIRequest?>
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun insert(request: AIRequest)
    @Upsert suspend fun upsert(request: AIRequest)
    @Upsert suspend fun upsertAll(requests: List<AIRequest>)
}
