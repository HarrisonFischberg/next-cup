package app.rarecreatures.nextcup.beans

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.CancellationSignal
import androidx.core.content.ContextCompat
import app.rarecreatures.nextcup.net.Http
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.URLEncoder
import java.util.Locale
import kotlin.coroutines.resume

/** One roaster found on the map. Nothing is stored until the user saves it. */
data class RoasterPlace(val name: String, val city: String?, val website: String?, val latitude: Double, val longitude: Double) {
    val id: String get() = "$name|${(latitude * 10_000).toInt()}|${(longitude * 10_000).toInt()}"
}

sealed interface SearchArea {
    data class Near(val latitude: Double, val longitude: Double) : SearchArea
    data class City(val name: String) : SearchArea
    /** A roaster name read off a bag, looked up to match a real business. */
    data class Named(val name: String) : SearchArea
}

/**
 * Roaster search on OpenStreetMap's Nominatim, the Android stand-in for iOS's MapKit search. Nominatim's usage
 * policy is kept: an identifying User-Agent, at most one request a second, only when the user asks, and the
 * results credit OpenStreetMap on screen.
 */
object RoasterSearch {
    const val USER_AGENT = "NextCup/1.0 (Android; hello@rarecreatures.app)"
    const val ATTRIBUTION = "Search by OpenStreetMap Nominatim. Map data © OpenStreetMap contributors."
    private const val ENDPOINT = "https://nominatim.openstreetmap.org/search"
    private val json = Json { ignoreUnknownKeys = true }
    private val gate = Mutex()
    private var lastRequestAt = 0L

    @Serializable
    private data class Result(
        val name: String? = null, val display_name: String? = null, val lat: String, val lon: String,
        val address: Map<String, String>? = null, val extratags: Map<String, String>? = null,
    )

    private fun encode(s: String) = URLEncoder.encode(s, "UTF-8")

    internal fun url(area: SearchArea): String {
        val base = "$ENDPOINT?format=jsonv2&addressdetails=1&extratags=1&limit=20&accept-language=${Locale.getDefault().toLanguageTag()}"
        return when (area) {
            is SearchArea.Near -> {
                // About 25 km around the point, as on iOS.
                val d = 0.23
                "$base&q=${encode("coffee roaster")}&bounded=1&viewbox=${area.longitude - d},${area.latitude + d},${area.longitude + d},${area.latitude - d}"
            }
            is SearchArea.City -> "$base&q=${encode("coffee roaster ${area.name}")}"
            is SearchArea.Named -> "$base&q=${encode(area.name)}"
        }
    }

    internal fun parse(body: String): List<RoasterPlace> {
        val seen = mutableSetOf<String>()
        return json.decodeFromString<List<Result>>(body).mapNotNull { r ->
            val name = r.name?.takeIf { it.isNotBlank() } ?: return@mapNotNull null
            val lat = r.lat.toDoubleOrNull() ?: return@mapNotNull null
            val lon = r.lon.toDoubleOrNull() ?: return@mapNotNull null
            val a = r.address.orEmpty()
            val website = (r.extratags?.get("website") ?: r.extratags?.get("contact:website"))?.takeIf { it.startsWith("https://") }
            RoasterPlace(name, a["city"] ?: a["town"] ?: a["village"], website, lat, lon).takeIf { seen.add(it.id) }
        }
    }

    suspend fun search(area: SearchArea): List<RoasterPlace> {
        val places = fetch(url(area))
        // A bag's brand plus "coffee roaster" often finds nothing; try the city query wording too.
        if (places.isEmpty() && area is SearchArea.Named) return fetch(url(SearchArea.City(area.name)))
        return places
    }

    private suspend fun fetch(url: String): List<RoasterPlace> = gate.withLock {
        val wait = 1_100 - (System.currentTimeMillis() - lastRequestAt)
        if (wait > 0) delay(wait)
        lastRequestAt = System.currentTimeMillis()
        val (body, status) = Http.get(url, USER_AGENT)
        if (status !in 200..299) throw IllegalStateException("The map search returned an error (HTTP $status).")
        parse(body.decodeToString())
    }
}

/** One coarse location fix, used for one search and never stored. Call only after the permission is granted. */
object DeviceLocation {
    @SuppressLint("MissingPermission")
    suspend fun current(context: Context): Location? {
        val manager = ContextCompat.getSystemService(context, LocationManager::class.java) ?: return null
        val provider = listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER).firstOrNull { runCatching { manager.isProviderEnabled(it) }.getOrDefault(false) }
            ?: return null
        manager.getLastKnownLocation(provider)?.takeIf { System.currentTimeMillis() - it.time < 30 * 60_000 }?.let { return it }
        if (Build.VERSION.SDK_INT < 30) return manager.getLastKnownLocation(provider)
        return suspendCancellableCoroutine { cont ->
            val signal = CancellationSignal()
            cont.invokeOnCancellation { signal.cancel() }
            manager.getCurrentLocation(provider, signal, ContextCompat.getMainExecutor(context)) { cont.resume(it) }
        }
    }
}
