import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  static const String nameKey = 'user_name';
  static const String phoneKey = 'user_phone';

  static Future<void> saveProfile({
    required String name,
    required String phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(nameKey, name);
    await prefs.setString(phoneKey, phone);
  }

  static Future<Map<String, String>> getProfile() async {
    final prefs = await SharedPreferences.getInstance();

    final name = prefs.getString(nameKey) ?? '';
    final phone = prefs.getString(phoneKey) ?? '';

    return {
      'name': name,
      'phone': phone,
    };
  }

  static Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(nameKey);
    await prefs.remove(phoneKey);
  }
}