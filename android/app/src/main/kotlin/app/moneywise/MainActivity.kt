package app.moneywise

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Manual-entry version: no notification listener or sensitive-access settings. */
class MainActivity : FlutterActivity() {
    private var voice: VoiceBridge? = null
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (voice?.permission(requestCode, grantResults) != true) super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
    override fun onStop() { voice?.stop(); super.onStop() }
    override fun onDestroy() { voice?.destroy(); super.onDestroy() }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        voice = VoiceBridge(this, MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.moneywise/voice"))
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
