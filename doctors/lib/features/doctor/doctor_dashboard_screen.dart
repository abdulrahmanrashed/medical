import 'package:flutter/material.dart';

import '../../core/enums/doctor_specialization.dart';
import '../../core/formatting/appointment_time_display.dart';
import '../../core/layout/responsive.dart';
import '../../core/models/backend_models.dart';
import '../../core/network/backend_api_client.dart';
import '../../core/network/session_manager.dart';
import 'doctor_patient_session_screen.dart';
import 'patient_archive_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GlobalKey<DoctorTodayAppointmentsTabState> _todayKey = GlobalKey();
  final GlobalKey<PatientArchiveScreenState> _archiveKey = GlobalKey();

  DoctorSpecialization get _specialization =>
      SessionManager.instance.doctorSpecialization ?? DoctorSpecialization.other;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onRefreshPressed() async {
    if (_tabController.index == 0) {
      await _todayKey.currentState?.reload();
    } else {
      await _archiveKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = _specialization;
    return Scaffold(
      appBar: AppBar(
        title: Text('Doctor · ${spec.label}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _onRefreshPressed,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Today's appointments"),
            Tab(text: 'Patient archive'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          DoctorTodayAppointmentsTab(
            key: _todayKey,
            specialization: spec,
          ),
          PatientArchiveScreen(
            key: _archiveKey,
            specialization: spec,
          ),
        ],
      ),
    );
  }
}

/// Pending + approved (confirmed) appointments scheduled for the current local calendar day only.
class DoctorTodayAppointmentsTab extends StatefulWidget {
  const DoctorTodayAppointmentsTab({super.key, required this.specialization});

  final DoctorSpecialization specialization;

  @override
  State<DoctorTodayAppointmentsTab> createState() => DoctorTodayAppointmentsTabState();
}

class DoctorTodayAppointmentsTabState extends State<DoctorTodayAppointmentsTab> {
  final TextEditingController _search = TextEditingController();

  List<ApiAppointment> _all = [];
  List<ApiAppointment> _filtered = [];
  bool _loading = true;
  String? _error;

  /// Called from the dashboard app bar refresh action.
  Future<void> reload() async => _load();

  @override
  void initState() {
    super.initState();
    _search.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _search.removeListener(_applyFilter);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var did = SessionManager.instance.doctorId;
      if (did == null || SessionManager.instance.doctorSpecialization == null) {
        final me = await BackendApiClient.instance.getDoctorMe();
        SessionManager.instance.applyDoctorMe(me);
        did = _parseDoctorId(me['id']) ?? did;
      }
      if (did == null) {
        throw StateError('Doctor id not available. Sign in again.');
      }
      final raw = await BackendApiClient.instance.getAppointments(doctorId: did);
      final list = raw.map(ApiAppointment.fromJson).toList(growable: false);
      list.sort((a, b) => a.scheduledAtUtc.compareTo(b.scheduledAtUtc));
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int? _parseDoctorId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static bool _isSameLocalCalendarDay(DateTime utc, DateTime nowLocal) {
    final local = utc.toLocal();
    return local.year == nowLocal.year &&
        local.month == nowLocal.month &&
        local.day == nowLocal.day;
  }

  /// Today: pending, confirmed (approved), or live (in progress). Hides completed / cancelled / rescheduled.
  List<ApiAppointment> _todayActiveQueue() {
    final now = DateTime.now();
    return _all.where((a) {
      if (!_isSameLocalCalendarDay(a.scheduledAtUtc, now)) return false;
      return a.status == ApiAppointmentStatus.pending ||
          a.status == ApiAppointmentStatus.approved ||
          a.status == ApiAppointmentStatus.inProgress;
    }).toList();
  }

  static String _queueStatusLabel(ApiAppointment a) {
    return switch (a.status) {
      ApiAppointmentStatus.inProgress => 'Live — session in progress',
      ApiAppointmentStatus.pending => 'Pending',
      ApiAppointmentStatus.approved => 'Confirmed',
      _ => a.status.name,
    };
  }

  void _applyFilter() {
    final q = _search.text.trim().toLowerCase();
    final digits = q.replaceAll(RegExp(r'\D'), '');
    final base = _todayActiveQueue()..sort((a, b) => a.scheduledAtUtc.compareTo(b.scheduledAtUtc));
    setState(() {
      _filtered = base.where((a) {
        if (q.isEmpty) return true;
        if (a.patientName.toLowerCase().contains(q)) return true;
        final phoneNorm = a.phoneNumber.replaceAll(RegExp(r'\D'), '');
        if (digits.isNotEmpty && phoneNorm.contains(digits)) return true;
        return false;
      }).toList();
    });
  }

  ApiAppointment? _nextPatient() {
    final sorted = _filtered.toList()
      ..sort((a, b) => a.scheduledAtUtc.compareTo(b.scheduledAtUtc));
    if (sorted.isEmpty) return null;
    final live = sorted.where((x) => x.status == ApiAppointmentStatus.inProgress).toList();
    if (live.isNotEmpty) return live.first;
    return sorted.first;
  }

  Future<void> _openSession(ApiAppointment a) async {
    try {
      ApiAppointment toOpen = a;
      if (a.id > 0 &&
          a.status != ApiAppointmentStatus.inProgress &&
          a.status != ApiAppointmentStatus.completed) {
        toOpen = await BackendApiClient.instance.patchDoctorAppointmentStatus(
          appointmentId: a.id,
          status: ApiAppointmentStatus.inProgress,
        );
      }
      if (!mounted) return;
      final ended = await Navigator.of(context).push<bool>(
        PageRouteBuilder<bool>(
          pageBuilder: (context, animation, secondaryAnimation) => DoctorPatientSessionScreen(
            appointment: toOpen,
            specialization: widget.specialization,
            readOnly: false,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              child: child,
            );
          },
        ),
      );
      if (mounted && ended == true) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update or open session: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextPatient();
    final padding = Responsive.screenPadding(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: padding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search by name or phone',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            textInputAction: TextInputAction.search,
          ),
          const SizedBox(height: 16),
          if (next != null) ...[
            Text(
              'Next patient',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: next.status == ApiAppointmentStatus.inProgress
                    ? const BorderSide(color: Color(0xFF004D40), width: 2)
                    : BorderSide.none,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (next.status == ApiAppointmentStatus.inProgress)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Chip(
                          label: const Text('Live'),
                          avatar: Icon(Icons.fiber_manual_record, size: 14, color: Colors.red.shade700),
                          backgroundColor: const Color(0xFF004D40).withValues(alpha: 0.12),
                          labelStyle: const TextStyle(
                            color: Color(0xFF004D40),
                            fontWeight: FontWeight.w800,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    Text(
                      next.patientName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      next.phoneNumber,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatAppointmentDateTimeLine(next.scheduledAtUtc),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _queueStatusLabel(next),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF004D40),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _openSession(next),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF004D40),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          next.status == ApiAppointmentStatus.inProgress
                              ? 'Continue session'
                              : 'Start session',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            'Today\'s queue (${_filtered.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pending, confirmed, or live visits for today. Completed sessions leave this list after you tap End session.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                _search.text.isEmpty
                    ? 'No appointments in your queue for today.'
                    : 'No matches for this search.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          else
            ..._filtered.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: a.status == ApiAppointmentStatus.inProgress
                        ? const BorderSide(color: Color(0xFF004D40), width: 1.5)
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    title: Row(
                      children: [
                        Expanded(child: Text(a.patientName)),
                        if (a.status == ApiAppointmentStatus.inProgress)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF004D40).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Live',
                              style: TextStyle(
                                color: Color(0xFF004D40),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${formatAppointmentDateTimeLine(a.scheduledAtUtc)}\n'
                      '${a.phoneNumber}\n'
                      '${_queueStatusLabel(a)}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openSession(a),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
