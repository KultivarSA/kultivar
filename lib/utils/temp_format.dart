import '../main.dart';

/// Formats a Celsius value according to the app's temperature-unit preference.
///
/// [decimals] controls how many decimal places to show (default 1).
String formatTemp(double celsius, {int decimals = 1}) {
  if (KultivarApp.useFahrenheitNotifier.value) {
    final f = celsius * 9 / 5 + 32;
    return '${f.toStringAsFixed(decimals)}°F';
  }
  return '${celsius.toStringAsFixed(decimals)}°C';
}

/// Unit label for use in input field hints, e.g. "Temperature (°C)".
String get tempUnitLabel =>
    KultivarApp.useFahrenheitNotifier.value
        ? 'Temperature (°F)'
        : 'Temperature (°C)';

/// Short unit suffix, e.g. "°C" or "°F".
String get tempUnitSuffix =>
    KultivarApp.useFahrenheitNotifier.value ? '°F' : '°C';

/// Converts a user-entered temperature (in the current display unit) back to
/// Celsius for storage. Always call this before persisting a typed value.
///
/// If the app is in Celsius mode the value is returned unchanged.
double toStorageTemp(double displayValue) {
  if (KultivarApp.useFahrenheitNotifier.value) {
    return (displayValue - 32) * 5 / 9;
  }
  return displayValue;
}

/// Converts a stored Celsius temperature to the current display unit for
/// pre-filling text input fields.  Inverse of [toStorageTemp].
double fromStorageTemp(double celsius) {
  if (KultivarApp.useFahrenheitNotifier.value) {
    return celsius * 9 / 5 + 32;
  }
  return celsius;
}
