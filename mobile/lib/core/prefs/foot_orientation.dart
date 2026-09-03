import 'package:shared_preferences/shared_preferences.dart';

const _strongFootIsRightKey = 'fc_strong_foot_is_right';

/// Which physical side (left/right) the user's strong foot is on — a local
/// display preference only: it controls which side of [FootToggle]
/// (widgets/foot_toggle.dart) shows WF vs SF, so the control matches how the
/// user actually thinks of their own body. Doesn't touch the underlying
/// `strongFoot` data model at all — that stays a plain "is this the
/// strong-foot slot" bool everywhere else in the app and on the server.
class FootOrientation {
  FootOrientation._();

  static SharedPreferences? _prefs;
  static bool _strongFootIsRight = true; // default matches the original fixed WF-left/SF-right layout

  static bool get strongFootIsRight => _strongFootIsRight;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _strongFootIsRight = prefs.getBool(_strongFootIsRightKey) ?? true;
  }

  static Future<void> setStrongFootIsRight(bool isRight) async {
    _strongFootIsRight = isRight;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_strongFootIsRightKey, isRight);
  }
}
