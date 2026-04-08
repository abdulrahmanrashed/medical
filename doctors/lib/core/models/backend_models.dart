enum ApiAppointmentType {
  general(0),
  specificDoctor(1);

  const ApiAppointmentType(this.value);
  final int value;
}

/// API may send int or string (`JsonStringEnumConverter` on the server).
ApiAppointmentType _parseAppointmentType(dynamic raw) {
  if (raw == null) return ApiAppointmentType.general;
  if (raw is int) {
    return ApiAppointmentType.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => ApiAppointmentType.general,
    );
  }
  final s = raw.toString().toLowerCase().trim();
  if (s == '0' || s == 'general') return ApiAppointmentType.general;
  if (s == '1' || s == 'specificdoctor') return ApiAppointmentType.specificDoctor;
  return ApiAppointmentType.general;
}

enum ApiAppointmentStatus {
  pending(0),
  approved(1),
  rescheduled(2),
  cancelled(3),
  completed(4),
  inProgress(5);

  const ApiAppointmentStatus(this.value);
  final int value;
}

ApiAppointmentStatus _parseAppointmentStatus(dynamic raw) {
  if (raw == null) return ApiAppointmentStatus.pending;
  if (raw is int) {
    return ApiAppointmentStatus.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => ApiAppointmentStatus.pending,
    );
  }
  final s = raw.toString().toLowerCase().trim();
  if (s == '0' || s == 'pending') return ApiAppointmentStatus.pending;
  if (s == '1' || s == 'approved') return ApiAppointmentStatus.approved;
  if (s == '2' || s == 'rescheduled') return ApiAppointmentStatus.rescheduled;
  if (s == '3' || s == 'cancelled') return ApiAppointmentStatus.cancelled;
  if (s == '4' || s == 'completed') return ApiAppointmentStatus.completed;
  if (s == '5' || s == 'inprogress') return ApiAppointmentStatus.inProgress;
  return ApiAppointmentStatus.pending;
}

enum ApiNotificationType {
  appointmentUpdate(0),
  medicationReminder(1),
  bookingConfirmation(2),
  general(3);

  const ApiNotificationType(this.value);
  final int value;
}

class ApiClinic {
  const ApiClinic({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.email,
  });

  final int id;
  final String name;
  final String? address;
  final String? phone;
  final String? email;

  factory ApiClinic.fromJson(Map<String, dynamic> json) => ApiClinic(
        id: _parseInt(json['id']),
        name: json['name'] as String? ?? '',
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
      );
}

class ApiDoctor {
  const ApiDoctor({
    required this.id,
    required this.userId,
    required this.clinicId,
    required this.specialization,
    this.licenseNumber,
  });

  final int id;
  final String userId;
  final int clinicId;
  final String specialization;
  final String? licenseNumber;

  factory ApiDoctor.fromJson(Map<String, dynamic> json) => ApiDoctor(
        id: _parseInt(json['id']),
        userId: json['userId'] as String? ?? '',
        clinicId: _parseInt(json['clinicId']),
        specialization: json['specialization'] as String? ?? '',
        licenseNumber: json['licenseNumber'] as String?,
      );
}

/// Backend `PatientRegistrationStatus`: draft | completed (case-insensitive).
enum ApiPatientRegistrationStatus {
  draft,
  completed,
  unknown;

  static ApiPatientRegistrationStatus parse(dynamic raw) {
    if (raw == null) return ApiPatientRegistrationStatus.unknown;
    final s = raw.toString().toLowerCase();
    if (s == 'draft') return ApiPatientRegistrationStatus.draft;
    if (s == 'completed') return ApiPatientRegistrationStatus.completed;
    return ApiPatientRegistrationStatus.unknown;
  }
}

/// Response from `POST /Patients/public/registration-lookup`.
class PatientRegistrationLookupResult {
  const PatientRegistrationLookupResult({
    required this.found,
    required this.registrationStatus,
    this.patientId,
    this.fullName,
    this.phoneNumber,
    this.email,
    this.dateOfBirth,
    this.insuranceStatus = false,
    this.insuranceDetails,
    this.chronicDiseases,
  });

  final bool found;
  final ApiPatientRegistrationStatus registrationStatus;
  final String? patientId;
  final String? fullName;
  final String? phoneNumber;
  final String? email;
  final DateTime? dateOfBirth;
  final bool insuranceStatus;
  final String? insuranceDetails;
  final String? chronicDiseases;

  factory PatientRegistrationLookupResult.fromJson(Map<String, dynamic> json) {
    final status = ApiPatientRegistrationStatus.parse(json['registrationStatus']);
    return PatientRegistrationLookupResult(
      found: json['found'] as bool? ?? false,
      registrationStatus: status,
      patientId: _parseGuid(json['patientId']),
      fullName: json['fullName'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      email: json['email'] as String?,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'].toString())
          : null,
      insuranceStatus: json['insuranceStatus'] as bool? ?? false,
      insuranceDetails: json['insuranceDetails'] as String?,
      chronicDiseases: json['chronicDiseases'] as String?,
    );
  }
}

class ApiPatient {
  const ApiPatient({
    required this.id,
    this.userId,
    required this.fullName,
    required this.phoneNumber,
    this.email,
    this.dateOfBirth,
    this.insuranceStatus = false,
    this.insuranceDetails,
    this.chronicDiseases,
    this.registrationStatus,
  });

  final String id;
  final String? userId;
  final String fullName;
  final String phoneNumber;
  final String? email;
  final DateTime? dateOfBirth;
  final bool insuranceStatus;
  final String? insuranceDetails;
  final String? chronicDiseases;
  final String? registrationStatus;

  /// Stable clinical anchor (UUID); same as [id].
  String get patientId => id;

  ApiPatientRegistrationStatus get registrationStatusEnum =>
      ApiPatientRegistrationStatus.parse(registrationStatus);

  factory ApiPatient.fromJson(Map<String, dynamic> json) => ApiPatient(
        id: _parseGuid(json['id']) ?? '',
        userId: json['userId'] as String?,
        fullName: json['fullName'] as String? ?? '',
        phoneNumber: json['phoneNumber'] as String? ?? '',
        email: json['email'] as String?,
        dateOfBirth: json['dateOfBirth'] != null
            ? DateTime.tryParse(json['dateOfBirth'] as String)
            : null,
        insuranceStatus: json['insuranceStatus'] as bool? ?? false,
        insuranceDetails: json['insuranceDetails'] as String?,
        chronicDiseases: json['chronicDiseases'] as String?,
        registrationStatus: json['registrationStatus'] as String?,
      );
}

String? _parseGuid(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

/// JSON numbers may arrive as [int], [double], or [String] depending on serializer / client.
int _parseInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim()) ?? fallback;
}

int? _parseIntNullable(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}

bool _isoHasTimezoneSuffix(String s) {
  if (s.endsWith('Z')) return true;
  return RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s) ||
      RegExp(r'[+-]\d{4}$').hasMatch(s);
}

/// API fields named *Utc are stored as UTC. If JSON has no `Z`/offset (e.g. EF Unspecified), treat as UTC.
DateTime _parseUtcIso8601(dynamic raw) {
  var s = raw.toString().trim();
  if (s.isEmpty) {
    throw FormatException('Empty ISO-8601 date');
  }
  s = s.replaceFirst(' ', 'T');
  s = s.replaceFirstMapped(RegExp(r'(\.\d{6})\d+'), (m) => m.group(1)!);
  if (!_isoHasTimezoneSuffix(s)) {
    s = '${s}Z';
  }
  return DateTime.parse(s).toUtc();
}

DateTime? _tryParseUtcIso8601(dynamic raw) {
  if (raw == null) return null;
  try {
    return _parseUtcIso8601(raw);
  } catch (_) {
    final fallback = DateTime.tryParse(raw.toString().trim());
    return fallback?.toUtc();
  }
}

class ApiAppointment {
  const ApiAppointment({
    required this.id,
    required this.patientId,
    required this.clinicId,
    this.doctorId,
    required this.patientName,
    required this.phoneNumber,
    required this.scheduledAtUtc,
    required this.type,
    required this.status,
    this.notes,
    this.clinicName,
    this.doctorName,
    this.createdAtUtc,
    this.updatedAtUtc,
  });

  final int id;
  final String patientId;
  final int clinicId;
  final int? doctorId;
  final String patientName;
  final String phoneNumber;
  final DateTime scheduledAtUtc;
  final ApiAppointmentType type;
  final ApiAppointmentStatus status;
  final String? notes;
  final String? clinicName;
  final String? doctorName;
  final DateTime? createdAtUtc;
  final DateTime? updatedAtUtc;

  factory ApiAppointment.fromJson(Map<String, dynamic> json) => ApiAppointment(
        id: _parseInt(json['id']),
        patientId: _parseGuid(json['patientId'] ?? json['patient_id']) ?? '',
        clinicId: _parseInt(json['clinicId'] ?? json['clinic_id']),
        doctorId: _parseIntNullable(json['doctorId']),
        patientName: json['patientName'] as String? ?? '',
        phoneNumber: json['phoneNumber'] as String? ?? '',
        scheduledAtUtc: _parseUtcIso8601(json['scheduledAtUtc']),
        type: _parseAppointmentType(json['type']),
        status: _parseAppointmentStatus(json['status']),
        notes: json['notes'] as String?,
        clinicName: json['clinicName'] as String?,
        doctorName: json['doctorName'] as String?,
        createdAtUtc: _tryParseUtcIso8601(json['createdAtUtc']),
        updatedAtUtc: _tryParseUtcIso8601(json['updatedAtUtc']),
      );

  /// Opens the doctor session screen from the patient archive when there is no live appointment row. [id] is 0.
  factory ApiAppointment.forHistoryReview({
    required String patientId,
    required String patientName,
    required String phoneNumber,
    required int clinicId,
    required DateTime lastVisitUtc,
  }) {
    return ApiAppointment(
      id: 0,
      patientId: patientId,
      clinicId: clinicId,
      doctorId: null,
      patientName: patientName,
      phoneNumber: phoneNumber,
      scheduledAtUtc: lastVisitUtc,
      type: ApiAppointmentType.general,
      status: ApiAppointmentStatus.completed,
    );
  }
}

class ApiMedicalRecord {
  const ApiMedicalRecord({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.clinicId,
    this.symptoms,
    this.diagnosis,
    this.notes,
  });

  final int id;
  final String patientId;
  final int doctorId;
  final int clinicId;
  final String? symptoms;
  final String? diagnosis;
  final String? notes;

  factory ApiMedicalRecord.fromJson(Map<String, dynamic> json) => ApiMedicalRecord(
        id: _parseInt(json['id']),
        patientId: _parseGuid(json['patientId']) ?? '',
        doctorId: _parseInt(json['doctorId']),
        clinicId: _parseInt(json['clinicId']),
        symptoms: json['symptoms'] as String?,
        diagnosis: json['diagnosis'] as String?,
        notes: json['notes'] as String?,
      );
}

class ApiPrescription {
  const ApiPrescription({
    required this.id,
    required this.medicalRecordId,
    required this.doctorId,
  });

  final int id;
  final int medicalRecordId;
  final int doctorId;

  factory ApiPrescription.fromJson(Map<String, dynamic> json) => ApiPrescription(
        id: _parseInt(json['id']),
        medicalRecordId: _parseInt(json['medicalRecordId']),
        doctorId: _parseInt(json['doctorId']),
      );
}

class ApiMedication {
  const ApiMedication({
    required this.id,
    required this.prescriptionId,
    required this.name,
    required this.dosage,
    required this.schedule,
    this.instructions,
  });

  final int id;
  final int prescriptionId;
  final String name;
  final String dosage;
  final String schedule;
  final String? instructions;

  factory ApiMedication.fromJson(Map<String, dynamic> json) => ApiMedication(
        id: _parseInt(json['id']),
        prescriptionId: _parseIntNullable(json['prescriptionId']) ?? 0,
        name: json['name'] as String? ?? '',
        dosage: json['dosage'] as String? ?? '',
        schedule: json['schedule'] as String? ?? '',
        instructions: json['instructions'] as String?,
      );
}

class ApiPrescriptionSummary {
  const ApiPrescriptionSummary({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.medications,
  });

  final int id;
  final String patientId;
  final int doctorId;
  final List<ApiMedication> medications;

  factory ApiPrescriptionSummary.fromJson(Map<String, dynamic> json) {
    final meds = (json['medications'] as List<dynamic>?) ?? const [];
    return ApiPrescriptionSummary(
      id: _parseInt(json['id']),
      patientId: _parseGuid(json['patientId']) ?? '',
      doctorId: _parseInt(json['doctorId']),
      medications: meds
          .whereType<Map>()
          .map((e) => ApiMedication.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// Full `MedicalRecordDto` from the API (visit file with prescriptions and attachments).
class ApiMedicalRecordDetail {
  const ApiMedicalRecordDetail({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.clinicId,
    this.symptoms,
    this.diagnosis,
    this.notes,
    required this.createdAtUtc,
    required this.prescriptions,
    required this.attachments,
  });

  final int id;
  final String patientId;
  final String patientName;
  final int doctorId;
  final String doctorName;
  final int clinicId;
  final String? symptoms;
  final String? diagnosis;
  final String? notes;
  final DateTime createdAtUtc;
  final List<ApiPrescriptionSummary> prescriptions;
  final List<ApiFileAttachment> attachments;

  int? get primaryPrescriptionId =>
      prescriptions.isEmpty ? null : prescriptions.first.id;

  factory ApiMedicalRecordDetail.fromJson(Map<String, dynamic> json) {
    final presc = (json['prescriptions'] as List<dynamic>?) ?? const [];
    final att = (json['attachments'] as List<dynamic>?) ?? const [];
    return ApiMedicalRecordDetail(
      id: _parseInt(json['id']),
      patientId: _parseGuid(json['patientId']) ?? '',
      patientName: json['patientName'] as String? ?? '',
      doctorId: _parseInt(json['doctorId']),
      doctorName: json['doctorName'] as String? ?? '',
      clinicId: _parseInt(json['clinicId']),
      symptoms: json['symptoms'] as String?,
      diagnosis: json['diagnosis'] as String?,
      notes: json['notes'] as String?,
      createdAtUtc: _tryParseUtcIso8601(json['createdAtUtc']) ?? DateTime.now().toUtc(),
      prescriptions: presc
          .whereType<Map>()
          .map((e) => ApiPrescriptionSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      attachments: att
          .whereType<Map>()
          .map((e) => ApiFileAttachment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class ApiFileAttachment {
  const ApiFileAttachment({
    required this.id,
    required this.medicalRecordId,
    required this.filePath,
    this.publicUrl,
    required this.originalFileName,
    required this.contentType,
    required this.fileSizeBytes,
    required this.uploadedByUserId,
  });

  final int id;
  final int medicalRecordId;
  final String filePath;
  final String? publicUrl;
  final String originalFileName;
  final String contentType;
  final int fileSizeBytes;
  final String uploadedByUserId;

  factory ApiFileAttachment.fromJson(Map<String, dynamic> json) => ApiFileAttachment(
        id: _parseInt(json['id']),
        medicalRecordId: _parseInt(json['medicalRecordId']),
        filePath: json['filePath'] as String? ?? '',
        publicUrl: json['publicUrl'] as String?,
        originalFileName: json['originalFileName'] as String? ?? '',
        contentType: json['contentType'] as String? ?? '',
        fileSizeBytes: _parseInt(json['fileSizeBytes'], 0),
        uploadedByUserId: json['uploadedByUserId'] as String? ?? '',
      );
}

class ApiNotification {
  const ApiNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.relatedAppointmentId,
    this.relatedPrescriptionId,
  });

  final int id;
  final String userId;
  final String title;
  final String message;
  final ApiNotificationType type;
  final bool isRead;
  final int? relatedAppointmentId;
  final int? relatedPrescriptionId;

  factory ApiNotification.fromJson(Map<String, dynamic> json) => ApiNotification(
        id: _parseInt(json['id']),
        userId: json['userId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        type: ApiNotificationType.values.firstWhere(
          (e) => e.value == _parseInt(json['type'], 3),
          orElse: () => ApiNotificationType.general,
        ),
        isRead: json['isRead'] as bool? ?? false,
        relatedAppointmentId: _parseIntNullable(json['relatedAppointmentId']),
        relatedPrescriptionId: _parseIntNullable(json['relatedPrescriptionId']),
      );
}

class ApiPatientClinic {
  const ApiPatientClinic({
    required this.id,
    required this.patientId,
    required this.clinicId,
    required this.linkedAtUtc,
  });

  final int id;
  final String patientId;
  final int clinicId;
  final DateTime linkedAtUtc;

  factory ApiPatientClinic.fromJson(Map<String, dynamic> json) => ApiPatientClinic(
        id: _parseInt(json['id']),
        patientId: _parseGuid(json['patientId']) ?? '',
        clinicId: _parseInt(json['clinicId']),
        linkedAtUtc: DateTime.parse(json['linkedAtUtc'].toString()),
      );
}
