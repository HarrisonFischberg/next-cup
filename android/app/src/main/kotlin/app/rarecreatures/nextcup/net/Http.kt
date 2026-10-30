package app.rarecreatures.nextcup.net

import app.rarecreatures.nextcup.kit.HTTPResult
import app.rarecreatures.nextcup.kit.HttpRequest
import app.rarecreatures.nextcup.kit.OfflineException
import app.rarecreatures.nextcup.kit.Transport
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.ConnectException
import java.net.HttpURLConnection
import java.net.URL
import java.net.UnknownHostException

/** The app's one door to the network: plain HttpsURLConnection, no SDKs. Only https is allowed. */
object Http : Transport {
    override suspend fun send(request: HttpRequest): HTTPResult = withContext(Dispatchers.IO) {
        require(request.url.startsWith("https://")) { "Only https requests are allowed" }
        val connection = URL(request.url).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = request.method
            connection.connectTimeout = 15_000
            connection.readTimeout = request.timeoutS * 1000
            request.headers.forEach { (k, v) -> connection.setRequestProperty(k, v) }
            request.body?.let { body ->
                connection.doOutput = true
                connection.outputStream.use { it.write(body.toByteArray()) }
            }
            val status = connection.responseCode
            val stream = if (status >= 400) connection.errorStream else connection.inputStream
            HTTPResult(status, stream?.use { it.readBytes() } ?: ByteArray(0))
        } catch (e: UnknownHostException) {
            throw OfflineException()
        } catch (e: ConnectException) {
            throw OfflineException()
        } finally {
            connection.disconnect()
        }
    }

    /** A GET for the small lookups (Open Food Facts, Nominatim): body and status. */
    suspend fun get(url: String, userAgent: String): Pair<ByteArray, Int> =
        send(HttpRequest(url, headers = mapOf("User-Agent" to userAgent, "Accept" to "application/json"), timeoutS = 10)).let { it.body to it.status }
}
