# Kultivar — branding assets

This folder holds the source artwork for the app icon. The
`flutter_launcher_icons` config in `pubspec.yaml` reads from here and
fans the assets out to every platform's launcher icon slot when you
run:

```sh
dart run flutter_launcher_icons
```

## Required files

Drop these two PNGs into this folder before running the generator.

### `icon_source.png` — the master icon

- **Size:** 1024 × 1024 px
- **Format:** PNG, **fully opaque** (no alpha channel)
- **Used by:** iOS, macOS, Windows, web (favicon + PWA icons)
- **Design notes:**
  - Fills the full square; the OS/launcher applies its own corner
    rounding on iOS and macOS.
  - Keep important content out of the extreme outer 5 % of the square
    — iOS clips with a generous corner radius.
  - Apple rejects App Store uploads whose 1024 px marketing icon
    has transparency, which is why `remove_alpha_ios: true` is set in
    `pubspec.yaml`. Supplying an opaque PNG to start avoids the
    re-encoding step entirely.

### `icon_foreground.png` — the Android adaptive foreground

- **Size:** 1024 × 1024 px
- **Format:** PNG, **transparent background**
- **Used by:** Android (Oreo+ adaptive icon, 13+ themed monochrome icon)
- **Design notes:**
  - Place the logo inside the centre 66 % "safe zone" — Android
    launchers crop the foreground to a circle / squircle / rounded
    square depending on the device, and anything outside that zone
    gets clipped.
  - The Material You themed-icon surface (Android 13+) extracts alpha
    from this same file and recolours it to match the wallpaper, so
    keep silhouettes legible even when flat-tinted.
  - The flat background colour is `#0A0A0F` (matches
    `AppColors.bg`) — change `adaptive_icon_background` in
    `pubspec.yaml` if you want a different fill.

## Quick start

```sh
# 1. Drop icon_source.png + icon_foreground.png into this folder.
# 2. Regenerate every platform's icon.
dart run flutter_launcher_icons

# 3. Rebuild the app — installers pick up the new icon.
flutter clean
flutter build apk     # or appbundle / ipa / web / macos / windows
```

The generated files land in:

- `android/app/src/main/res/mipmap-*/`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/`
- `web/favicon.png` + `web/icons/Icon-*.png` + manifest tweaks
- `windows/runner/resources/app_icon.ico`

Those generated paths are checked in so CI builds don't need to
re-run the generator — only run it locally when the source artwork
changes.
