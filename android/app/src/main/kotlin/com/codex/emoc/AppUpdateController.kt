package com.codex.emoc

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.Html
import android.util.Xml
import androidx.core.content.FileProvider
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.dnsoverhttps.DnsOverHttps
import okhttp3.HttpUrl.Companion.toHttpUrl
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.io.StringReader
import java.net.InetAddress
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

internal class AppUpdateController(
    context: Context,
    private val emitEvent: (String, Map<String, Any>) -> Unit
) {
    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val prefs = appContext.getSharedPreferences("emoc", Context.MODE_PRIVATE)
    private val normalClient = createClient()
    private val dohClient: OkHttpClient? = runCatching {
        val bootstrapClient = createClient()
        val cloudflareDns = DnsOverHttps.Builder()
            .client(bootstrapClient)
            .url("https://cloudflare-dns.com/dns-query".toHttpUrl())
            .bootstrapDnsHosts(
                InetAddress.getByAddress(byteArrayOf(1, 1, 1, 1)),
                InetAddress.getByAddress(byteArrayOf(1, 0, 0, 1))
            )
            .includeIPv6(false)
            .build()
        createClient(dns = cloudflareDns)
    }.getOrNull()
    @Volatile
    private var waitingForInstallPermission = false

    fun installedVersion(): Map<String, Any> {
        val info = currentPackageInfo()
        return mapOf(
            "versionName" to info.versionName.orEmpty(),
            "versionCode" to versionCodeOf(info)
        )
    }

    fun downloadedUpdate(): Map<String, Any> {
        val path = prefs.getString(KEY_APK_PATH, null).orEmpty()
        if (path.isBlank()) return mapOf("valid" to false)
        val file = File(path)
        val expectedVersion = prefs.getString(KEY_APK_VERSION, null).orEmpty()
        val packageInfo = validateDownloadedApk(file, expectedVersion)
        if (packageInfo == null) {
            clearDownloadedUpdate(deleteFile = true)
            return mapOf("valid" to false)
        }
        return downloadedMap(file, packageInfo)
    }

    fun checkLatestRelease(
        onSuccess: (Map<String, Any>) -> Unit,
        onError: (String, String) -> Unit
    ) {
        executor.execute {
            try {
                val result = runCatching { fetchLatestReleaseFromApi() }
                    .getOrElse { fetchLatestReleaseFromPublicPages() }
                postSuccess(onSuccess, result)
            } catch (error: Exception) {
                postError(onError, "UPDATE_CHECK_FAILED", readableError(error))
            }
        }
    }

    fun downloadUpdate(
        release: Map<String, Any?>,
        onSuccess: (Map<String, Any>) -> Unit,
        onError: (String, String) -> Unit
    ) {
        executor.execute {
            val tag = release["tagName"]?.toString().orEmpty()
            val expectedVersion = normalizeVersion(
                release["version"]?.toString().orEmpty().ifBlank { tag }
            )
            val url = release["apkUrl"]?.toString().orEmpty()
            val digest = release["digest"]?.toString().orEmpty()
            var partial: File? = null
            try {
                val uri = Uri.parse(url)
                if (uri.scheme != "https" || uri.host.isNullOrBlank()) {
                    throw IOException("Release APK 地址无效")
                }
                val updatesDir = File(appContext.filesDir, "updates").apply { mkdirs() }
                val safeTag = tag.replace(Regex("[^A-Za-z0-9._-]"), "_")
                    .ifBlank { expectedVersion.ifBlank { "latest" } }
                partial = File(updatesDir, "EmoC-$safeTag.apk.part")
                val finalFile = File(updatesDir, "EmoC-$safeTag.apk")
                partial.delete()
                finalFile.delete()
                val request = Request.Builder()
                    .url(url)
                    .header("Accept", "application/octet-stream")
                    .header("User-Agent", "EmoC-Android")
                    .build()
                executeWithDnsFallback(request).use { response ->
                    if (!response.isSuccessful) {
                        throw IOException("下载返回 HTTP ${response.code}")
                    }
                    val body = response.body ?: throw IOException("下载内容为空")
                    val total = body.contentLength().coerceAtLeast(0L)
                    body.byteStream().use { input ->
                        partial.outputStream().buffered().use { output ->
                            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                            var received = 0L
                            var lastUpdateAt = 0L
                            while (true) {
                                val count = input.read(buffer)
                                if (count < 0) break
                                output.write(buffer, 0, count)
                                received += count
                                val now = System.currentTimeMillis()
                                if (now - lastUpdateAt >= 160L ||
                                    (total > 0 && received >= total)
                                ) {
                                    lastUpdateAt = now
                                    emitProgress(received, total)
                                }
                            }
                            output.flush()
                        }
                    }
                }
                verifyDigest(partial, digest)
                val archive = validateDownloadedApk(partial, expectedVersion)
                    ?: throw IOException("APK 包名、版本或签名校验失败")
                if (!partial.renameTo(finalFile)) {
                    partial.copyTo(finalFile, overwrite = true)
                    partial.delete()
                }
                val previousPath = prefs.getString(KEY_APK_PATH, null).orEmpty()
                if (previousPath.isNotBlank() && previousPath != finalFile.absolutePath) {
                    runCatching { File(previousPath).delete() }
                }
                prefs.edit()
                    .putString(KEY_APK_PATH, finalFile.absolutePath)
                    .putString(KEY_APK_TAG, tag)
                    .putString(KEY_APK_VERSION, archive.versionName.orEmpty())
                    .apply()
                val ready = downloadedMap(finalFile, archive)
                emitEvent("updateDownloadReady", ready)
                postSuccess(onSuccess, ready)
            } catch (error: Exception) {
                partial?.delete()
                val message = readableError(error)
                emitEvent("updateDownloadFailed", mapOf("message" to message))
                postError(onError, "UPDATE_DOWNLOAD_FAILED", message)
            }
        }
    }

    fun installDownloaded(activity: Activity): Map<String, Any> {
        val downloaded = downloadedUpdate()
        if (downloaded["valid"] != true) {
            return mapOf("state" to "invalid", "message" to "安装包不存在或校验失败")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !appContext.packageManager.canRequestPackageInstalls()
        ) {
            waitingForInstallPermission = true
            val settingsIntent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${appContext.packageName}")
            )
            activity.startActivity(settingsIntent)
            return mapOf("state" to "permissionRequested")
        }
        waitingForInstallPermission = false
        launchInstaller(activity, File(downloaded["path"].toString()))
        return mapOf("state" to "launched")
    }

    fun onHostResumed(activity: Activity) {
        if (!waitingForInstallPermission) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !appContext.packageManager.canRequestPackageInstalls()
        ) {
            waitingForInstallPermission = false
            return
        }
        waitingForInstallPermission = false
        val downloaded = downloadedUpdate()
        if (downloaded["valid"] == true) {
            mainHandler.postDelayed({
                launchInstaller(activity, File(downloaded["path"].toString()))
            }, 320L)
        }
    }

    fun close() {
        executor.shutdownNow()
        normalClient.dispatcher.executorService.shutdown()
        normalClient.connectionPool.evictAll()
        dohClient?.dispatcher?.executorService?.shutdown()
        dohClient?.connectionPool?.evictAll()
    }

    private fun createClient(dns: okhttp3.Dns? = null): OkHttpClient {
        val builder = OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(40, TimeUnit.SECONDS)
            .writeTimeout(40, TimeUnit.SECONDS)
            .callTimeout(75, TimeUnit.SECONDS)
            .followRedirects(true)
            .followSslRedirects(true)
        if (dns != null) builder.dns(dns)
        return builder.build()
    }

    private fun fetchLatestReleaseFromApi(): Map<String, Any> {
        val request = Request.Builder()
            .url(LATEST_RELEASE_API_URL)
            .header("Accept", "application/vnd.github+json")
            .header("X-GitHub-Api-Version", "2022-11-28")
            .header("User-Agent", "EmoC-Android")
            .build()
        val responseBody = executeWithDnsFallback(request).use { response ->
            if (!response.isSuccessful) {
                throw IOException("GitHub API 返回 HTTP ${response.code}")
            }
            response.body?.string().orEmpty()
        }
        val json = JSONObject(responseBody)
        val assets = json.optJSONArray("assets")
            ?: throw IOException("最新 Release 没有附件")
        var apk: JSONObject? = null
        for (index in 0 until assets.length()) {
            val candidate = assets.optJSONObject(index) ?: continue
            if (candidate.optString("name").endsWith(".apk", ignoreCase = true)) {
                apk = candidate
                break
            }
        }
        val asset = apk ?: throw IOException("最新 Release 没有 APK")
        val tag = json.optString("tag_name")
        return mapOf(
            "tagName" to tag,
            "version" to normalizeVersion(tag),
            "name" to json.optString("name"),
            "body" to json.optString("body"),
            "htmlUrl" to json.optString("html_url"),
            "apkUrl" to asset.optString("browser_download_url"),
            "apkName" to asset.optString("name"),
            "apkSize" to asset.optLong("size"),
            "digest" to asset.optString("digest")
        )
    }

    private fun fetchLatestReleaseFromPublicPages(): Map<String, Any> {
        val latestRequest = Request.Builder()
            .url(LATEST_RELEASE_PAGE_URL)
            .header("User-Agent", "EmoC-Android")
            .build()
        val releasePage = executeWithDnsFallback(latestRequest).use { response ->
            if (!response.isSuccessful) {
                throw IOException("GitHub Release 页面返回 HTTP ${response.code}")
            }
            response.request.url.toString()
        }
        val tagMarker = "/releases/tag/"
        val tag = releasePage.substringAfter(tagMarker, "")
            .substringBefore('?')
            .substringBefore('#')
            .trim('/')
        if (tag.isBlank()) throw IOException("无法识别最新 Release 版本")

        val assetsRequest = Request.Builder()
            .url("$REPOSITORY_URL/releases/expanded_assets/$tag")
            .header("User-Agent", "EmoC-Android")
            .build()
        val assetsHtml = executeWithDnsFallback(assetsRequest).use { response ->
            if (!response.isSuccessful) {
                throw IOException("GitHub Release 附件页返回 HTTP ${response.code}")
            }
            response.body?.string().orEmpty()
        }
        val rawHref = APK_LINK_PATTERN.find(assetsHtml)?.groupValues?.getOrNull(1)
            ?: throw IOException("最新 Release 没有 APK")
        val href = htmlToText(rawHref)
        val apkUrl = if (href.startsWith("https://")) href else "https://github.com$href"
        val apkName = Uri.decode(apkUrl.substringAfterLast('/'))
        val feedInfo = readReleaseFeed(tag)
        return mapOf(
            "tagName" to tag,
            "version" to normalizeVersion(tag),
            "name" to feedInfo.title.ifBlank { "EmoC $tag" },
            "body" to feedInfo.notes,
            "htmlUrl" to "$REPOSITORY_URL/releases/tag/$tag",
            "apkUrl" to apkUrl,
            "apkName" to apkName,
            "apkSize" to 0L,
            "digest" to ""
        )
    }

    private fun readReleaseFeed(tag: String): ReleaseFeedInfo {
        val request = Request.Builder()
            .url("$REPOSITORY_URL/releases.atom")
            .header("Accept", "application/atom+xml")
            .header("User-Agent", "EmoC-Android")
            .build()
        val xml = executeWithDnsFallback(request).use { response ->
            if (!response.isSuccessful) return ReleaseFeedInfo()
            response.body?.string().orEmpty()
        }
        if (xml.isBlank()) return ReleaseFeedInfo()
        return runCatching {
            val parser = Xml.newPullParser()
            parser.setInput(StringReader(xml))
            var insideEntry = false
            var title = ""
            var notes = ""
            var link = ""
            while (parser.eventType != org.xmlpull.v1.XmlPullParser.END_DOCUMENT) {
                when (parser.eventType) {
                    org.xmlpull.v1.XmlPullParser.START_TAG -> when (parser.name) {
                        "entry" -> {
                            insideEntry = true
                            title = ""
                            notes = ""
                            link = ""
                        }
                        "title" -> if (insideEntry) title = parser.nextText()
                        "content" -> if (insideEntry) notes = parser.nextText()
                        "link" -> if (insideEntry) {
                            link = parser.getAttributeValue(null, "href").orEmpty()
                        }
                    }
                    org.xmlpull.v1.XmlPullParser.END_TAG -> if (
                        parser.name == "entry" && insideEntry
                    ) {
                        if (link.contains("/releases/tag/$tag")) {
                            return@runCatching ReleaseFeedInfo(
                                title = htmlToText(title),
                                notes = htmlToText(notes)
                            )
                        }
                        insideEntry = false
                    }
                }
                parser.next()
            }
            ReleaseFeedInfo()
        }.getOrDefault(ReleaseFeedInfo())
    }

    @Suppress("DEPRECATION")
    private fun htmlToText(value: String): String {
        val spanned = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            Html.fromHtml(value, Html.FROM_HTML_MODE_LEGACY)
        } else {
            Html.fromHtml(value)
        }
        return spanned.toString().replace(Regex("\\n{3,}"), "\n\n").trim()
    }

    private fun executeWithDnsFallback(request: Request): Response {
        return try {
            normalClient.newCall(request).execute()
        } catch (primary: IOException) {
            val fallback = dohClient ?: throw primary
            fallback.newCall(request).execute()
        }
    }

    private fun emitProgress(received: Long, total: Long) {
        val progress = if (total > 0L) {
            (received.toDouble() / total.toDouble()).coerceIn(0.0, 1.0)
        } else {
            0.0
        }
        emitEvent(
            "updateDownloadProgress",
            mapOf(
                "receivedBytes" to received,
                "totalBytes" to total,
                "progress" to progress
            )
        )
    }

    private fun verifyDigest(file: File, digest: String) {
        if (digest.isBlank()) return
        val separator = digest.indexOf(':')
        if (separator <= 0) return
        val algorithm = digest.substring(0, separator).lowercase()
        if (algorithm != "sha256") return
        val expected = digest.substring(separator + 1).lowercase()
        val messageDigest = MessageDigest.getInstance("SHA-256")
        file.inputStream().buffered().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                messageDigest.update(buffer, 0, count)
            }
        }
        val actual = messageDigest.digest().joinToString("") { "%02x".format(it) }
        if (!actual.equals(expected, ignoreCase = true)) {
            throw IOException("APK SHA-256 校验失败")
        }
    }

    private fun validateDownloadedApk(file: File, expectedVersion: String): PackageInfo? {
        if (!file.isFile || file.length() <= 0L) return null
        val archive = packageInfoForArchive(file) ?: return null
        if (archive.packageName != appContext.packageName) return null
        val current = currentPackageInfo()
        if (versionCodeOf(archive) <= versionCodeOf(current)) return null
        if (expectedVersion.isNotBlank() &&
            normalizeVersion(archive.versionName.orEmpty()) != normalizeVersion(expectedVersion)
        ) {
            return null
        }
        val currentSignatures = signatureDigests(current)
        val archiveSignatures = signatureDigests(archive)
        if (currentSignatures.isEmpty() ||
            archiveSignatures.isEmpty() ||
            currentSignatures.intersect(archiveSignatures).isEmpty()
        ) {
            return null
        }
        return archive
    }

    @Suppress("DEPRECATION")
    private fun currentPackageInfo(): PackageInfo {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            appContext.packageManager.getPackageInfo(
                appContext.packageName,
                PackageManager.PackageInfoFlags.of(
                    PackageManager.GET_SIGNING_CERTIFICATES.toLong()
                )
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            appContext.packageManager.getPackageInfo(
                appContext.packageName,
                PackageManager.GET_SIGNING_CERTIFICATES
            )
        } else {
            appContext.packageManager.getPackageInfo(
                appContext.packageName,
                PackageManager.GET_SIGNATURES
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun packageInfoForArchive(file: File): PackageInfo? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            appContext.packageManager.getPackageArchiveInfo(
                file.absolutePath,
                PackageManager.PackageInfoFlags.of(
                    PackageManager.GET_SIGNING_CERTIFICATES.toLong()
                )
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            appContext.packageManager.getPackageArchiveInfo(
                file.absolutePath,
                PackageManager.GET_SIGNING_CERTIFICATES
            )
        } else {
            appContext.packageManager.getPackageArchiveInfo(
                file.absolutePath,
                PackageManager.GET_SIGNATURES
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun signatureDigests(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = info.signingInfo ?: return emptySet()
            if (signingInfo.hasMultipleSigners()) {
                signingInfo.apkContentsSigners
            } else {
                signingInfo.signingCertificateHistory
            }
        } else {
            info.signatures
        }
        return signatures.orEmpty().mapTo(mutableSetOf()) { signature ->
            MessageDigest.getInstance("SHA-256")
                .digest(signature.toByteArray())
                .joinToString("") { "%02x".format(it) }
        }
    }

    @Suppress("DEPRECATION")
    private fun versionCodeOf(info: PackageInfo): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            info.versionCode.toLong()
        }
    }

    private fun downloadedMap(file: File, info: PackageInfo): Map<String, Any> {
        return mapOf(
            "valid" to true,
            "path" to file.absolutePath,
            "tagName" to prefs.getString(KEY_APK_TAG, null).orEmpty(),
            "versionName" to info.versionName.orEmpty(),
            "versionCode" to versionCodeOf(info),
            "size" to file.length()
        )
    }

    private fun clearDownloadedUpdate(deleteFile: Boolean) {
        val path = prefs.getString(KEY_APK_PATH, null).orEmpty()
        if (deleteFile && path.isNotEmpty()) runCatching { File(path).delete() }
        prefs.edit()
            .remove(KEY_APK_PATH)
            .remove(KEY_APK_TAG)
            .remove(KEY_APK_VERSION)
            .apply()
    }

    private fun launchInstaller(activity: Activity, file: File) {
        val contentUri = FileProvider.getUriForFile(
            appContext,
            "${appContext.packageName}.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(contentUri, APK_MIME_TYPE)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(intent)
    }

    private fun postSuccess(
        callback: (Map<String, Any>) -> Unit,
        value: Map<String, Any>
    ) {
        mainHandler.post { callback(value) }
    }

    private fun postError(
        callback: (String, String) -> Unit,
        code: String,
        message: String
    ) {
        mainHandler.post { callback(code, message) }
    }

    private fun readableError(error: Exception): String {
        return error.message?.takeIf { it.isNotBlank() }
            ?: "连接 GitHub 失败，请稍后重试"
    }

    private fun normalizeVersion(value: String): String {
        return Regex("\\d+(?:\\.\\d+)*")
            .find(value.trim().removePrefix("v").removePrefix("V"))
            ?.value
            .orEmpty()
    }

    companion object {
        private const val LATEST_RELEASE_API_URL =
            "https://api.github.com/repos/yufenghub/EmoC/releases/latest"
        private const val REPOSITORY_URL = "https://github.com/yufenghub/EmoC"
        private const val LATEST_RELEASE_PAGE_URL = "$REPOSITORY_URL/releases/latest"
        private val APK_LINK_PATTERN = Regex(
            """href="([^"]*/releases/download/[^"]+\.apk[^"]*)""",
            RegexOption.IGNORE_CASE
        )
        private const val APK_MIME_TYPE = "application/vnd.android.package-archive"
        private const val KEY_APK_PATH = "downloadedUpdateApkPath"
        private const val KEY_APK_TAG = "downloadedUpdateTag"
        private const val KEY_APK_VERSION = "downloadedUpdateVersion"
    }

    private data class ReleaseFeedInfo(
        val title: String = "",
        val notes: String = ""
    )
}
