import 'package:flutter/material.dart';
import 'dart:async';

import 'package:url_launcher/url_launcher.dart';

import '../../core/formatting/appointment_time_display.dart';
import '../../core/layout/responsive.dart';
import '../../core/models/backend_models.dart';
import '../../core/models/clinic_summary.dart';
import '../../core/network/backend_api_client.dart';
import 'patient_booking_flow_screen.dart';

class PatientShellScreen extends StatefulWidget {
  const PatientShellScreen({super.key});

  @override
  State<PatientShellScreen> createState() => _PatientShellScreenState();
}

class _PatientShellScreenState extends State<PatientShellScreen> {
  int _index = 0;
  Duration? _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadNextAppointmentCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadNextAppointmentCountdown() async {
    try {
      final raw = await BackendApiClient.instance.getAppointments();
      final appointments = raw.map(ApiAppointment.fromJson).toList();
      final now = DateTime.now().toUtc();
      final upcoming = appointments
          .map((a) => a.scheduledAtUtc)
          .where((d) => d.isAfter(now))
          .toList()
        ..sort();
      if (upcoming.isEmpty) return;
      final next = upcoming.first;

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final diff = next.difference(DateTime.now().toUtc());
        if (!mounted) return;
        setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
      });
    } catch (_) {
      // keep UI alive even if API fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = Responsive.isTablet(constraints.maxWidth);
        return Scaffold(
          appBar: AppBar(
            title: Text(switch (_index) {
              0 => 'Home',
              1 => 'Medical records',
              _ => 'My appointments',
            }),
          ),
          body: isTablet
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _index,
                      onDestinationSelected: (i) => setState(() => _index = i),
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.local_hospital_outlined),
                          label: Text('Clinics'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.folder_open_outlined),
                          label: Text('Records'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.event_note_outlined),
                          label: Text('My appointments'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: _stack()),
                  ],
                )
              : _stack(),
          bottomNavigationBar: isTablet
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.local_hospital_outlined),
                      selectedIcon: Icon(Icons.local_hospital),
                      label: 'Clinics',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.folder_open_outlined),
                      selectedIcon: Icon(Icons.folder_open),
                      label: 'Records',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.event_note_outlined),
                      selectedIcon: Icon(Icons.event_note),
                      label: 'My appointments',
                    ),
                  ],
                ),
          floatingActionButton: _remaining == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => setState(() => _index = 2),
                  backgroundColor: const Color(0xFF008080),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.timer_outlined),
                  label: Text('Next in ${_formatDuration(_remaining!)}'),
                ),
        );
      },
    );
  }

  Widget _stack() {
    return IndexedStack(
      index: _index,
      children: const [
        _ClinicsTab(),
        _RecordsTab(),
        _AppointmentsTab(),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _ClinicsTab extends StatefulWidget {
  const _ClinicsTab();

  @override
  State<_ClinicsTab> createState() => _ClinicsTabState();
}

class _ClinicsTabState extends State<_ClinicsTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = BackendApiClient.instance.getClinics();
  }

  Future<void> _reload() async {
    setState(() => _future = BackendApiClient.instance.getClinics());
    await _future;
  }

  void _openBooking(BuildContext context, {ClinicSummary? clinic}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PatientBookingFlowScreen(initialClinic: clinic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.screenPadding(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = Responsive.isTablet(constraints.maxWidth);
        return RefreshIndicator(
          onRefresh: _reload,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: padding,
                  children: [
                    Text('Could not load clinics: ${snap.error}'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _reload, child: const Text('Retry')),
                  ],
                );
              }
              final raw = snap.data ?? const <Map<String, dynamic>>[];
              final clinics =
                  raw.map(ClinicSummary.fromApiClinic).toList(growable: false);

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: padding,
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Text(
                          'Your clinics',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontSize: Responsive.titleSize(context),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Live directory from your care network. Contact details come from the clinic.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          onPressed: () => _openBooking(context),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Book a visit (pick clinic in flow)'),
                        ),
                        const SizedBox(height: 20),
                      ]),
                    ),
                  ),
                  if (isTablet)
                    SliverPadding(
                      padding: padding.copyWith(top: 0),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.05,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final clinic = clinics[index];
                            return _PatientClinicCard(
                              clinic: clinic,
                              onBook: () => _openBooking(context, clinic: clinic),
                            );
                          },
                          childCount: clinics.length,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: padding.copyWith(top: 0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final clinic = clinics[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PatientClinicCard(
                                clinic: clinic,
                                onBook: () => _openBooking(context, clinic: clinic),
                              ),
                            );
                          },
                          childCount: clinics.length,
                        ),
                      ),
                    ),
                  if (clinics.isEmpty)
                    SliverPadding(
                      padding: padding,
                      sliver: const SliverToBoxAdapter(
                        child: Text('No clinics available yet.'),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _PatientClinicCard extends StatelessWidget {
  const _PatientClinicCard({
    required this.clinic,
    required this.onBook,
  });

  final ClinicSummary clinic;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF004D40).withValues(alpha: 0.12),
                      foregroundColor: const Color(0xFF004D40),
                      child: const Icon(Icons.local_hospital),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        clinic.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                if (clinic.address != null && clinic.address!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.place_outlined,
                          size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(child: Text(clinic.address!)),
                    ],
                  ),
                ],
                if (clinic.phone != null && clinic.phone!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined,
                          size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(clinic.phone!),
                    ],
                  ),
                ],
                if (clinic.email != null && clinic.email!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.email_outlined,
                          size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(child: Text(clinic.email!)),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  '${clinic.doctorCount ?? 0} doctors on staff',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF004D40),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40),
                ),
                onPressed: onBook,
                child: const Text('Request appointment'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsTab extends StatefulWidget {
  const _RecordsTab();

  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  late Future<List<ApiMedicalRecordDetail>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ApiMedicalRecordDetail>> _load() async {
    final raw = await BackendApiClient.instance.getMedicalRecords();
    final list = raw
        .map((e) => ApiMedicalRecordDetail.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    list.sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    return list;
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _openFile(ApiFileAttachment a) async {
    final url = BackendApiClient.instance.attachmentUrl(a);
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open file')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.screenPadding(context);
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<ApiMedicalRecordDetail>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
                const Center(child: CircularProgressIndicator()),
              ],
            );
          }
          if (snap.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              children: [
                Text('Could not load history: ${snap.error}'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _reload, child: const Text('Retry')),
              ],
            );
          }
          final items = snap.data ?? const <ApiMedicalRecordDetail>[];
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            children: [
              Text(
                'My Records',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: Responsive.titleSize(context),
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Visits, prescriptions, and files from your doctors.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'No records yet.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              else
                for (final r in items) ...[
                  Card(
                    child: ExpansionTile(
                      leading: const Icon(Icons.folder_shared_outlined),
                      title: Text(
                        r.diagnosis != null && r.diagnosis!.trim().isNotEmpty
                            ? r.diagnosis!.trim()
                            : 'Clinical visit',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${r.doctorName}\n${formatAppointmentDateTimeLine(r.createdAtUtc)}',
                      ),
                      children: [
                        if (r.symptoms != null && r.symptoms!.trim().isNotEmpty)
                          ListTile(
                            title: const Text('Symptoms'),
                            subtitle: Text(r.symptoms!),
                          ),
                        if (r.diagnosis != null && r.diagnosis!.trim().isNotEmpty)
                          ListTile(
                            title: const Text('Diagnosis'),
                            subtitle: Text(r.diagnosis!),
                          ),
                        if (r.notes != null && r.notes!.trim().isNotEmpty)
                          ListTile(
                            title: const Text('Notes'),
                            subtitle: Text(r.notes!),
                          ),
                        for (final p in r.prescriptions)
                          for (final m in p.medications)
                            ListTile(
                              leading: const Icon(Icons.medication_outlined),
                              title: Text(m.name),
                              subtitle: Text(
                                '${m.dosage} · ${m.schedule}'
                                '${m.instructions != null && m.instructions!.isNotEmpty ? '\n${m.instructions}' : ''}',
                              ),
                              isThreeLine: m.instructions != null && m.instructions!.isNotEmpty,
                            ),
                        for (final f in r.attachments)
                          ListTile(
                            leading: Icon(
                              f.contentType.contains('pdf') ||
                                      f.originalFileName.toLowerCase().endsWith('.pdf')
                                  ? Icons.picture_as_pdf
                                  : Icons.image_outlined,
                            ),
                            title: Text(f.originalFileName),
                            subtitle: const Text('Tap to open'),
                            trailing: const Icon(Icons.open_in_new),
                            onTap: () => _openFile(f),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _AppointmentsTab extends StatefulWidget {
  const _AppointmentsTab();

  @override
  State<_AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<_AppointmentsTab> {
  late Future<List<ApiAppointment>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAppointments();
  }

  Future<List<ApiAppointment>> _loadAppointments() async {
    final raw = await BackendApiClient.instance.getAppointments();
    final list = raw.map(ApiAppointment.fromJson).toList(growable: false);
    list.sort((a, b) => a.scheduledAtUtc.compareTo(b.scheduledAtUtc));
    return list;
  }

  Future<void> _reload() async {
    setState(() => _future = _loadAppointments());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.screenPadding(context);
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<ApiAppointment>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              children: [
                Text('Could not load appointments: ${snap.error}'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _reload, child: const Text('Retry')),
              ],
            );
          }
          final items = snap.data ?? const <ApiAppointment>[];
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            children: [
              Text(
                'My Appointments',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: Responsive.titleSize(context),
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pending requests need clinic approval. Confirmed visits show a green check.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              if (items.isEmpty)
                Text(
                  'No appointments yet. Book a visit from the Clinics tab.',
                  style: Theme.of(context).textTheme.bodyLarge,
                )
              else
                ...items.map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PatientAppointmentCard(appointment: a),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _PatientAppointmentCard extends StatelessWidget {
  const _PatientAppointmentCard({required this.appointment});

  final ApiAppointment appointment;

  static String _doctorLine(ApiAppointment a) {
    final n = a.doctorName?.trim();
    if (n != null && n.isNotEmpty) return n;
    if (a.type == ApiAppointmentType.general) {
      return 'Any available doctor';
    }
    return 'Doctor to be assigned';
  }

  static String _clinicLine(ApiAppointment a) {
    final n = a.clinicName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Clinic #${a.clinicId}';
  }

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: switch (a.status) {
              ApiAppointmentStatus.pending => Colors.orange.shade50,
              ApiAppointmentStatus.approved => Colors.green.shade50,
              ApiAppointmentStatus.inProgress => Colors.teal.shade50,
              ApiAppointmentStatus.cancelled => theme.colorScheme.errorContainer.withValues(alpha: 0.35),
              _ => theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            },
            child: _StatusLabel(status: a.status),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(
                  icon: Icons.person_outline,
                  label: 'Doctor',
                  value: _doctorLine(a),
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  icon: Icons.local_hospital_outlined,
                  label: 'Clinic',
                  value: _clinicLine(a),
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: formatAppointmentDateIso(a.scheduledAtUtc),
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  icon: Icons.schedule,
                  label: 'Time',
                  value: formatAppointmentTimeHm(a.scheduledAtUtc),
                ),
                if (a.type == ApiAppointmentType.specificDoctor) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Specific doctor visit',
                    style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final ApiAppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      ApiAppointmentStatus.pending => Row(
          children: [
            Icon(Icons.hourglass_top_rounded, color: Colors.orange.shade800, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Waiting for Clinic Approval',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ApiAppointmentStatus.approved => Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
            const SizedBox(width: 10),
            Text(
              'Confirmed',
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ApiAppointmentStatus.inProgress => Row(
          children: [
            Icon(Icons.local_hospital_outlined, color: Colors.teal.shade800, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Visit in progress',
                style: TextStyle(
                  color: Colors.teal.shade900,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ApiAppointmentStatus.rescheduled => Row(
          children: [
            Icon(Icons.update, color: Colors.blue.shade700, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Rescheduled',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ],
        ),
      ApiAppointmentStatus.cancelled => Row(
          children: [
            Icon(Icons.cancel_outlined, color: Theme.of(context).colorScheme.error, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Cancelled',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ],
        ),
      ApiAppointmentStatus.completed => Row(
          children: [
            Icon(Icons.verified_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Completed',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ],
        ),
    };
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: muted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: muted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
