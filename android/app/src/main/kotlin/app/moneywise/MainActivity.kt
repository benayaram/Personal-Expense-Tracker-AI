package app.moneywise

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Manual-entry version: no notification listener or sensitive-access settings. */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        // Retain only deletion of legacy local capture data when resetting the app.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.moneywise/capture").setMethodCallHandler { call, result ->
            if (call.method == "clear") {
                if (getSharedPreferences("capture", MODE_PRIVATE).edit().clear().commit()) result.success(null)
                else result.error("STORAGE_ERROR", "Could not clear legacy local data", null)
            } else result.notImplemented()
        }
    }
}
