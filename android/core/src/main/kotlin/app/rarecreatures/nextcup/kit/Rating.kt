package app.rarecreatures.nextcup.kit

/** A cup's rating is stored as tenths of a point out of 10 (0 to 100); 0 means not rated. */
object Rating {
    const val MAX_TENTHS = 100

    /** "8" for a whole number, otherwise "7.4". */
    fun text(tenths: Int): String = if (tenths % 10 == 0) "${tenths / 10}" else fmt("%.1f", tenths / 10.0)

    /** An average, always with one decimal: "7.6". */
    fun text(average: Double): String = fmt("%.1f", average / 10)
}
