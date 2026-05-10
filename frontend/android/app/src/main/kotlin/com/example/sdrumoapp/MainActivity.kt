package com.example.sdrumoapp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import java.io.File

class MainActivity : FlutterActivity() {
  private val CHANNEL = "com.fiatlinux.sdrumoapp/install"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "installApk" -> {
            val apkPath = call.argument<String>("apkPath")
            if (apkPath != null) {
              installApk(apkPath)
              result.success(null)
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
      return
    }

    val intent = Intent(Intent.ACTION_VIEW)

    val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      FileProvider.getUriForFile(
        this,
        "${packageName}.fileprovider",
        file
      )
    } else {
      Uri.fromFile(file)
    }

    intent.setDataAndType(uri, "application/vnd.android.package-archive")
    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    startActivity(intent)
  }
}