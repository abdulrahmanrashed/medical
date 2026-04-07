enum UserRole {
  admin,
  clinicManagement,
  doctor,
  receptionist,
  patient,
}

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.admin => 'Admin',
        UserRole.clinicManagement => 'Clinic Management',
        UserRole.doctor => 'Doctor',
        UserRole.receptionist => 'Receptionist',
        UserRole.patient => 'Patient',
      };
}

extension UserRoleDescription on UserRole {
  String get shortDescription => switch (this) {
        UserRole.admin => 'Manage clinics, users & security',
        UserRole.clinicManagement => 'Clinic owner portal & staff setup',
        UserRole.doctor => 'Manage patients & records',
        UserRole.receptionist => 'Front desk & appointments',
        UserRole.patient => 'Book visits & view your care',
      };
}
