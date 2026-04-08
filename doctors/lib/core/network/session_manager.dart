import '../enums/doctor_specialization.dart';
import '../enums/user_role.dart';
import '../models/doctor_summary.dart';
import '../storage/patient_local_storage.dart';

class SessionManager {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  String? token;
  String? email;
  String? userId;
  int? doctorId;

  /// From login payload and/or [applyDoctorMe]. Used by the doctor dashboard and session flows.
  DoctorSpecialization? doctorSpecialization;
  /// Stable patient UUID from the API (`patient_id` claim).
  String? patientId;
  int? assignedClinicId;
  List<String> roles = const [];

  UserRole? get primaryRole {
    if (roles.any((r) => r.toLowerCase() == 'admin')) return UserRole.admin;
    if (roles.any((r) => r.toLowerCase() == 'clinicadmin')) {
      return UserRole.clinicManagement;
    }
    if (roles.any((r) => r.toLowerCase() == 'doctor')) return UserRole.doctor;
    if (roles.any((r) => r.toLowerCase() == 'reception')) {
      return UserRole.receptionist;
    }
    if (roles.any((r) => r.toLowerCase() == 'patient')) return UserRole.patient;
    return null;
  }

  bool hasRole(UserRole role) {
    return switch (role) {
      UserRole.admin => roles.any((r) => r.toLowerCase() == 'admin'),
      UserRole.clinicManagement =>
        roles.any((r) => r.toLowerCase() == 'clinicadmin'),
      UserRole.doctor => roles.any((r) => r.toLowerCase() == 'doctor'),
      UserRole.receptionist => roles.any((r) => r.toLowerCase() == 'reception'),
      UserRole.patient => roles.any((r) => r.toLowerCase() == 'patient'),
    };
  }

  void setFromAuth(Map<String, dynamic> json) {
    token = json['token'] as String?;
    email = json['email'] as String?;
    userId = json['userId'] as String?;
    doctorId = _parseOptionalInt(json['doctorId']);
    patientId = _parseGuid(json['patientId']);
    if (patientId != null && patientId!.isNotEmpty) {
      Future<void>.microtask(
        () => PatientLocalStorage.instance.savePatientId(patientId!),
      );
    }
    assignedClinicId = _parseOptionalInt(json['assignedClinicId']);
    final rawRoles = json['roles'] as List<dynamic>? ?? const [];
    roles = rawRoles.map((e) => e.toString()).toList();
    final specRaw = json['specialization']?.toString();
    if (specRaw != null && specRaw.trim().isNotEmpty) {
      doctorSpecialization = DoctorSummary.specializationFromApi(specRaw);
    }
  }

  /// Updates [doctorId] and [doctorSpecialization] from `GET /Doctors/me` (or equivalent map).
  void applyDoctorMe(Map<String, dynamic> me) {
    final id = _parseOptionalInt(me['id']);
    if (id != null) doctorId = id;
    final raw = me['specialization']?.toString();
    if (raw != null && raw.trim().isNotEmpty) {
      doctorSpecialization = DoctorSummary.specializationFromApi(raw);
    }
  }

  void clear() {
    token = null;
    email = null;
    userId = null;
    doctorId = null;
    doctorSpecialization = null;
    patientId = null;
    assignedClinicId = null;
    roles = const [];
    Future<void>.microtask(() => PatientLocalStorage.instance.clearPatientId());
  }

  /// Restores [patientId] from secure/prefs when JWT is not in memory (e.g. after process restart).
  Future<void> restorePatientIdFromDisk() async {
    if (patientId != null && patientId!.isNotEmpty) return;
    final id = await PatientLocalStorage.instance.readPatientId();
    if (id != null && id.isNotEmpty) patientId = id;
  }

  static String? _parseGuid(dynamic v) {
    if (v == null) return null;
    if (v is String && v.isNotEmpty) return v;
    return v.toString();
  }

  static int? _parseOptionalInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }
}
