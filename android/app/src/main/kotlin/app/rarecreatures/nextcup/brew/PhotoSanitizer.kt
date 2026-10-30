package app.rarecreatures.nextcup.brew

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import java.io.ByteArrayOutputStream
import kotlin.math.max

/**
 * Re-encodes a photo as JPEG with no metadata, so location and camera details never reach the database or an
 * AI request. The pixels are decoded, turned upright, scaled and written fresh: no EXIF is carried over.
 */
object PhotoSanitizer {
    /** Longest edge of the stored photo, in pixels. */
    const val MAX_PIXEL_SIZE = 1568

    fun sanitized(data: ByteArray, maxPixelSize: Int = MAX_PIXEL_SIZE, quality: Int = 80): ByteArray? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(data, 0, data.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxPixelSize) sample *= 2
        val decoded = BitmapFactory.decodeByteArray(data, 0, data.size, BitmapFactory.Options().apply { inSampleSize = sample }) ?: return null
        val rotation = runCatching { ExifInterface(data.inputStream()).rotationDegrees }.getOrDefault(0)
        val longest = max(decoded.width, decoded.height)
        val scale = if (longest > maxPixelSize) maxPixelSize.toFloat() / longest else 1f
        val matrix = Matrix().apply { postScale(scale, scale); postRotate(rotation.toFloat()) }
        val upright = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
        return ByteArrayOutputStream().use { out ->
            upright.compress(Bitmap.CompressFormat.JPEG, quality, out)
            out.toByteArray()
        }
    }
}
