package io.kultivar.app

import io.flutter.embedding.android.FlutterFragmentActivity

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
class MainActivity : FlutterFragmentActivity()
