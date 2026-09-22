package com.example.mobile

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.StatFs
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sw1.local_ai/resources")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "read" -> {
                        val memory = ActivityManager.MemoryInfo()
                        (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager)
                            .getMemoryInfo(memory)
                        val storage = StatFs(filesDir.absolutePath)
                        val architecture = if (Build.SUPPORTED_64_BIT_ABIS.any { it == "arm64-v8a" }) {
                            "android-arm64"
                        } else {
                            "unsupported"
                        }
                        result.success(
                            mapOf(
                                "architecture" to architecture,
                                "ramBytes" to memory.totalMem,
                                "freeStorageBytes" to storage.availableBytes,
                            )
                        )
                    }
                    "checkNativeRuntime" -> {
                        try {
                            System.loadLibrary("llama")
                            result.success(true)
                        } catch (_: UnsatisfiedLinkError) {
                            result.success(false)
                        } catch (_: SecurityException) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
