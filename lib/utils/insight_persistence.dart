import 'package:shared_preferences/shared_preferences.dart';

class InsightPersistence {
  static const _key = 'acknowledged_insights';

  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key)?.toSet() ?? {};
  }

  static Future<void> save(Set<String> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, values.toList());
  }
}
