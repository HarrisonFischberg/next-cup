package app.rarecreatures.nextcup.kit

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** A scanned retail barcode looked up in Open Food Facts. Pure: the app supplies the transport. */
object BarcodeLookup {
    /** Open Food Facts asks every client to name itself and give a contact. */
    const val USER_AGENT = "NextCup/1.0 (Android; hello@rarecreatures.app)"

    /** EAN-8, UPC-A/E, EAN-13 and GTIN-14 are 8 to 14 ASCII digits. Anything else never shapes a URL. */
    fun normalized(code: String): String? {
        val digits = code.trim()
        if (digits.length !in 8..14 || !digits.all { it in '0'..'9' }) return null
        return digits
    }

    fun url(code: String): String? =
        normalized(code)?.let { "https://world.openfoodfacts.org/api/v2/product/$it.json?fields=product_name,brands" }

    data class Product(
        /** Empty when the record has only a brand: a brand is not the coffee's name. */
        val name: String,
        /** The first listed brand, usually the roaster. */
        val brand: String?,
    )

    enum class Failure { INVALID_CODE, NOT_FOUND, OFFLINE, UNREADABLE }

    sealed interface Outcome {
        data class Found(val product: Product) : Outcome
        data class Failed(val failure: Failure) : Outcome
    }

    /** Reads a v2 product response. A 404, `status: 0` or a product with neither name nor brand is "not found". */
    fun parse(data: ByteArray, statusCode: Int): Outcome {
        if (statusCode == 404) return Outcome.Failed(Failure.NOT_FOUND)
        if (statusCode !in 200..299) return Outcome.Failed(Failure.UNREADABLE)
        val body = runCatching { Json.parseToJsonElement(data.decodeToString()).jsonObject }.getOrNull()
            ?: return Outcome.Failed(Failure.UNREADABLE)
        fun clean(s: String?): String? = s?.trim()?.takeIf { it.isNotEmpty() }
        val product = body["product"] as? JsonObject
        val status = (body["status"])?.jsonPrimitive?.intOrNull
        val name = clean(product?.get("product_name")?.jsonPrimitive?.contentOrNull)
        val brand = clean(product?.get("brands")?.jsonPrimitive?.contentOrNull?.split(",")?.firstOrNull())
        if (status == 0 || product == null || (name == null && brand == null)) return Outcome.Failed(Failure.NOT_FOUND)
        return Outcome.Found(Product(name ?: "", brand))
    }

    /** Validates the code, fetches through [fetch] (url → body and status), and parses. A transport error is "offline". */
    suspend fun lookUp(code: String, fetch: suspend (String) -> Pair<ByteArray, Int>): Outcome {
        val url = url(code) ?: return Outcome.Failed(Failure.INVALID_CODE)
        val (data, status) = try {
            fetch(url)
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            return Outcome.Failed(Failure.OFFLINE)
        }
        return parse(data, status)
    }
}
