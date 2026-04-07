import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/layout/responsive.dart';
import '../../core/network/session_manager.dart';
import '../reception/reception_my_doctors_panel.dart';
import 'clinic_receptionists_panel.dart';

/// Clinic owner (ClinicAdmin): manage doctors and receptionists for assigned clinic.
class ClinicOwnerShellScreen extends StatelessWidget {
  const ClinicOwnerShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final clinicId = SessionManager.instance.assignedClinicId;
    final padding = Responsive.screenPadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinic dashboard'),
      ),
      body: clinicId == null
          ? Center(
              child: Padding(
                padding: padding,
                child: const Text(
                  'No clinic is assigned to this account. Contact system support.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: padding,
              children: [
                Text(
                  'Welcome',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Clinic ID $clinicId · Manage your team below.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: const Color(0xFF616161),
                  ),
                ),
                const SizedBox(height: 28),
                _ActionTile(
                  icon: Icons.medical_services_outlined,
                  title: 'Manage doctors',
                  subtitle: 'Add, review, or remove doctors for your clinic',
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const _ClinicDoctorsPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                _ActionTile(
                  icon: Icons.groups_outlined,
                  title: 'Manage receptionists',
                  subtitle: 'Register front-desk staff for your clinic',
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => ClinicReceptionistsPanel(clinicId: clinicId),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF004D40).withValues(alpha: 0.12),
          foregroundColor: const Color(0xFF004D40),
          radius: 28,
          child: Icon(icon, size: 28),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(subtitle, style: GoogleFonts.inter(fontSize: 13)),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ClinicDoctorsPage extends StatefulWidget {
  const _ClinicDoctorsPage();

  @override
  State<_ClinicDoctorsPage> createState() => _ClinicDoctorsPageState();
}

class _ClinicDoctorsPageState extends State<_ClinicDoctorsPage> {
  final GlobalKey<ReceptionMyDoctorsPanelState> _doctorsKey =
      GlobalKey<ReceptionMyDoctorsPanelState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage doctors')),
      body: ReceptionMyDoctorsPanel(key: _doctorsKey),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _doctorsKey.currentState?.openAddDoctor(),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add doctor'),
      ),
    );
  }
}
