import '../enums/doctor_specialization.dart';
import 'doctor_summary.dart';

class ClinicSummary {
  const ClinicSummary({
    required this.id,
    required this.name,
    required this.availableSpecialties,
    this.doctors,
    this.address,
    this.phone,
    this.email,
    this.doctorCount,
  });

  final String id;
  final String name;
  final List<DoctorSpecialization> availableSpecialties;
  /// Optional preview list; may be null or empty when not exposed to patients.
  final List<DoctorSummary>? doctors;
  final String? address;
  final String? phone;
  final String? email;
  final int? doctorCount;

  /// From GET /Clinics item (roster not loaded).
  factory ClinicSummary.fromApiClinic(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    return ClinicSummary(
      id: '$id',
      name: json['name']?.toString() ?? 'Clinic',
      availableSpecialties: const [],
      doctors: null,
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      doctorCount: (json['doctorCount'] as num?)?.toInt(),
    );
  }

  /// Merge roster from GET /Doctors/clinic/{id} for booking flow.
  ClinicSummary withDoctors(List<DoctorSummary> roster) {
    final specs = roster.map((d) => d.specialization).toSet().toList();
    specs.sort((a, b) => a.label.compareTo(b.label));
    final fallback = specs.isEmpty
        ? <DoctorSpecialization>[
            DoctorSpecialization.general,
            DoctorSpecialization.other,
          ]
        : specs;
    return ClinicSummary(
      id: id,
      name: name,
      availableSpecialties: fallback,
      doctors: roster,
      address: address,
      phone: phone,
      email: email,
      doctorCount: doctorCount ?? roster.length,
    );
  }
}
