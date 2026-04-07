import 'package:flutter/material.dart';

import '../../core/layout/responsive.dart';
import '../../core/network/backend_api_client.dart';
import '../../widgets/add_patient_draft_card.dart';
import 'admin_clinics_manage_panel.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _index = 0;

  final GlobalKey<AdminClinicsManagePanelState> _clinicsKey =
      GlobalKey<AdminClinicsManagePanelState>();

  final _titles = const [
    'Dashboard',
    'Clinics',
    'Doctors',
  ];

  final _destinations = const [
    NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
    NavigationDestination(icon: Icon(Icons.local_hospital_outlined), label: 'Clinics'),
    NavigationDestination(icon: Icon(Icons.badge_outlined), label: 'Doctors'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = Responsive.isTablet(constraints.maxWidth);
        return Scaffold(
          appBar: AppBar(title: Text('Admin · ${_titles[_index]}')),
          floatingActionButton: _index == 1
              ? FloatingActionButton.extended(
                  onPressed: () =>
                      _clinicsKey.currentState?.showAddClinicSheet(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add clinic'),
                  backgroundColor: const Color(0xFF004D40),
                  foregroundColor: Colors.white,
                )
              : null,
          body: isTablet
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _index,
                      onDestinationSelected: (i) => setState(() => _index = i),
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          label: Text('Dashboard'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.local_hospital_outlined),
                          label: Text('Clinics'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.badge_outlined),
                          label: Text('Doctors'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: _body()),
                  ],
                )
              : _body(),
          bottomNavigationBar: isTablet
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: _destinations,
                ),
        );
      },
    );
  }

  Widget _body() {
    return switch (_index) {
      0 => _DashboardPanel(),
      1 => AdminClinicsManagePanel(key: _clinicsKey),
      _ => const _DoctorsPanel(),
    };
  }
}

class _DashboardPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: BackendApiClient.instance.getClinics(),
      builder: (context, clinicsSnap) {
        if (clinicsSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (clinicsSnap.hasError) {
          return Center(child: Text('Could not load dashboard: ${clinicsSnap.error}'));
        }

        final clinics = clinicsSnap.data ?? const <Map<String, dynamic>>[];
        final doctorCount = clinics.fold<int>(
          0,
          (sum, c) => sum + (((c['doctorCount'] as num?)?.toInt()) ?? 0),
        );
        final avgDoctors = clinics.isEmpty ? 0.0 : doctorCount / clinics.length;

        return ListView(
          padding: Responsive.screenPadding(context),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatCard(title: 'Clinics', value: '${clinics.length}', icon: Icons.local_hospital),
                _StatCard(title: 'Doctors', value: '$doctorCount', icon: Icons.medical_services),
                _StatCard(
                  title: 'Avg Doctors / Clinic',
                  value: avgDoctors.toStringAsFixed(1),
                  icon: Icons.analytics_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: const Text('Add patient (draft)'),
                subtitle: const Text('Requires name and phone only — same as reception.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Add patient draft'),
                      content: const SingleChildScrollView(
                        child: SizedBox(
                          width: 400,
                          child: AddPatientDraftCard(compact: true),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text('Clinic Capacity Overview', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final c in clinics)
              _BarTile(
                label: c['name']?.toString() ?? 'Clinic',
                value: ((c['doctorCount'] as num?)?.toInt()) ?? 0,
                max: doctorCount == 0 ? 1 : doctorCount,
              ),
          ],
        );
      },
    );
  }
}

class _DoctorsPanel extends StatelessWidget {
  const _DoctorsPanel();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: BackendApiClient.instance.getClinics(),
      builder: (context, clinicsSnap) {
        if (clinicsSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (clinicsSnap.hasError) {
          return Center(child: Text('Could not load doctors: ${clinicsSnap.error}'));
        }
        final clinics = clinicsSnap.data ?? const <Map<String, dynamic>>[];
        return ListView(
          padding: Responsive.screenPadding(context),
          children: [
            for (final c in clinics)
              FutureBuilder<List<Map<String, dynamic>>>(
                future: BackendApiClient.instance.getDoctorsByClinic(
                  ((c['id'] as num?)?.toInt()) ?? 0,
                ),
                builder: (context, doctorsSnap) {
                  if (doctorsSnap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: LinearProgressIndicator(),
                    );
                  }
                  if (doctorsSnap.hasError) {
                    return Card(
                      child: ListTile(
                        title: Text(c['name']?.toString() ?? 'Clinic'),
                        subtitle: const Text('Failed to load doctors'),
                      ),
                    );
                  }
                  final doctors = doctorsSnap.data ?? const <Map<String, dynamic>>[];
                  return Card(
                    child: ExpansionTile(
                      title: Text(c['name']?.toString() ?? 'Clinic'),
                      subtitle: Text('${doctors.length} doctors'),
                      children: [
                        for (final d in doctors)
                          ListTile(
                            dense: true,
                            title: Text(
                              '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim(),
                            ),
                            subtitle: Text(d['specialization']?.toString() ?? ''),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodySmall),
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarTile extends StatelessWidget {
  const _BarTile({
    required this.label,
    required this.value,
    required this.max,
  });

  final String label;
  final int value;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ratio = (value / max).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: ratio),
            const SizedBox(height: 4),
            Text('$value doctors', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
