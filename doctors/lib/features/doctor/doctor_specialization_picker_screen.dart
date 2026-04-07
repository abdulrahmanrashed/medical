import 'package:flutter/material.dart';

import '../../core/layout/responsive.dart';
import '../../core/enums/doctor_specialization.dart';
import '../../core/network/backend_api_client.dart';
import 'doctor_dashboard_screen.dart';

class DoctorSpecializationPickerScreen extends StatelessWidget {
  const DoctorSpecializationPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your specialization')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = Responsive.isTablet(constraints.maxWidth);
          return ListView(
            padding: Responsive.screenPadding(context),
            children: [
              Text(
                'Each specialization gets its own dashboard layout and fields.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final me = await BackendApiClient.instance.getDoctorMe();
                    if (!context.mounted) return;
                    final specialization = _fromApi(
                      me['specialization']?.toString() ?? '',
                    );
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => DoctorDashboardScreen(
                          specialization: specialization,
                        ),
                      ),
                    );
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not load doctor profile.')),
                    );
                  }
                },
                icon: const Icon(Icons.cloud_sync_outlined),
                label: const Text('Use specialization from API'),
              ),
              const SizedBox(height: 16),
              if (isTablet)
                GridView.builder(
                  itemCount: DoctorSpecialization.values.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.6,
                  ),
                  itemBuilder: (context, index) {
                    final spec = DoctorSpecialization.values[index];
                    return Card(
                      child: ListTile(
                        title: Text(spec.label),
                        trailing: const Icon(Icons.dashboard_customize_outlined),
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  DoctorDashboardScreen(specialization: spec),
                            ),
                          );
                        },
                      ),
                    );
                  },
                )
              else
                for (final spec in DoctorSpecialization.values)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(spec.label),
                      trailing: const Icon(Icons.dashboard_customize_outlined),
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                DoctorDashboardScreen(specialization: spec),
                          ),
                        );
                      },
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  DoctorSpecialization _fromApi(String value) {
    final key = value.toLowerCase().replaceAll(' ', '');
    return switch (key) {
      'cardiology' => DoctorSpecialization.cardiology,
      'gynecology' => DoctorSpecialization.gynecology,
      'ophthalmology' => DoctorSpecialization.ophthalmology,
      'pregnancyfollowup' => DoctorSpecialization.pregnancyFollowUp,
      'general' => DoctorSpecialization.general,
      _ => DoctorSpecialization.other,
    };
  }
}
