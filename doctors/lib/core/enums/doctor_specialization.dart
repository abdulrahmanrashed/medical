enum DoctorSpecialization {
  general,
  cardiology,
  gynecology,
  ophthalmology,
  pregnancyFollowUp,
  other,
}

extension DoctorSpecializationLabel on DoctorSpecialization {
  String get label => switch (this) {
        DoctorSpecialization.general => 'General',
        DoctorSpecialization.cardiology => 'Cardiology',
        DoctorSpecialization.gynecology => 'Gynecology',
        DoctorSpecialization.ophthalmology => 'Ophthalmology',
        DoctorSpecialization.pregnancyFollowUp => 'Pregnancy follow-up',
        DoctorSpecialization.other => 'Other',
      };
}
