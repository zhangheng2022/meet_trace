package com.meettrace.app

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val updateChannel = "com.meettrace.app/app_update"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannel)
            .setMethodCallHandler { call, result ->
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("invalid_path", "APK path is required", null)
                    return@setMethodCallHandler
                }
                try {
                    val apk = trustedUpdateFile(path)
                    when (call.method) {
                        "inspectApk" -> result.success(inspectApk(apk))
                        "requestInstall" -> requestInstall(apk, result)
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("app_update_failed", error.message, null)
                }
            }
    }

    private fun trustedUpdateFile(path: String): File {
        val updateRoot = File(filesDir, "app_updates").canonicalFile
        val apk = File(path).canonicalFile
        val prefix = updateRoot.path + File.separator
        require(apk.path.startsWith(prefix) && apk.isFile) {
            "APK must be an existing file in the private update directory"
        }
        return apk
    }

    @Suppress("DEPRECATION")
    private fun inspectApk(apk: File): Map<String, Any> {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }
        val info = requireNotNull(packageManager.getPackageArchiveInfo(apk.path, flags)) {
            "Cannot read APK package metadata"
        }
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            requireNotNull(info.signingInfo).apkContentsSigners
        } else {
            requireNotNull(info.signatures)
        }
        require(signatures.isNotEmpty()) { "APK has no signing certificates" }
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            info.versionCode.toLong()
        }
        return mapOf(
            "packageName" to info.packageName,
            "versionName" to requireNotNull(info.versionName),
            "versionCode" to versionCode,
            "signingCertificateSha256" to signatures.map { signature ->
                MessageDigest.getInstance("SHA-256")
                    .digest(signature.toByteArray())
                    .joinToString("") { byte -> "%02x".format(byte) }
            },
        )
    }

    private fun requestInstall(apk: File, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ),
            )
            result.error(
                "authorization_required",
                "Allow this source to install the verified update, then retry",
                null,
            )
            return
        }
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.update_files",
            apk,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        require(intent.resolveActivity(packageManager) != null) {
            "No system package installer is available"
        }
        startActivity(intent)
        result.success(null)
    }
}
