package app.moneywise

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.moneywise/capture").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "pending" -> result.success(CaptureQueue.pending(this))
                    "ack" -> { CaptureQueue.ack(this, requireNotNull(call.argument<String>("id"))); result.success(null) }
                    "clear" -> { CaptureQueue.clear(this); result.success(null) }
                    "enabled" -> {
                        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners").orEmpty()
                            .split(":").mapNotNull { ComponentName.unflattenFromString(it) }.any { it.packageName == packageName }
                        result.success(enabled)
                    }
                    "settings" -> {
                        CaptureQueue.resume(this)
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)); result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.error("CAPTURE_ERROR", "Notification capture is unavailable", null) }
        }
    }
}
