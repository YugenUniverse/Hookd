package com.fiatlinux.hookd

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import android.content.pm.PackageManager
import java.io.File

class MainActivity : FlutterActivity() {
  private val CHANNEL = "com.fiatlinux.hookd/install"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "installApk" -> {
            val apkPath = call.argument<String>("apkPath")
            if (apkPath != null) {
              try {
                installApk(apkPath)
                result.success(null)
              } catch (e: Exception) {
                result.error("INSTALL_ERROR", e.message, null)
              }
            } else {
              result.error("INVALID_ARGUMENT", "apkPath is required", null)
            }
          }
          else -> result.notImplemented()
        }
      }
  }

  private fun installApk(apkPath: String) {
    val file = File(apkPath)
    if (!file.exists()) {
      throw Exception("APK file not found: $apkPath")
    }

    val intent = Intent(Intent.ACTION_INSTALL_PACKAGE)

    val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      FileProvider.getUriForFile(
        this,
        "${packageName}.fileprovider",
        file
      )
    } else {
      Uri.fromFile(file)
    }

    intent.data = uri
    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    // For Android 12+, request install permission explicitly
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      if (checkSelfPermission(android.Manifest.permission.REQUEST_INSTALL_PACKAGES) == PackageManager.PERMISSION_GRANTED) {
        intent.putExtra(Intent.EXTRA_INSTALLER_PACKAGE_NAME, packageName)
      }
    } else {
      intent.putExtra(Intent.EXTRA_INSTALLER_PACKAGE_NAME, packageName)
    }

    startActivity(intent)
  }
}