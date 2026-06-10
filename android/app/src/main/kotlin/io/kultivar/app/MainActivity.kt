package io.kultivar.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Bug #168 — extend FlutterFragmentActivity (not the default
// FlutterActivity) because Android's BiometricPrompt API requires the
// host activity to be a FragmentActivity.  The local_auth Flutter
// plugin wraps BiometricPrompt under the hood, so authenticate() calls
// against a plain FlutterActivity throw IllegalStateException internally
// and report "auth failed" to Dart with no further detail.
//
// Several other plugins (image_picker on newer Androids, in_app_purchase
// in some scenarios) also expect a FragmentActivity host, so this is the
// recommended baseline for production Flutter apps anyway.  The
// upstream Flutter docs flag this exact requirement at
// https://pub.dev/packages/local_auth#android-integration.
class MainActivity : FlutterFragmentActivity() {

    // Task #178 — tiny channel for the two Android settings screens the
    // notification-reliability UX needs to deep-link into.  A dedicated
    // plugin (app_settings / android_intent_plus) would be overkill for
    // two intents; this keeps the dependency surface flat.
    private val channelName = "io.kultivar.app/system_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // Opens the per-app notification settings page so a user
                // who previously denied POST_NOTIFICATIONS can re-enable
                // without spelunking through Android Settings manually.
                // ACTION_APP_NOTIFICATION_SETTINGS + EXTRA_APP_PACKAGE is
                // API 26+; older devices get the app-details page, which
                // has the same toggle one tap deeper.
                "openNotificationSettings" -> {
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        }
                    } else {
                        Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.fromParts("package", packageName, null)
                        )
                    }
                    startActivity(intent)
                    result.success(true)
                }
                // Opens the system battery-optimization list.  Samsung
                // One UI (and other OEM skins) aggressively kill
                // background-scheduled notifications; exempting the app
                // here is the documented fix.  We open the LIST screen
                // rather than the direct REQUEST_IGNORE_... action
                // because the direct action requires an extra manifest
                // permission that triggers Play review scrutiny.
                "openBatteryOptimizationSettings" -> {
                    val intent =
                        Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                // True when the app is already exempt from battery
                // optimization (user previously flipped the toggle).
                // Lets the Settings tile show a "done" state.
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(POWER_SERVICE)
                            as android.os.PowerManager
                    result.success(
                        pm.isIgnoringBatteryOptimizations(packageName)
                    )
                }
                else -> result.notImplemented()
            }
        }
    }
}
