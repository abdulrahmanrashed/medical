import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/backend_models.dart';
import 'api_service.dart';
import 'auth_exceptions.dart';
import 'session_manager.dart';

class BackendApiClient {
  BackendApiClient._();

  static final BackendApiClient instance = BackendApiClient._();

  Dio get _dio => ApiService.instance.client;

  Future<void> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    try {
      final payload = <String, dynamic>{'password': password};
      if (phone != null && phone.trim().isNotEmpty) {
        payload['phone'] = phone.trim();
      } else {
        payload['email'] = email?.trim() ?? '';
      }
      final res = await _dio.post<Map<String, dynamic>>(
        '/Auth/login',
        data: payload,
      );
      final data = res.data ?? <String, dynamic>{};
      SessionManager.instance.setFromAuth(data);
      ApiService.instance.syncAuthorizationHeaderFromSession();
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        final data = e.response?.data;
        final msg = data is Map
            ? data['error']?.toString() ?? ''
            : data?.toString() ?? '';
        final lower = msg.toLowerCase();
        if (lower.contains('frozen')) {
          throw AccountFrozenException(
            msg.isNotEmpty
                ? msg
                : 'Your account is frozen. Please contact your clinic administrator.',
          );
        }
        if (msg.contains('Account Suspended') || msg.contains('Suspended')) {
          throw AccountSuspendedException(
            msg.isNotEmpty
                ? msg
                : 'Account Suspended. Please contact your clinic administrator regarding payment.',
          );
        }
      }
      rethrow;
    }
  }

  /// Anonymous: check phone before signup (prefill DRAFT from reception).
  Future<PatientRegistrationLookupResult> registrationLookupByPhone(String phone) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/Patients/public/registration-lookup',
      data: <String, dynamic>{'phone': phone},
    );
    return PatientRegistrationLookupResult.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Completes signup; same backend row / patient_id for DRAFT or new COMPLETED.
  Future<Map<String, dynamic>> registerPatient({
    required String phone,
    required String password,
    required String fullName,
    String? email,
    DateTime? dateOfBirth,
    bool insuranceStatus = false,
    String? insuranceDetails,
    String? chronicDiseases,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/Auth/register/patient',
      data: <String, dynamic>{
        'phone': phone,
        'password': password,
        'fullName': fullName,
        if (email != null && email.isNotEmpty) 'email': email,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth.toUtc().toIso8601String(),
        'insuranceStatus': insuranceStatus,
        if (insuranceDetails != null && insuranceDetails.isNotEmpty)
          'insuranceDetails': insuranceDetails,
        if (chronicDiseases != null && chronicDiseases.isNotEmpty)
          'chronicDiseases': chronicDiseases,
      },
    );
    final data = res.data ?? <String, dynamic>{};
    SessionManager.instance.setFromAuth(data);
    ApiService.instance.syncAuthorizationHeaderFromSession();
    return data;
  }

  /// Reception/admin: find by phone or create DRAFT (name + phone only).
  Future<Map<String, dynamic>> receptionFindOrCreateDraft({
    required String phone,
    required String fullName,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/Patients/reception/find-or-create-draft',
      data: <String, dynamic>{
        'phone': phone,
        'fullName': fullName,
      },
    );
    return res.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getClinics({String? search}) async {
    final res = await _dio.get<List<dynamic>>(
      '/Clinics',
      queryParameters: (search != null && search.trim().isNotEmpty)
          ? <String, dynamic>{'search': search.trim()}
          : null,
    );
    return _listMap(res.data);
  }

  Future<Map<String, dynamic>> createClinic({
    required String name,
    String? address,
    String? phone,
    String? email,
    required String clinicAdminEmail,
    required String clinicAdminPassword,
    required String clinicAdminFirstName,
    required String clinicAdminLastName,
    double totalAmount = 0,
    double paidAmount = 0,
    DateTime? subscriptionEndDate,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/Clinics',
      data: <String, dynamic>{
        'name': name,
        'address': address,
        'phone': phone,
        'email': email,
        'clinicAdminEmail': clinicAdminEmail,
        'clinicAdminPassword': clinicAdminPassword,
        'clinicAdminFirstName': clinicAdminFirstName,
        'clinicAdminLastName': clinicAdminLastName,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        if (subscriptionEndDate != null)
          'subscriptionEndDate': subscriptionEndDate.toUtc().toIso8601String(),
      },
    );
    return res.data ?? <String, dynamic>{};
  }

  /// Admin: record a subscription payment and extend billing period.
  Future<Map<String, dynamic>> recordClinicPayment({
    required int clinicId,
    required double amountPaid,
    DateTime? paymentDate,
    required DateTime nextExpiryDate,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/Clinics/$clinicId/payment',
      data: <String, dynamic>{
        'amountPaid': amountPaid,
        if (paymentDate != null) 'paymentDate': paymentDate.toUtc().toIso8601String(),
        'nextExpiryDate': nextExpiryDate.toUtc().toIso8601String(),
      },
    );
    return res.data ?? <String, dynamic>{};
  }

  /// Admin: all clinic invoices (billing history).
  Future<List<Map<String, dynamic>>> getAllBillingInvoices() async {
    final res = await _dio.get<List<dynamic>>('/Clinics/invoices/all');
    return _listMap(res.data);
  }

  Future<void> setClinicPaymentStatus(int id, String paymentStatus) async {
    await _dio.patch<void>(
      '/Clinics/$id/payment-status',
      data: <String, dynamic>{'paymentStatus': paymentStatus},
    );
  }

  Future<List<Map<String, dynamic>>> getClinicReceptionists(int clinicId) async {
    final res = await _dio.get<List<dynamic>>('/Clinics/$clinicId/receptionists');
    return _listMap(res.data);
  }

  Future<void> registerReception({
    required int clinicId,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    await _dio.post<void>(
      '/Auth/register/reception',
      data: <String, dynamic>{
        'clinicId': clinicId,
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
      },
    );
  }

  Future<void> deleteClinic(int id) async {
    await _dio.delete<void>('/Clinics/$id');
  }

  /// Registers a doctor for the clinic (ClinicAdmin JWT).
  Future<void> registerDoctor({
    required int clinicId,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String specialization,
    String? licenseNumber,
    String? phoneNumber,
    int yearsOfExperience = 0,
    String? gender,
  }) async {
    await _dio.post<void>(
      '/Auth/register/doctor',
      data: <String, dynamic>{
        'clinicId': clinicId,
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        'specialization': specialization,
        'licenseNumber': licenseNumber,
        'phoneNumber': phoneNumber,
        'yearsOfExperience': yearsOfExperience,
        'gender': gender,
      },
    );
  }

  Future<Map<String, dynamic>> setDoctorActive(int id, {required bool isActive}) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/Doctors/$id/active',
      data: <String, dynamic>{'isActive': isActive},
    );
    return res.data ?? <String, dynamic>{};
  }

  Future<void> deleteDoctor(int id) async {
    await _dio.delete<void>('/Doctors/$id');
  }

  Future<List<Map<String, dynamic>>> getDoctorsByClinic(int clinicId) async {
    final res = await _dio.get<List<dynamic>>('/Doctors/clinic/$clinicId');
    return _listMap(res.data);
  }

  /// Clinic admin: doctor shift / off-day schedules.
  Future<List<Map<String, dynamic>>> getWorkSchedules(
    int clinicId, {
    int? doctorId,
    String? from,
    String? to,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/Clinics/$clinicId/work-schedules',
      queryParameters: <String, dynamic>{
        if (doctorId != null) 'doctorId': doctorId,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      },
    );
    return _listMap(res.data);
  }

  Future<List<Map<String, dynamic>>> bulkWorkSchedules(int clinicId, Map<String, dynamic> body) async {
    final res = await _dio.post<List<dynamic>>(
      '/Clinics/$clinicId/work-schedules/bulk',
      data: body,
    );
    return _listMap(res.data);
  }

  Future<Map<String, dynamic>> updateWorkSchedule(int id, Map<String, dynamic> body) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/DoctorWorkSchedules/$id',
      data: body,
    );
    return res.data ?? <String, dynamic>{};
  }

  Future<void> deleteWorkSchedule(int id) async {
    await _dio.delete<void>('/DoctorWorkSchedules/$id');
  }

  Future<Map<String, dynamic>> getDoctorMe() async {
    ApiService.instance.syncAuthorizationHeaderFromSession();
    final res = await _dio.get<Map<String, dynamic>>('/Doctors/me');
    return res.data ?? <String, dynamic>{};
  }

  /// Paginated appointments (default page size 10 on the server).
  Future<PagedAppointments> getAppointmentsPage({
    int? doctorId,
    int pageNumber = 1,
    int pageSize = 10,
    DateTime? scheduledFromUtc,
    DateTime? scheduledToUtc,
  }) async {
    ApiService.instance.syncAuthorizationHeaderFromSession();
    final qp = <String, dynamic>{
      'pageNumber': pageNumber,
      'pageSize': pageSize,
    };
    if (doctorId != null) qp['doctorId'] = doctorId;
    if (scheduledFromUtc != null) {
      qp['scheduledFromUtc'] = scheduledFromUtc.toUtc().toIso8601String();
    }
    if (scheduledToUtc != null) {
      qp['scheduledToUtc'] = scheduledToUtc.toUtc().toIso8601String();
    }
    final res = await _dio.get<Map<String, dynamic>>(
      '/Appointments',
      queryParameters: qp,
    );
    return PagedAppointments.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Loads all pages into a single list (use sparingly; prefer [getAppointmentsPage] + infinite scroll).
  Future<List<ApiAppointment>> getAllAppointmentsAccumulated({
    int? doctorId,
    int pageSize = 50,
    DateTime? scheduledFromUtc,
    DateTime? scheduledToUtc,
  }) async {
    final out = <ApiAppointment>[];
    var page = 1;
    while (true) {
      final p = await getAppointmentsPage(
        doctorId: doctorId,
        pageNumber: page,
        pageSize: pageSize,
        scheduledFromUtc: scheduledFromUtc,
        scheduledToUtc: scheduledToUtc,
      );
      out.addAll(p.items);
      if (p.items.length < pageSize || out.length >= p.totalCount) break;
      page++;
    }
    out.sort((a, b) => a.scheduledAtUtc.compareTo(b.scheduledAtUtc));
    return out;
  }

  /// Patient JWT: own profile; [ApiPatient.id] is the same clinical UUID as `patient_id` in the token.
  Future<ApiPatient> getPatientMe() async {
    final res = await _dio.get<Map<String, dynamic>>('/Patients/me');
    return ApiPatient.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Doctor/reception/admin: clinical profile by stable patient UUID.
  Future<ApiPatient> getPatientById(String patientId) async {
    ApiService.instance.syncAuthorizationHeaderFromSession();
    final res = await _dio.get<Map<String, dynamic>>('/Patients/$patientId');
    return ApiPatient.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Reception/admin: resolve patient by phone without creating a row. Returns null if 404.
  Future<ApiPatient?> lookupPatientByPhoneForReception(String phone) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/Patients/reception/by-phone',
        queryParameters: <String, dynamic>{'phone': phone},
      );
      final data = res.data;
      if (data == null) return null;
      return ApiPatient.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<ApiAppointment> createAppointment({
    required String patientId,
    required int clinicId,
    int? doctorId,
    required String patientName,
    required String phoneNumber,
    required DateTime scheduledAtUtc,
    required int type,
    String? notes,
    String? doctorNotes,
    String? receptionNotes,
  }) async {
    final body = <String, dynamic>{
      'patientId': patientId,
      'clinicId': clinicId,
      'patientName': patientName,
      'phoneNumber': phoneNumber,
      // RFC 3339 / ISO 8601 UTC (ends with Z) so the API stores an unambiguous instant.
      'scheduledAtUtc': scheduledAtUtc.toUtc().toIso8601String(),
      'type': type,
    };
    if (doctorId != null) body['doctorId'] = doctorId;
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;
    if (doctorNotes != null && doctorNotes.isNotEmpty) body['doctorNotes'] = doctorNotes;
    if (receptionNotes != null && receptionNotes.isNotEmpty) {
      body['receptionNotes'] = receptionNotes;
    }

    final res = await _dio.post<Map<String, dynamic>>(
      '/Appointments',
      data: body,
    );
    return ApiAppointment.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Reception/admin: full update per [UpdateAppointmentDto].
  Future<ApiAppointment> updateAppointment({
    required int id,
    required String patientName,
    required String phoneNumber,
    required DateTime scheduledAtUtc,
    required int type,
    required int status,
    int? doctorId,
    String? notes,
    String? doctorNotes,
    String? receptionNotes,
  }) async {
    final body = <String, dynamic>{
      'patientName': patientName,
      'phoneNumber': phoneNumber,
      'scheduledAtUtc': scheduledAtUtc.toUtc().toIso8601String(),
      'type': type,
      'status': status,
      'notes': notes,
      'doctorNotes': doctorNotes,
      'receptionNotes': receptionNotes,
    };
    if (doctorId != null) body['doctorId'] = doctorId;

    final res = await _dio.put<Map<String, dynamic>>(
      '/Appointments/$id',
      data: body,
    );
    return ApiAppointment.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Reception/admin: hard delete (optional alternative to [updateAppointment] with cancelled status).
  Future<void> deleteAppointment(int id) async {
    await _dio.delete<void>('/Appointments/$id');
  }

  /// Doctor JWT: start session (`InProgress`) or end session (`Completed`). Backend validates transitions.
  Future<ApiAppointment> patchDoctorAppointmentStatus({
    required int appointmentId,
    required ApiAppointmentStatus status,
  }) async {
    ApiService.instance.syncAuthorizationHeaderFromSession();
    final statusStr = switch (status) {
      ApiAppointmentStatus.inProgress => 'InProgress',
      ApiAppointmentStatus.completed => 'Completed',
      _ => throw ArgumentError('Doctor status patch only supports InProgress or Completed'),
    };
    final res = await _dio.patch<Map<String, dynamic>>(
      '/Appointments/$appointmentId/doctor-status',
      data: <String, dynamic>{'status': statusStr},
    );
    return ApiAppointment.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Doctor JWT: update session notes and/or type-specific JSON (`PATCH /Appointments/{id}/doctor-session`).
  Future<ApiAppointment> patchDoctorAppointmentSession({
    required int appointmentId,
    String? doctorNotes,
    String? specializedDataJson,
    String? requestedTests,
  }) async {
    ApiService.instance.syncAuthorizationHeaderFromSession();
    final body = <String, dynamic>{};
    if (doctorNotes != null) body['doctorNotes'] = doctorNotes;
    if (specializedDataJson != null) body['specializedDataJson'] = specializedDataJson;
    if (requestedTests != null) body['requestedTests'] = requestedTests;
    final res = await _dio.patch<Map<String, dynamic>>(
      '/Appointments/$appointmentId/doctor-session',
      data: body,
    );
    return ApiAppointment.fromJson(res.data ?? <String, dynamic>{});
  }

  Future<List<Map<String, dynamic>>> getMedicalRecords() async {
    ApiService.instance.syncAuthorizationHeaderFromSession();
    final res = await _dio.get<List<dynamic>>('/MedicalRecords');
    return _listMap(res.data);
  }

  /// Single appointment with prescriptions and requested tests (`GET /Appointments/{id}`).
  Future<ApiAppointment> getAppointmentById(int id) async {
    ApiService.instance.syncAuthorizationHeaderFromSession();
    final res = await _dio.get<Map<String, dynamic>>('/Appointments/$id');
    return ApiAppointment.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Patient: aggregated diagnosis, prescriptions, documents (`GET /Patients/me/medical-history`).
  Future<PatientMedicalHistory> getPatientMedicalHistory() async {
    final res = await _dio.get<Map<String, dynamic>>('/Patients/me/medical-history');
    return PatientMedicalHistory.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Patient: multipart upload; optional [appointmentId] links file to a visit for the doctor.
  Future<ApiMedicalFile> uploadPatientMedicalFile({
    int? appointmentId,
    required String filePath,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final res = await _dio.post<Map<String, dynamic>>(
      '/MedicalFiles',
      data: formData,
      queryParameters: appointmentId != null
          ? <String, dynamic>{'appointmentId': appointmentId}
          : null,
    );
    return ApiMedicalFile.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Doctor/staff: patient uploads for this appointment.
  Future<List<ApiMedicalFile>> getAppointmentPatientUploads(int appointmentId) async {
    ApiService.instance.syncAuthorizationHeaderFromSession();
    final res = await _dio.get<List<dynamic>>(
      '/Appointments/$appointmentId/patient-uploads',
    );
    final raw = res.data ?? const <dynamic>[];
    return raw
        .whereType<Map>()
        .map((e) => ApiMedicalFile.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  /// Doctor: replace appointment-level prescription lines (patient reminder schedule).
  Future<ApiAppointment> replaceAppointmentPrescriptions({
    required int appointmentId,
    required List<Map<String, dynamic>> lines,
  }) async {
    ApiService.instance.syncAuthorizationHeaderFromSession();
    final res = await _dio.put<Map<String, dynamic>>(
      '/Appointments/$appointmentId/prescriptions',
      data: <String, dynamic>{'lines': lines},
    );
    return ApiAppointment.fromJson(res.data ?? <String, dynamic>{});
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final res = await _dio.get<List<dynamic>>('/Notifications/me');
    return _listMap(res.data);
  }

  Future<ApiMedicalRecordDetail> getMedicalRecord(int id) async {
    final res = await _dio.get<Map<String, dynamic>>('/MedicalRecords/$id');
    return ApiMedicalRecordDetail.fromJson(res.data ?? <String, dynamic>{});
  }

  Future<ApiMedicalRecordDetail> createMedicalRecord({
    required String patientId,
    required int clinicId,
    required int doctorId,
    String? symptoms,
    String? diagnosis,
    String? notes,
    List<Map<String, dynamic>>? initialMedications,
  }) async {
    ApiService.instance.syncAuthorizationHeaderFromSession();
    final body = _buildCreateMedicalRecordJson(
      patientId: patientId,
      clinicId: clinicId,
      doctorId: doctorId,
      symptoms: symptoms,
      diagnosis: diagnosis,
      notes: notes,
      initialMedications: initialMedications,
    );
    // ignore: avoid_print
    print('POST /MedicalRecords body: ${jsonEncode(body)}');
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/MedicalRecords',
        data: body,
      );
      return ApiMedicalRecordDetail.fromJson(res.data ?? <String, dynamic>{});
    } on DioException catch (e) {
      _throwMedicalRecordDio(e, 'POST /MedicalRecords');
    }
  }

  Future<ApiMedicalRecordDetail> updateMedicalRecord({
    required int id,
    String? symptoms,
    String? diagnosis,
    String? notes,
  }) async {
    if (id <= 0) {
      throw FormatException('updateMedicalRecord: medical record id must be > 0, got $id');
    }
    final body = <String, dynamic>{
      'symptoms': symptoms,
      'diagnosis': diagnosis,
      'notes': notes,
    };
    // ignore: avoid_print
    print('PUT /MedicalRecords/$id body: ${jsonEncode(body)}');
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/MedicalRecords/$id',
        data: body,
      );
      return ApiMedicalRecordDetail.fromJson(res.data ?? <String, dynamic>{});
    } on DioException catch (e) {
      _throwMedicalRecordDio(e, 'PUT /MedicalRecords/$id');
    }
  }

  Future<ApiMedicalRecordDetail> addMedication({
    required int prescriptionId,
    required String name,
    required String dosage,
    required String schedule,
    String? instructions,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/MedicalRecords/medications',
      data: <String, dynamic>{
        'prescriptionId': prescriptionId,
        'name': name,
        'dosage': dosage,
        'schedule': schedule,
        'instructions': instructions,
      },
    );
    return ApiMedicalRecordDetail.fromJson(res.data ?? <String, dynamic>{});
  }

  Future<ApiMedicalRecordDetail> removeMedication(int medicationId) async {
    final res = await _dio.delete<Map<String, dynamic>>(
      '/MedicalRecords/medications/$medicationId',
    );
    return ApiMedicalRecordDetail.fromJson(res.data ?? <String, dynamic>{});
  }

  Future<ApiMedicalRecordDetail> uploadMedicalRecordAttachment({
    required int medicalRecordId,
    required String filePath,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final res = await _dio.post<Map<String, dynamic>>(
      '/MedicalRecords/$medicalRecordId/attachments',
      data: formData,
    );
    return ApiMedicalRecordDetail.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Builds a browser-openable URL for an attachment (uses API [publicUrl] when present).
  String attachmentUrl(ApiFileAttachment a) {
    if (a.publicUrl != null && a.publicUrl!.isNotEmpty) {
      return a.publicUrl!;
    }
    final path = a.filePath.replaceFirst(RegExp(r'^/+'), '');
    return '${ApiService.instance.publicOrigin}/$path';
  }

  String medicalFileUrl(ApiMedicalFile f) {
    if (f.publicUrl != null && f.publicUrl!.isNotEmpty) {
      return f.publicUrl!;
    }
    final path = f.fileUrl.replaceFirst(RegExp(r'^/+'), '');
    return '${ApiService.instance.publicOrigin}/$path';
  }

  List<Map<String, dynamic>> _listMap(List<dynamic>? raw) {
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }
}

/// Builds JSON for `CreateMedicalRecordDto` (camelCase: `patientId`, `clinicId`, optional `doctorId`).
/// Required: non-empty patientId (Guid), clinicId > 0; doctorId must match JWT when sent.
final RegExp _medicalRecordPatientUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

String _normalizeCreateMedicalRecordPatientId(String raw) {
  final s = raw.trim().toLowerCase();
  if (!_medicalRecordPatientUuidPattern.hasMatch(s)) {
    throw FormatException(
      'patientId must be a UUID string (JSON field name: patientId). Got: "$raw"',
    );
  }
  return s;
}

/// Builds the exact map sent as JSON for POST /MedicalRecords.
Map<String, dynamic> _buildCreateMedicalRecordJson({
  required String patientId,
  required int clinicId,
  required int doctorId,
  String? symptoms,
  String? diagnosis,
  String? notes,
  List<Map<String, dynamic>>? initialMedications,
}) {
  if (patientId.trim().isEmpty) {
    throw FormatException('patientId must not be null or empty before POST /MedicalRecords.');
  }
  if (clinicId <= 0) {
    throw FormatException(
      'clinicId must be a positive int (not a string) for POST /MedicalRecords. Got: $clinicId',
    );
  }
  if (doctorId <= 0) {
    throw FormatException(
      'doctorId must be a positive int for POST /MedicalRecords. Got: $doctorId',
    );
  }
  final map = <String, dynamic>{
    'patientId': _normalizeCreateMedicalRecordPatientId(patientId),
    'clinicId': clinicId,
    'doctorId': doctorId,
  };
  if (symptoms != null) map['symptoms'] = symptoms;
  if (diagnosis != null) map['diagnosis'] = diagnosis;
  if (notes != null) map['notes'] = notes;
  if (initialMedications != null && initialMedications.isNotEmpty) {
    map['initialMedications'] = initialMedications;
  }
  return map;
}

Never _throwMedicalRecordDio(DioException e, String op) {
  final buf = StringBuffer('$op failed');
  if (e.response?.statusCode != null) {
    buf.write(' (${e.response!.statusCode})');
  }
  final detail = _dioErrorDetail(e);
  if (detail != null) {
    buf.write(': $detail');
  } else if (e.message != null) {
    buf.write(': ${e.message}');
  }
  throw Exception(buf.toString());
}

String? _dioErrorDetail(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final err = data['error'];
    if (err != null) return err.toString();
    final title = data['title'];
    if (title != null) return title.toString();
    final errs = data['errors'];
    if (errs is Map) return errs.toString();
  }
  if (data is String && data.isNotEmpty) return data;
  return null;
}
