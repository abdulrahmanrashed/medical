import 'package:flutter/material.dart';

import 'app/medical_records_app.dart';
import 'core/network/session_manager.dart';
import 'core/notifications/medication_reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionManager.instance.restorePatientIdFromDisk();
  await MedicationReminderService.instance.init();
  runApp(const MedicalRecordsApp());
}
