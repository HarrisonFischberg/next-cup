package app.rarecreatures.nextcup.kit

enum class WeightUnit(val raw: String) { GRAMS("grams"), OUNCES("ounces") }

enum class TemperatureUnit(val raw: String) { CELSIUS("celsius"), FAHRENHEIT("fahrenheit") }

/** The single units setting. Storage is always grams and °C; conversion happens here, at display. */
data class UnitPreferences(
    val weight: WeightUnit = WeightUnit.GRAMS,
    val temperature: TemperatureUnit = TemperatureUnit.CELSIUS,
) {
    fun displayWeight(grams: Double): Double = if (weight == WeightUnit.GRAMS) grams else grams / GRAMS_PER_OUNCE
    fun grams(fromDisplayWeight: Double): Double =
        if (weight == WeightUnit.GRAMS) fromDisplayWeight else fromDisplayWeight * GRAMS_PER_OUNCE
    fun displayTemperature(celsius: Double): Double =
        if (temperature == TemperatureUnit.CELSIUS) celsius else celsius * 9 / 5 + 32
    fun celsius(fromDisplayTemperature: Double): Double =
        if (temperature == TemperatureUnit.CELSIUS) fromDisplayTemperature else (fromDisplayTemperature - 32) * 5 / 9

    val weightSymbol: String get() = if (weight == WeightUnit.GRAMS) "g" else "oz"
    val temperatureSymbol: String get() = if (temperature == TemperatureUnit.CELSIUS) "°C" else "°F"

    companion object {
        const val GRAMS_PER_OUNCE = 28.349523125
    }
}
