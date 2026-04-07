import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/role_selection/role_selection_screen.dart';

class MedicalRecordsApp extends StatelessWidget {
  const MedicalRecordsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi-Clinic Medical Records',
      theme: AppTheme.light,
      home: const RoleSelectionScreen(),
    );
  }
}
