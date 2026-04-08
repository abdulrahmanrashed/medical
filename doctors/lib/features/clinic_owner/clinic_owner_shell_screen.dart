import 'package:flutter/material.dart';

import '../../core/layout/responsive.dart';
import '../../core/network/session_manager.dart';
import '../reception/reception_my_doctors_panel.dart' show ReceptionMyDoctorsPanel, showReceptionAddDoctorSheet;
import 'clinic_receptionists_panel.dart';
import 'clinic_schedule_management_screen.dart';
import 'clinic_owner_ui.dart';

/// Clinic owner (ClinicAdmin): responsive dashboard, rail on tablet, bottom nav on phone.
class ClinicOwnerShellScreen extends StatefulWidget {
  const ClinicOwnerShellScreen({super.key});

  @override
  State<ClinicOwnerShellScreen> createState() => _ClinicOwnerShellScreenState();
}

class _ClinicOwnerShellScreenState extends State<ClinicOwnerShellScreen> {
  int _index = 0;
  Future<void> Function()? _reloadDoctors;
  Future<void> Function()? _reloadSchedules;
  Future<void> Function()? _reloadReceptionists;

  static const _titles = [
    'Clinic dashboard',
    'Manage doctors',
    'Manage schedules',
    'Manage receptionists',
  ];

  @override
  Widget build(BuildContext context) {
    final clinicId = SessionManager.instance.assignedClinicId;
    if (clinicId == null) {
      return Scaffold(
        backgroundColor: ClinicOwnerUi.surface,
        appBar: AppBar(
          title: const Text('Clinic dashboard'),
          backgroundColor: ClinicOwnerUi.surface,
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: Padding(
            padding: Responsive.screenPadding(context),
            child: const Text(
              'No clinic is assigned to this account. Contact system support.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final useRail = Responsive.isTablet(w);
        final maxW = Responsive.contentMaxWidth(w);
        final padding = Responsive.screenPadding(context);

        Widget main = _buildMainContent(clinicId, w, padding);
        main = Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: main,
          ),
        );

        return Scaffold(
          backgroundColor: ClinicOwnerUi.surface,
          appBar: AppBar(
            title: Text(_titles[_index]),
            backgroundColor: ClinicOwnerUi.surface,
            surfaceTintColor: Colors.transparent,
          ),
          floatingActionButton: _buildFab(clinicId),
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
                    NavigationDestination(icon: Icon(Icons.medical_services_outlined), label: 'Doctors'),
                    NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Schedules'),
                    NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Reception'),
                  ],
                ),
          body: useRail
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NavigationRail(
                      selectedIndex: _index,
                      onDestinationSelected: (i) => setState(() => _index = i),
                      labelType: NavigationRailLabelType.all,
                      backgroundColor: Colors.white,
                      indicatorColor: ClinicOwnerUi.primary.withValues(alpha: 0.12),
                      selectedIconTheme: const IconThemeData(color: ClinicOwnerUi.primary),
                      selectedLabelTextStyle: const TextStyle(
                        color: ClinicOwnerUi.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard),
                          label: Text('Home'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.medical_services_outlined),
                          selectedIcon: Icon(Icons.medical_services),
                          label: Text('Doctors'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.calendar_month_outlined),
                          selectedIcon: Icon(Icons.calendar_month),
                          label: Text('Schedules'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.groups_outlined),
                          selectedIcon: Icon(Icons.groups),
                          label: Text('Reception'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: main),
                  ],
                )
              : main,
        );
      },
    );
  }

  Widget? _buildFab(int clinicId) {
    switch (_index) {
      case 1:
        return FloatingActionButton.extended(
          onPressed: () => showReceptionAddDoctorSheet(
            context,
            onSuccess: () async => _reloadDoctors?.call(),
          ),
          backgroundColor: ClinicOwnerUi.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.person_add),
          label: const Text('Add doctor'),
        );
      case 2:
        return FloatingActionButton.extended(
          onPressed: () async {
            await showClinicOwnerAddScheduleSheet(
              context,
              clinicId: clinicId,
              onSuccess: () async => _reloadSchedules?.call(),
            );
          },
          backgroundColor: ClinicOwnerUi.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Add schedule'),
        );
      case 3:
        return FloatingActionButton.extended(
          onPressed: () => showAddClinicReceptionistSheet(
            context,
            clinicId: clinicId,
            onSuccess: () async => _reloadReceptionists?.call(),
          ),
          backgroundColor: ClinicOwnerUi.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.person_add),
          label: const Text('Add receptionist'),
        );
      default:
        return null;
    }
  }

  Widget _buildMainContent(int clinicId, double width, EdgeInsets padding) {
    switch (_index) {
      case 0:
        return _DashboardGrid(
          clinicId: clinicId,
          padding: padding,
          width: width,
          onSelect: (i) => setState(() => _index = i),
        );
      case 1:
        return ReceptionMyDoctorsPanel(
          useClinicOwnerLayout: true,
          onReloadReady: (reload) => _reloadDoctors = reload,
        );
      case 2:
        return ClinicScheduleManagementScreen(
          clinicId: clinicId,
          embedded: true,
          onReloadReady: (reload) => _reloadSchedules = reload,
        );
      case 3:
        return ClinicReceptionistsPanel(
          clinicId: clinicId,
          embedded: true,
          onReloadReady: (reload) => _reloadReceptionists = reload,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({
    required this.clinicId,
    required this.padding,
    required this.width,
    required this.onSelect,
  });

  final int clinicId;
  final EdgeInsets padding;
  final double width;
  final void Function(int index) onSelect;

  @override
  Widget build(BuildContext context) {
    final cols = Responsive.gridColumnCount(width);
    final cards = [
      _DashCardData(
        index: 1,
        icon: Icons.medical_services_outlined,
        title: 'Manage doctors',
        subtitle: 'Add, freeze, or review doctors for your clinic',
      ),
      _DashCardData(
        index: 2,
        icon: Icons.calendar_month_outlined,
        title: 'Manage schedules',
        subtitle: 'Shifts, days off, and holidays',
      ),
      _DashCardData(
        index: 3,
        icon: Icons.groups_outlined,
        title: 'Manage receptionists',
        subtitle: 'Register front-desk staff',
      ),
    ];

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome', style: ClinicOwnerUi.welcomeTitle(width)),
                const SizedBox(height: 8),
                Text(
                  'Clinic ID $clinicId · Choose a section below',
                  style: ClinicOwnerUi.welcomeSubtitle(),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: padding.copyWith(top: 8),
          sliver: cols == 1
              ? SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final c = cards[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _DashboardActionCard(data: c, onTap: () => onSelect(c.index)),
                      );
                    },
                    childCount: cards.length,
                  ),
                )
              : SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: cols >= 3 ? 1.25 : 1.15,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final c = cards[i];
                      return _DashboardActionCard(data: c, onTap: () => onSelect(c.index));
                    },
                    childCount: cards.length,
                  ),
                ),
        ),
      ],
    );
  }
}

class _DashCardData {
  const _DashCardData({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
}

class _DashboardActionCard extends StatelessWidget {
  const _DashboardActionCard({required this.data, required this.onTap});

  final _DashCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: ClinicOwnerUi.premiumCardDecoration(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: ClinicOwnerUi.primary.withValues(alpha: 0.12),
                  foregroundColor: ClinicOwnerUi.primary,
                  child: Icon(data.icon, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: ClinicOwnerUi.onSurfaceTitle,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data.subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: ClinicOwnerUi.onSurfaceMuted,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: ClinicOwnerUi.primary.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
