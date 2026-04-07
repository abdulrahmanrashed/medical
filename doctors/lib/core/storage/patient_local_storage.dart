import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the stable clinical [patientId] (UUID) after login/registration for local reference.
/// Uses [SharedPreferences] (fast) and [FlutterSecureStorage] (tamper-resistant on supported platforms).
class PatientLocalStorage {
  PatientLocalStorage._();

  static final PatientLocalStorage instance = PatientLocalStorage._();

  static const _prefsKey = 'stable_patient_id_v1';
  static const _secureKey = 'stable_patient_id_v1';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<void> savePatientId(String patientId) async {
    if (patientId.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_prefsKey, patientId);
    await _secure.write(key: _secureKey, value: patientId);
  }

  /// If the session has no patient id yet (e.g. restored token elsewhere), backfill from disk.
  Future<String?> readPatientId() async {
    final sp = await SharedPreferences.getInstance();
    final fromPrefs = sp.getString(_prefsKey);
    if (fromPrefs != null && fromPrefs.isNotEmpty) return fromPrefs;
    return _secure.read(key: _secureKey);
  }

  Future<void> clearPatientId() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_prefsKey);
    await _secure.delete(key: _secureKey);
  }
}
