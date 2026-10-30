package app.rarecreatures.nextcup.kit

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/** A span the bag spent in the freezer. `thawedOn == null` means it is still frozen. */
data class FrozenSpan(val frozenOn: Instant, val thawedOn: Instant? = null)

enum class FreshnessState { UNKNOWN, RESTING, PEAK, PAST_PEAK, FROZEN }

data class FreshnessWindows(
    /** Days after roast the beans are still resting (before this age). */
    val restingDays: Int = 5,
    /** Last day (inclusive) counted as peak. */
    val peakEndDay: Int = 30,
)

object Freshness {
    private fun Instant.day(zone: ZoneId): LocalDate = atZone(zone).toLocalDate()

    /** Calendar days since roast in [zone], with frozen days left out; `null` without a roast date or for a future one. */
    fun ageDays(
        roastDate: Instant?, frozenSpans: List<FrozenSpan> = emptyList(), today: Instant,
        zone: ZoneId = ZoneId.systemDefault(),
    ): Int? {
        if (roastDate == null) return null
        val start = roastDate.day(zone)
        val end = today.day(zone)
        if (end < start) return null
        var frozenDays = 0L
        for (span in frozenSpans) {
            val spanStart = maxOf(span.frozenOn.day(zone), start)
            val spanEnd = minOf(span.thawedOn?.day(zone) ?: end, end)
            if (spanEnd > spanStart) frozenDays += ChronoUnit.DAYS.between(spanStart, spanEnd)
        }
        val total = ChronoUnit.DAYS.between(start, end)
        return maxOf(total - frozenDays, 0).toInt()
    }

    fun state(
        roastDate: Instant?, frozenSpans: List<FrozenSpan> = emptyList(), today: Instant,
        windows: FreshnessWindows = FreshnessWindows(), zone: ZoneId = ZoneId.systemDefault(),
    ): FreshnessState {
        if (roastDate == null) return FreshnessState.UNKNOWN
        val frozenNow = frozenSpans.any { it.thawedOn == null && it.frozenOn.day(zone) <= today.day(zone) }
        if (frozenNow) return FreshnessState.FROZEN
        val age = ageDays(roastDate, frozenSpans, today, zone) ?: return FreshnessState.UNKNOWN
        return when {
            age < windows.restingDays -> FreshnessState.RESTING
            age <= windows.peakEndDay -> FreshnessState.PEAK
            else -> FreshnessState.PAST_PEAK
        }
    }
}
