import 'package:shared_preferences/shared_preferences.dart';
import '../utils/insight_engine.dart';

class InsightNotificationBridge {
  static const _ackKey = 'acknowledged_insights';

  static Future<void> markAsSeen(Insight insight) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_ackKey)?.toSet() ?? {};

    seen.add(insight.message);

    await prefs.setStringList(_ackKey, seen.toList());
  }

  static Future<Set<String>> loadSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_ackKey)?.toSet() ?? {};
  }
}
