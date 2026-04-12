import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting/appointment_time_display.dart';
import '../../core/layout/adaptive_sheet.dart';
import '../../core/layout/responsive.dart';
import '../../core/layout/responsive_main_content.dart';
import '../../core/models/backend_models.dart';
import '../../core/theme/teal_modern_style.dart';
import '../../widgets/add_patient_draft_card.dart';
import 'reception_add_appointment_sheet.dart';
import 'reception_dashboard_controller.dart';

/// Red numeric badge; driven by [stream] (emits after each appointment sync, including 30s poll).
Widget _pendingRequestBadge({
  required Stream<int> stream,
  required int initialCount,
  required Widget child,
}) {
  return StreamBuilder<int>(
    stream: stream,
    initialData: initialCount,
    builder: (context, snapshot) {
      final n = snapshot.data ?? 0;
      return Badge(
        isLabelVisible: n > 0,
        backgroundColor: Colors.red,
        label: Text(
          n > 99 ? '99+' : '$n',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        child: child,
      );
    },
  );
}

class ReceptionShellScreen extends StatefulWidget {
  const ReceptionShellScreen({super.key});

  @override
  State<ReceptionShellScreen> createState() => _ReceptionShellScreenState();
}

class _ReceptionShellScreenState extends State<ReceptionShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = Responsive.useMasterLayout(constraints.maxWidth);
        return Consumer<ReceptionDashboardController>(
          builder: (context, dash, _) {
            final pendingCount = dash.pendingAppointments.length;
            return Scaffold(
              appBar: AppBar(
                title: Text(_appBarTitle),
                actions: [
                  IconButton(
                    tooltip: 'Pending requests',
                    onPressed: () => setState(() => _index = 1),
                    icon: _pendingRequestBadge(
                      stream: dash.pendingAppointmentCountStream,
                      initialCount: pendingCount,
                      child: const Icon(Icons.mark_email_unread_outlined),
                    ),
                  ),
                ],
              ),
              body: isTablet
                  ? Row(
                      children: [
                        NavigationRail(
                          selectedIndex: _index,
                          onDestinationSelected: (i) => setState(() => _index = i),
                          labelType: NavigationRailLabelType.all,
                          destinations: [
                            const NavigationRailDestination(
                              icon: Icon(Icons.calendar_month_outlined),
                              label: Text('Timeline'),
                            ),
                            NavigationRailDestination(
                              icon: _pendingRequestBadge(
                                stream: dash.pendingAppointmentCountStream,
                                initialCount: pendingCount,
                                child: const Icon(Icons.pending_actions_outlined),
                              ),
                              label: const Text('Pending'),
                            ),
                            const NavigationRailDestination(
                              icon: Icon(Icons.notifications_active_outlined),
                              label: Text('Live Feed'),
                            ),
                            const NavigationRailDestination(
                              icon: Icon(Icons.person_add_outlined),
                              label: Text('Add patient'),
                            ),
                          ],
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: ResponsiveMainContent(
                            width: constraints.maxWidth,
                            child: _body(context, dash),
                          ),
                        ),
                      ],
                    )
                  : _body(context, dash),
              bottomNavigationBar: isTablet
                  ? null
                  : NavigationBar(
                      selectedIndex: _index,
                      onDestinationSelected: (i) => setState(() => _index = i),
                      destinations: [
                        const NavigationDestination(
                          icon: Icon(Icons.calendar_month_outlined),
                          selectedIcon: Icon(Icons.calendar_month),
                          label: 'Timeline',
                        ),
                        NavigationDestination(
                          icon: _pendingRequestBadge(
                            stream: dash.pendingAppointmentCountStream,
                            initialCount: pendingCount,
                            child: const Icon(Icons.pending_actions_outlined),
                          ),
                          selectedIcon: _pendingRequestBadge(
                            stream: dash.pendingAppointmentCountStream,
                            initialCount: pendingCount,
                            child: const Icon(Icons.pending_actions),
                          ),
                          label: 'Pending',
                        ),
                        const NavigationDestination(
                          icon: Icon(Icons.notifications_active_outlined),
                          selectedIcon: Icon(Icons.notifications_active),
                          label: 'Live Feed',
                        ),
                        const NavigationDestination(
                          icon: Icon(Icons.person_add_outlined),
                          selectedIcon: Icon(Icons.person_add),
                          label: 'Add patient',
                        ),
                      ],
                    ),
              floatingActionButton: _index == 0
                  ? FloatingActionButton.extended(
                      onPressed: () => showReceptionAddAppointmentSheet(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add appointment'),
                      backgroundColor: const Color(0xFF004D40),
                      foregroundColor: Colors.white,
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  String get _appBarTitle => switch (_index) {
        0 => 'Reception · Timeline',
        1 => 'Reception · Pending requests',
        2 => 'Reception · Live Feed',
        _ => 'Reception · Add patient',
      };

  Widget _body(BuildContext context, ReceptionDashboardController dash) {
    return switch (_index) {
      0 => _AppointmentsPanel(dash: dash),
      1 => _PendingRequestsPanel(dash: dash),
      2 => _LiveFeedPanel(dash: dash),
      _ => ListView(
          padding: Responsive.screenPadding(context),
          children: const [
            AddPatientDraftCard(),
          ],
        ),
    };
  }
}

class _AppointmentsPanel extends StatelessWidget {
  const _AppointmentsPanel({required this.dash});

  final ReceptionDashboardController dash;

  @override
  Widget build(BuildContext context) {
    if (dash.loading && dash.appointments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (dash.lastError != null && dash.appointments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dash.lastError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => dash.refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => dash.refresh(),
      child: dash.activeAppointmentsForTimeline.isEmpty
          ? ListView(
              padding: Responsive.screenPadding(context),
              children: [
                const SizedBox(height: 48),
                Center(
                  child: Text(
                    dash.appointments.isEmpty
                        ? 'No appointments yet. Tap Add appointment.'
                        : 'No active appointments. Completed visits disappear from this list a few seconds after the doctor ends the session.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: Responsive.screenPadding(context),
              itemCount: dash.activeAppointmentsForTimeline.length,
              itemBuilder: (context, i) {
                final ap = dash.activeAppointmentsForTimeline[i];
                final busy = dash.busyAppointmentId == ap.id;
                return Card(
                  key: ValueKey(ap.id),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_statusIcon(ap.status), color: TealModernStyle.deepTeal),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                ap.patientName,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${formatAppointmentDateTimeLine(ap.scheduledAtUtc)} · ${_statusLabel(ap.status)}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Text(
                          '${ap.clinicName ?? 'Clinic'} · ${_typeLabel(ap.type)}'
                          '${ap.doctorName != null && ap.doctorName!.isNotEmpty ? ' · ${ap.doctorName}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        if (ap.phoneNumber.isNotEmpty)
                          Text(
                            ap.phoneNumber,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        if (ap.receptionNotes != null && ap.receptionNotes!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Reception notes',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: TealModernStyle.midTeal,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            ap.receptionNotes!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TealModernStyle.primaryButton(
                              onPressed: busy
                                  ? null
                                  : () => _editAppointmentTime(context, dash, ap),
                              child: const Text('Edit time'),
                            ),
                            OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () => _confirmCancelAppointment(context, dash, ap),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: TealModernStyle.deepTeal,
                                side: const BorderSide(color: TealModernStyle.midTeal, width: 1.5),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              ),
                              child: busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Cancel appointment'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  static IconData _statusIcon(ApiAppointmentStatus s) => switch (s) {
        ApiAppointmentStatus.pending => Icons.schedule,
        ApiAppointmentStatus.approved => Icons.event_available,
        ApiAppointmentStatus.inProgress => Icons.medication_outlined,
        ApiAppointmentStatus.rescheduled => Icons.update,
        ApiAppointmentStatus.cancelled => Icons.cancel_outlined,
        ApiAppointmentStatus.completed => Icons.check_circle_outline,
      };

  static String _statusLabel(ApiAppointmentStatus s) => switch (s) {
        ApiAppointmentStatus.pending => 'Pending',
        ApiAppointmentStatus.approved => 'Approved',
        ApiAppointmentStatus.inProgress => 'In progress',
        ApiAppointmentStatus.rescheduled => 'Rescheduled',
        ApiAppointmentStatus.cancelled => 'Cancelled',
        ApiAppointmentStatus.completed => 'Completed',
      };

  static String _typeLabel(ApiAppointmentType t) => switch (t) {
        ApiAppointmentType.general => 'General',
        ApiAppointmentType.specificDoctor => 'Specific doctor',
        ApiAppointmentType.pregnancyFollowUp => 'Pregnancy follow-up',
        ApiAppointmentType.diabetes => 'Diabetes',
      };
}

Future<void> _editAppointmentTime(
  BuildContext context,
  ReceptionDashboardController dash,
  ApiAppointment ap,
) async {
  DateTime scheduledUtc = ap.scheduledAtUtc;
  final confirmedUtc = await showDialog<DateTime>(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          final scheduledLocal = scheduledUtc.toLocal();
          return AlertDialog(
            title: Text('Edit time · ${ap.patientName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Visit time:', style: Theme.of(ctx).textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text(
                  formatLocalWallDateTimeLine(scheduledLocal),
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: dialogCtx,
                      initialDate: DateTime(
                        scheduledLocal.year,
                        scheduledLocal.month,
                        scheduledLocal.day,
                      ),
                      firstDate: now.subtract(const Duration(days: 1)),
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (d == null) return;
                    if (!dialogCtx.mounted) return;
                    final t = await showTimePicker(
                      context: dialogCtx,
                      initialTime: TimeOfDay(
                        hour: scheduledLocal.hour,
                        minute: scheduledLocal.minute,
                      ),
                    );
                    if (t == null) return;
                    scheduledUtc = DateTime(
                      d.year,
                      d.month,
                      d.day,
                      t.hour,
                      t.minute,
                    ).toUtc();
                    setDialogState(() {});
                  },
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('Change time'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogCtx, scheduledUtc),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
  if (confirmedUtc == null || !context.mounted) return;
  try {
    await dash.updateAppointmentTimeKeepingStatus(ap, confirmedUtc);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Updated to ${formatAppointmentDateTimeLine(confirmedUtc)}')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  }
}

Future<void> _confirmCancelAppointment(
  BuildContext context,
  ReceptionDashboardController dash,
  ApiAppointment ap,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel appointment?'),
      content: Text('Mark ${ap.patientName}\'s visit as cancelled?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: TealModernStyle.deepTeal,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await dash.cancelAppointment(ap);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Appointment cancelled.')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  }
}

class _PendingRequestsPanel extends StatelessWidget {
  const _PendingRequestsPanel({required this.dash});

  final ReceptionDashboardController dash;

  @override
  Widget build(BuildContext context) {
    if (dash.loading && dash.appointments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final pending = dash.pendingAppointments;

    return RefreshIndicator(
      onRefresh: () => dash.refresh(),
      child: pending.isEmpty
          ? ListView(
              padding: Responsive.screenPadding(context),
              children: const [
                SizedBox(height: 48),
                Center(
                  child: Text(
                    'No pending requests.\nPatient bookings appear here until approved.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: Responsive.screenPadding(context),
              itemCount: pending.length,
              itemBuilder: (context, i) {
                final a = pending[i];
                final busy = dash.busyAppointmentId == a.id;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.pending_actions, color: Colors.orange.shade800),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                a.patientName,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Requested time: ${formatAppointmentDateTimeLine(a.scheduledAtUtc)}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (a.phoneNumber.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            a.phoneNumber,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TealModernStyle.primaryButton(
                                onPressed: busy
                                    ? null
                                    : () => _onApprove(context, a),
                                loading: busy,
                                child: const Text('Approve'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => _showRejectRescheduleBottomSheet(context, a),
                                child: const Text('Reject / Reschedule'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Approve confirms the slot (API: Approved).',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _onApprove(BuildContext context, ApiAppointment a) async {
    DateTime scheduledUtc = a.scheduledAtUtc;
    final confirmedUtc = await showDialog<DateTime>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final scheduledLocal = scheduledUtc.toLocal();
            return AlertDialog(
              title: Text('Approve · ${a.patientName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visit time (adjust if needed):',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatLocalWallDateTimeLine(scheduledLocal),
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(
                        context: dialogCtx,
                        initialDate: DateTime(
                          scheduledLocal.year,
                          scheduledLocal.month,
                          scheduledLocal.day,
                        ),
                        firstDate: now.subtract(const Duration(days: 1)),
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (d == null) return;
                      if (!dialogCtx.mounted) return;
                      final t = await showTimePicker(
                        context: dialogCtx,
                        initialTime: TimeOfDay(
                          hour: scheduledLocal.hour,
                          minute: scheduledLocal.minute,
                        ),
                      );
                      if (t == null) return;
                      scheduledUtc = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        t.hour,
                        t.minute,
                      ).toUtc();
                      setDialogState(() {});
                    },
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('Change time'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogCtx, scheduledUtc),
                  child: const Text('Approve'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmedUtc == null || !context.mounted) return;
    try {
      await dash.approvePendingAppointment(a, scheduledAtUtc: confirmedUtc);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${a.patientName}: confirmed.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _showRejectRescheduleBottomSheet(
    BuildContext anchorContext,
    ApiAppointment a,
  ) async {
    await showAdaptiveSheet<void>(
      context: anchorContext,
      maxWidth: 400,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Cancel request'),
                subtitle: const Text('Mark as cancelled'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  try {
                    await dash.cancelPendingAppointment(a);
                    if (!anchorContext.mounted) return;
                    ScaffoldMessenger.of(anchorContext).showSnackBar(
                      const SnackBar(content: Text('Request cancelled.')),
                    );
                  } catch (e) {
                    if (!anchorContext.mounted) return;
                    ScaffoldMessenger.of(anchorContext).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_repeat),
                title: const Text('Reschedule…'),
                subtitle: const Text('Pick a new time (status: Rescheduled)'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await _pickReschedule(anchorContext, a);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickReschedule(BuildContext context, ApiAppointment a) async {
    final now = DateTime.now();
    final initial = a.scheduledAtUtc.toLocal();
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null || !context.mounted) return;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (t == null || !context.mounted) return;

    final local = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    try {
      await dash.reschedulePendingAppointment(a, local.toUtc());
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment rescheduled.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}

class _LiveFeedPanel extends StatelessWidget {
  const _LiveFeedPanel({required this.dash});

  final ReceptionDashboardController dash;

  @override
  Widget build(BuildContext context) {
    final items = dash.feedItems;

    return RefreshIndicator(
      onRefresh: () => dash.refresh(),
      child: items.isEmpty
          ? ListView(
              padding: Responsive.screenPadding(context),
              children: [
                const SizedBox(height: 24),
                Text('Live activity', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Bookings and updates from your clinic timeline will appear here. '
                  'Include words like "arrived" in appointment notes to log check-ins.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                if (dash.loading) const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            )
          : ListView.builder(
              padding: Responsive.screenPadding(context),
              itemCount: items.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('Live activity', style: Theme.of(context).textTheme.titleLarge),
                  );
                }
                final e = items[i - 1];
                final time = formatAppointmentTimeHm(e.timestampUtc);
                return Card(
                  child: ListTile(
                    leading: Icon(e.icon, color: const Color(0xFF004D40)),
                    title: Text(e.headline),
                    subtitle: Text('$time · ${e.detail}'),
                  ),
                );
              },
            ),
    );
  }
}
