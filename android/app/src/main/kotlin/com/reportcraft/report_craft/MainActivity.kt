package com.reportcraft.report_craft

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.reportcraft/camera"
    private val CAMERA_REQUEST_CODE = 8801
    private var pendingResult: MethodChannel.Result? = null
    private var photoFile: File? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        savedInstanceState?.getString("saved_photo_path")?.let {
            photoFile = File(it)
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        photoFile?.let {
            outState.putString("saved_photo_path", it.absolutePath)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "takePhoto") {
                try {
                    val storageDir = externalCacheDir ?: cacheDir
                    storageDir.mkdirs()
                    val file = File(storageDir, "camera_${System.currentTimeMillis()}.jpg")
                    photoFile = file

                    val uri: Uri = FileProvider.getUriForFile(
                        this,
                        "${applicationContext.packageName}.fileprovider",
                        file
                    )

                    val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
                    intent.putExtra(MediaStore.EXTRA_OUTPUT, uri)
                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    intent.clipData = ClipData.newRawUri("photo", uri)

                    // Grant URI permission explicitly to any resolving camera packages
                    val resInfoList = packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
                    for (resolveInfo in resInfoList) {
                        val pkg = resolveInfo.activityInfo.packageName
                        grantUriPermission(pkg, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    }

                    pendingResult = result
                    startActivityForResult(intent, CAMERA_REQUEST_CODE)
                } catch (e: Exception) {
                    pendingResult = null
                    result.error("CAMERA_ERROR", e.message ?: "Unknown camera error", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == CAMERA_REQUEST_CODE) {
            val result = pendingResult
            pendingResult = null
            try {
                val file = photoFile
                if (resultCode == Activity.RESULT_OK && file != null && file.exists() && file.length() > 0) {
                    result?.success(file.absolutePath)
                } else {
                    result?.success(null)
                }
            } catch (e: Exception) {
                result?.success(null)
            }
        }
    }
}
