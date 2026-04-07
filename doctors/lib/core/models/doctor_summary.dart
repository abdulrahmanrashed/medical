import '../enums/doctor_specialization.dart';

class DoctorSummary {
  const DoctorSummary({
    required this.id,
    required this.name,
    required this.specialization,
  });

  final String id;
  final String name;
  final DoctorSpecialization specialization;

  static DoctorSpecialization specializationFromApi(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.contains('cardio')) return DoctorSpecialization.cardiology;
    if (s.contains('gynec')) return DoctorSpecialization.gynecology;
    if (s.contains('ophthal') || s.contains('eye')) {
      return DoctorSpecialization.ophthalmology;
    }
    if (s.contains('pregnan') || s.contains('prenatal') || s.contains('obstet')) {
      return DoctorSpecialization.pregnancyFollowUp;
    }
    if (s.contains('general')) return DoctorSpecialization.general;
    return DoctorSpecialization.other;
  }

  factory DoctorSummary.fromApi(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final first = json['firstName']?.toString() ?? '';
    final last = json['lastName']?.toString() ?? '';
    final specRaw = json['specialization']?.toString() ?? '';
    return DoctorSummary(
      id: '$id',
      name: '$first $last'.trim().isEmpty ? 'Doctor #$id' : '$first $last'.trim(),
      specialization: specializationFromApi(specRaw),
    );
  }
}
