package com.example.shala_saathi

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "startLockTask" -> {
                            startLockTask()
                            result.success(true)
                        }
                        "stopLockTask" -> {
                            stopLockTask()
                            result.success(true)
                        }
                        "isLocked" -> result.success(isInLockTaskMode())
                        "prefGet" -> result.success(prefs().getString(call.argument<String>("key"), null))
                        "prefSet" -> {
                            prefs().edit()
                                .putString(call.argument<String>("key"), call.argument<String>("value"))
                                .apply()
                            result.success(null)
                        }
                        "prefDelete" -> {
                            prefs().edit().remove(call.argument<String>("key")).apply()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: IllegalStateException) {
                    result.error("LOCK_TASK_STATE", e.message, null)
                } catch (e: SecurityException) {
                    result.error("LOCK_TASK_DENIED", e.message, null)
                }
            }
    }

    private fun prefs() = getSharedPreferences("study_lock_prefs", Context.MODE_PRIVATE)

    private fun isInLockTaskMode(): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            manager.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
        } else {
            @Suppress("DEPRECATION")
            manager.isInLockTaskMode
        }
    }

    companion object {
        const val CHANNEL = "com.example.shala_saathi/lock_task"
    }
}
