package net.grafm.pdfcompressor

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "openUrl") {
                    openUrl(call.argument<String>("url"), result)
                    return@setMethodCallHandler
                }
                if (call.method != "saveFile") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingResult != null) {
                    result.error("busy", "Another save dialog is already open", null)
                    return@setMethodCallHandler
                }
                pendingResult = result
                pendingPath = call.argument<String>("path")
                // "Speichern unter"-Dialog des Systems (Storage Access Framework)
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "application/pdf"
                    putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                }
                @Suppress("DEPRECATION")
                startActivityForResult(intent, REQUEST_SAVE)
            }
    }

    @Deprecated("Deprecated in Android, still required by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_SAVE) return

        val result = pendingResult ?: return
        val path = pendingPath
        pendingResult = null
        pendingPath = null

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || path == null) {
            result.success(false)
            return
        }
        // Datei per Datenstrom kopieren, damit auch sehr große PDFs nicht
        // komplett im Speicher landen. Läuft im Hintergrund.
        thread {
            try {
                val out = contentResolver.openOutputStream(uri, "wt")
                    ?: throw IllegalStateException("Cannot open $uri")
                out.use { o -> File(path).inputStream().use { it.copyTo(o, 64 * 1024) } }
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                runOnUiThread { result.error("io", e.message, null) }
            }
        }
    }

    // Link im Browser öffnen. Die App selbst braucht dafür keine
    // Internet-Berechtigung, der Browser lädt die Seite.
    private fun openUrl(url: String?, result: MethodChannel.Result) {
        val uri = url?.let(Uri::parse)
        if (uri == null || uri.scheme != "https") {
            result.success(false)
            return
        }
        try {
            startActivity(Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE))
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.success(false)
        }
    }

    private companion object {
        const val CHANNEL = "net.grafm.pdfcompressor/platform"
        const val REQUEST_SAVE = 0x5AFE
    }
}
