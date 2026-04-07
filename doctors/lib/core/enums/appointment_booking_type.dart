/// General: visible to all doctors in the clinic.
/// SpecificDoctor: visible only to the assigned doctor.
enum AppointmentBookingType {
  general,
  specificDoctor,
}

extension AppointmentBookingTypeLabel on AppointmentBookingType {
  String get label => switch (this) {
        AppointmentBookingType.general => 'General (all doctors)',
        AppointmentBookingType.specificDoctor => 'Specific doctor',
      };
}
