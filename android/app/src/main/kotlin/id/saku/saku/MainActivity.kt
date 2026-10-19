package id.saku.saku

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "id.saku.saku/app_icon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCurrentIcon" -> result.success(currentIcon())
                    "setIcon" -> {
                        val name = call.argument<String>("name") ?: "a"
                        setIcon(name)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun currentIcon(): String {
        val pm = packageManager
        val pkg = packageName
        // Cek alias mana yang aktif; default = "a" (MainActivity).
        for ((name, cls) in listOf("b" to ".IconB", "c" to ".IconC")) {
            val state = pm.getComponentEnabledSetting(ComponentName(pkg, pkg + cls))
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) return name
        }
        return "a"
    }

    private fun setIcon(name: String) {
        val pm = packageManager
        val pkg = packageName
        val main = ComponentName(pkg, "$pkg.MainActivity")
        val aliasB = ComponentName(pkg, "$pkg.IconB")
        val aliasC = ComponentName(pkg, "$pkg.IconC")
        val enabled = PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        val disabled = PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        // Jangan bunuh aplikasi saat ganti komponen.
        val noKill = PackageManager.DONT_KILL_APP
        pm.setComponentEnabledSetting(main, if (name == "a") enabled else disabled, noKill)
        pm.setComponentEnabledSetting(aliasB, if (name == "b") enabled else disabled, noKill)
        pm.setComponentEnabledSetting(aliasC, if (name == "c") enabled else disabled, noKill)
    }
}
