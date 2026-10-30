package app.rarecreatures.nextcup.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters

@Database(
    entities = [
        Brew::class, BrewBean::class, Bean::class, Roaster::class, BrewMethod::class, Recipe::class, RecipeStep::class,
        Grinder::class, Suggestion::class, AIRequest::class, TaxonomyAlias::class, WaterProfile::class,
    ],
    version = 1,
    exportSchema = true,
)
@TypeConverters(Converters::class)
abstract class NextCupDatabase : RoomDatabase() {
    abstract fun methods(): MethodDao
    abstract fun recipes(): RecipeDao
    abstract fun brews(): BrewDao
    abstract fun beans(): BeanDao
    abstract fun roasters(): RoasterDao
    abstract fun gear(): GearDao
    abstract fun suggestions(): SuggestionDao
    abstract fun aiRequests(): AIRequestDao

    companion object {
        fun open(context: Context): NextCupDatabase =
            Room.databaseBuilder(context, NextCupDatabase::class.java, "nextcup.db").build()
    }
}
