package com.codex.emoc

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class LocalMusicController(private val activity: Activity) {
    private val worker = Executors.newSingleThreadExecutor()
    private val canceled = AtomicBoolean(false)
    private var pending: MethodChannel.Result? = null
    private var closed = false

    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "localMusicPick" -> {
                if (!begin(result)) return true
                val folder = call.argument<Boolean>("folder") == true
                val intent = Intent(if (folder) Intent.ACTION_OPEN_DOCUMENT_TREE else Intent.ACTION_OPEN_DOCUMENT).apply {
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                    if (!folder) {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "audio/*"
                        putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    }
                }
                try { activity.startActivityForResult(intent, if (folder) PICK_FOLDER else PICK_FILES) }
                catch (error: Exception) { finishError("PICKER_UNAVAILABLE", error.message ?: "无法打开文件选择器") }
            }
            "localMusicScan" -> {
                if (!begin(result)) return true
                val roots = call.argument<List<String>>("roots").orEmpty().take(20)
                worker.execute { importUris(emptyList(), roots.map(Uri::parse)) }
            }
            "localLyricsPick" -> {
                if (!begin(result)) return true
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                try { activity.startActivityForResult(intent, PICK_LYRICS) }
                catch (error: Exception) { finishError("PICKER_UNAVAILABLE", error.message ?: "无法打开文件选择器") }
            }
            "cancelLocalMusicImport" -> { canceled.set(true); result.success(null) }
            else -> return false
        }
        return true
    }

    private fun begin(result: MethodChannel.Result): Boolean {
        if (pending != null) { result.error("IMPORT_BUSY", "已有导入任务进行中", null); return false }
        pending = result
        canceled.set(false)
        return true
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode !in setOf(PICK_FILES, PICK_FOLDER, PICK_LYRICS)) return false
        if (resultCode != Activity.RESULT_OK || data == null) { finish(null); return true }
        if (requestCode == PICK_LYRICS) {
            val uri = data.data ?: run { finish(null); return true }
            worker.execute {
                try {
                    val bytes = activity.contentResolver.openInputStream(uri)?.use { input ->
                        val output = java.io.ByteArrayOutputStream()
                        val buffer = ByteArray(4096)
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            if (output.size() + count > 256 * 1024) throw IllegalArgumentException("歌词文件不能超过 256 KB")
                            output.write(buffer, 0, count)
                        }
                        output.toByteArray()
                    } ?: throw IllegalArgumentException("无法读取歌词文件")
                    val text = if (bytes.size >= 2 && (bytes[0].toInt() and 255) == 255 && (bytes[1].toInt() and 255) == 254) {
                        bytes.toString(Charsets.UTF_16LE)
                    } else bytes.toString(Charsets.UTF_8)
                    finish(text.removePrefix("\uFEFF"))
                } catch (error: Exception) { finishError("LYRICS_READ_FAILED", error.message ?: "歌词读取失败") }
            }
            return true
        }
        val uris = buildList {
            data.data?.let { add(it) }
            data.clipData?.let { clip -> for (index in 0 until clip.itemCount) add(clip.getItemAt(index).uri) }
        }.distinct().take(MAX_TRACKS)
        val retained = mutableListOf<Uri>()
        var denied = 0
        for (uri in uris) {
            try {
                activity.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                retained.add(uri)
            } catch (_: Exception) { denied++ }
        }
        worker.execute {
            importUris(if (requestCode == PICK_FILES) retained else emptyList(),
                if (requestCode == PICK_FOLDER) retained else emptyList(), denied)
        }
        return true
    }

    private fun importUris(files: List<Uri>, roots: List<Uri>, initialFailures: Int = 0) {
        try {
            var failed = initialFailures
            var truncated = false
            val selected = LinkedHashSet<Uri>()
            selected.addAll(files)
            for (root in roots) {
                if (canceled.get()) break
                try {
                    val stack = java.util.ArrayDeque<Pair<String, Int>>()
                    stack.add(DocumentsContract.getTreeDocumentId(root) to 0)
                    var visited = 0
                    while (stack.isNotEmpty() && !canceled.get()) {
                        if (selected.size >= MAX_TRACKS || visited >= 20000) { truncated = true; break }
                        val (parent, depth) = stack.removeFirst()
                        val children = DocumentsContract.buildChildDocumentsUriUsingTree(root, parent)
                        activity.contentResolver.query(children, arrayOf(
                            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                            DocumentsContract.Document.COLUMN_MIME_TYPE,
                            DocumentsContract.Document.COLUMN_DISPLAY_NAME
                        ), null, null, null)?.use { cursor ->
                            while (cursor.moveToNext() && !canceled.get()) {
                                visited++
                                val id = cursor.getString(0)
                                val type = cursor.getString(1).orEmpty()
                                val name = cursor.getString(2).orEmpty()
                                if (type == DocumentsContract.Document.MIME_TYPE_DIR && depth < 12) stack.add(id to depth + 1)
                                else if (type.startsWith("audio/") || name.substringAfterLast('.', "").lowercase() in extensions) {
                                    selected.add(DocumentsContract.buildDocumentUriUsingTree(root, id))
                                }
                                if (selected.size >= MAX_TRACKS || visited >= 20000) { truncated = true; break }
                            }
                        }
                    }
                } catch (_: Exception) { failed++ }
            }
            val tracks = mutableListOf<Map<String, Any>>()
            for (uri in selected) {
                if (canceled.get()) break
                try { tracks.add(metadata(uri)) } catch (_: Exception) { failed++ }
            }
            finish(mapOf("tracks" to tracks, "roots" to roots.map(Uri::toString),
                "failed" to failed, "canceled" to canceled.get(), "truncated" to truncated))
        } catch (error: Exception) { finishError("IMPORT_FAILED", error.message ?: "本地音乐导入失败") }
    }

    private fun metadata(uri: Uri): Map<String, Any> {
        var filename = uri.lastPathSegment.orEmpty()
        activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) filename = it.getString(0).orEmpty()
        }
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(activity, uri)
            val title = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE).orEmpty().ifBlank { filename.substringBeforeLast('.', filename) }
            val artist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST).orEmpty()
            val album = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM).orEmpty()
            val key = MessageDigest.getInstance("SHA-256").digest(uri.toString().toByteArray()).joinToString("") { "%02x".format(it) }
            var cover = ""
            val picture = retriever.embeddedPicture
            if (picture != null && picture.size <= 8 * 1024 * 1024) {
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeByteArray(picture, 0, picture.size, bounds)
                var sample = 1
                while (bounds.outWidth / sample > 512 || bounds.outHeight / sample > 512) sample *= 2
                val bitmap = BitmapFactory.decodeByteArray(picture, 0, picture.size, BitmapFactory.Options().apply { inSampleSize = sample })
                if (bitmap != null) {
                    val directory = File(activity.cacheDir, "local_artwork").apply { mkdirs() }
                    val file = File(directory, "$key.jpg")
                    file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 85, it) }
                    bitmap.recycle()
                    cover = Uri.fromFile(file).toString()
                }
            }
            return mapOf("domId" to "local_$key", "kind" to "local", "title" to title,
                "subtitle" to listOf(artist, album).filter(String::isNotBlank).joinToString(" · ").ifBlank { "本地音乐" },
                "imageUrl" to cover, "href" to uri.toString())
        } finally { retriever.release() }
    }

    private fun finish(value: Any?) { activity.runOnUiThread { if (!closed) { pending?.success(value); pending = null } } }
    private fun finishError(code: String, message: String) { activity.runOnUiThread { if (!closed) { pending?.error(code, message, null); pending = null } } }
    fun close() {
        closed = true
        canceled.set(true)
        pending?.error("IMPORT_CANCELED", "导入已取消", null)
        pending = null
        worker.shutdownNow()
    }

    companion object {
        private const val PICK_FILES = 16310
        private const val PICK_FOLDER = 16311
        private const val PICK_LYRICS = 16312
        private const val MAX_TRACKS = 5000
        private val extensions = setOf("mp3", "flac", "m4a", "aac", "ogg", "opus", "wav", "wma", "aiff")
    }
}
