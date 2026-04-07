import 'package:flutter/material.dart';

import 'app/medical_records_app.dart';
import 'core/network/session_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionManager.instance.restorePatientIdFromDisk();
  runApp(const MedicalRecordsApp());
}
