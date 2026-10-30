package app.rarecreatures.nextcup.beans

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import app.rarecreatures.nextcup.kit.BarcodeLookup
import app.rarecreatures.nextcup.ui.theme.DS
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.suspendCancellableCoroutine
import java.util.concurrent.Executors
import kotlin.coroutines.resume

enum class ScanMode { BARCODE, LABEL }

/** What a scan found: a retail barcode, or a label photo (metadata stripped) and the text lines read from it. */
sealed interface ScanResult {
    data class Code(val digits: String) : ScanResult
    data class Label(val photo: ByteArray, val lines: List<String>) : ScanResult
}

/**
 * The camera for a coffee bag: CameraX with ML Kit's bundled, on-device barcode and text models (nothing is
 * downloaded at runtime and no image leaves the phone). The camera is asked for only when this opens.
 */
@Composable
fun BagScanner(mode: ScanMode, onResult: (ScanResult) -> Unit, onCancel: () -> Unit) {
    val context = LocalContext.current
    var granted by remember { mutableStateOf(ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) }
    var denied by remember { mutableStateOf(false) }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted = it; denied = !it }
    LaunchedEffect(Unit) { if (!granted) ask.launch(Manifest.permission.CAMERA) }

    if (!granted) {
        Column(Modifier.fillMaxSize().padding(DS.Space.xl), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                if (denied) "Camera access is off for Next Cup. Allow it in system settings, or choose a photo from your library instead."
                else "Next Cup needs the camera to read the bag.",
                textAlign = TextAlign.Center, color = DS.colors.ink,
            )
            TextButton(onClick = onCancel) { Text("Close") }
        }
        return
    }

    val owner = LocalLifecycleOwner.current
    val capture = remember { ImageCapture.Builder().setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY).build() }
    val executor = remember { Executors.newSingleThreadExecutor() }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var done by remember { mutableStateOf(false) }

    Box(Modifier.fillMaxSize()) {
        AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { ctx ->
                val view = PreviewView(ctx)
                val providerFuture = ProcessCameraProvider.getInstance(ctx)
                providerFuture.addListener({
                    val provider = providerFuture.get()
                    val preview = Preview.Builder().build().also { it.surfaceProvider = view.surfaceProvider }
                    val useCases = mutableListOf(preview, capture)
                    if (mode == ScanMode.BARCODE) {
                        val scanner = BarcodeScanning.getClient(
                            BarcodeScannerOptions.Builder().setBarcodeFormats(
                                Barcode.FORMAT_EAN_13, Barcode.FORMAT_EAN_8, Barcode.FORMAT_UPC_A, Barcode.FORMAT_UPC_E, Barcode.FORMAT_ITF,
                            ).build(),
                        )
                        val analysis = ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                        analysis.setAnalyzer(executor) { proxy -> analyze(proxy, scanner) { code -> if (!done) { done = true; onResult(ScanResult.Code(code)) } } }
                        useCases += analysis
                    }
                    runCatching {
                        provider.unbindAll()
                        provider.bindToLifecycle(owner, CameraSelector.DEFAULT_BACK_CAMERA, *useCases.toTypedArray())
                    }.onFailure { error = "The camera could not start." }
                }, ContextCompat.getMainExecutor(ctx))
                view
            },
        )
        Column(Modifier.align(Alignment.BottomCenter).fillMaxWidth().padding(DS.Space.lg), verticalArrangement = Arrangement.spacedBy(DS.Space.sm)) {
            Text(
                if (mode == ScanMode.BARCODE) "Point at the barcode on the bag." else "Fill the frame with the label, then take the photo.",
                color = androidx.compose.ui.graphics.Color.White, style = MaterialTheme.typography.titleMedium,
            )
            error?.let { Text(it, color = DS.colors.error) }
            if (mode == ScanMode.LABEL) Button(
                enabled = !busy,
                onClick = {
                    busy = true
                    capture.takePicture(executor, object : ImageCapture.OnImageCapturedCallback() {
                        override fun onCaptureSuccess(image: ImageProxy) {
                            val bytes = image.toJpegBytes()
                            image.close()
                            val clean = bytes?.let { app.rarecreatures.nextcup.brew.PhotoSanitizer.sanitized(it) }
                            if (clean == null) { busy = false; error = "That photo could not be read."; return }
                            TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                                .process(InputImage.fromBitmap(android.graphics.BitmapFactory.decodeByteArray(clean, 0, clean.size), 0))
                                .addOnSuccessListener { text -> onResult(ScanResult.Label(clean, text.textBlocks.flatMap { b -> b.lines.map { it.text } })) }
                                .addOnFailureListener { onResult(ScanResult.Label(clean, emptyList())) }
                        }

                        override fun onError(exception: ImageCaptureException) {
                            busy = false
                            error = "The photo could not be taken."
                        }
                    })
                },
                modifier = Modifier.fillMaxWidth().height(DS.Size.primary),
            ) { Text(if (busy) "Reading…" else "Take photo") }
            TextButton(onClick = onCancel, modifier = Modifier.fillMaxWidth()) { Text("Cancel", color = androidx.compose.ui.graphics.Color.White) }
        }
    }
    DisposableEffect(Unit) { onDispose { executor.shutdown() } }
}

@androidx.annotation.OptIn(androidx.camera.core.ExperimentalGetImage::class)
private fun analyze(proxy: ImageProxy, scanner: com.google.mlkit.vision.barcode.BarcodeScanner, found: (String) -> Unit) {
    val media = proxy.image ?: return proxy.close()
    scanner.process(InputImage.fromMediaImage(media, proxy.imageInfo.rotationDegrees))
        .addOnSuccessListener { codes -> codes.firstNotNullOfOrNull { it.rawValue?.let(BarcodeLookup::normalized) }?.let(found) }
        .addOnCompleteListener { proxy.close() }
}

/** A captured frame as JPEG bytes (ImageCapture delivers JPEG in its single plane). */
private fun ImageProxy.toJpegBytes(): ByteArray? = runCatching {
    val buffer = planes[0].buffer
    ByteArray(buffer.remaining()).also { buffer.get(it) }
}.getOrNull()

/** Reads text from a photo the user picked from the library, on device. */
suspend fun readText(photo: ByteArray): List<String> = suspendCancellableCoroutine { cont ->
    val bitmap = android.graphics.BitmapFactory.decodeByteArray(photo, 0, photo.size) ?: return@suspendCancellableCoroutine cont.resume(emptyList())
    TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS).process(InputImage.fromBitmap(bitmap, 0))
        .addOnSuccessListener { t -> cont.resume(t.textBlocks.flatMap { b -> b.lines.map { it.text } }) }
        .addOnFailureListener { cont.resume(emptyList()) }
}
