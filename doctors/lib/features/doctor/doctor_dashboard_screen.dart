import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/appointments/appointment_paged_live_controller.dart';
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
  final ScrollController _scroll = ScrollController();

  late final AppointmentPagedLiveController _live;

  /// Called from the dashboard app bar refresh action (reloads first page only — no polling).
  Future<void> reload() async => _live.loadFirstPage();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    final from = _utcStartOfLocalToday();
    final to = _utcEndOfLocalToday();
    _live = AppointmentPagedLiveController(
      pageSize: 10,
      scheduledFromUtc: from,
      scheduledToUtc: to,
      fetchPage: (page, size) async {
        var did = SessionManager.instance.doctorId;
        if (did == null) {
          final me = await BackendApiClient.instance.getDoctorMe();
          SessionManager.instance.applyDoctorMe(me);
          did = _parseDoctorId(me['id']);
        }
        if (did == null) {
          throw StateError('Doctor id not available. Sign in again.');
        }
        return BackendApiClient.instance.getAppointmentsPage(
          doctorId: did,
          pageNumber: page,
          pageSize: size,
          scheduledFromUtc: from,
          scheduledToUtc: to,
        );
      },
      subscribeHub: (hub) async {
        var cid = SessionManager.instance.doctorClinicId;
        if (cid == null) {
          final me = await BackendApiClient.instance.getDoctorMe();
          SessionManager.instance.applyDoctorMe(me);
          cid = SessionManager.instance.doctorClinicId;
        }
        if (cid == null) {
          throw StateError('Clinic id not available for SignalR.');
        }
        await hub.invoke('SubscribeDoctorClinic', args: <Object>[cid]);
      },
    );
    _scroll.addListener(_onScroll);
    unawaited(_live.start());
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    unawaited(_live.dispose());
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels < pos.maxScrollExtent - 320) return;
    unawaited(_live.loadMore());
  }

  static DateTime _utcStartOfLocalToday() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).toUtc();
  }

  static DateTime _utcEndOfLocalToday() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).add(const Duration(days: 1)).toUtc();
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

  /// Today: pending, confirmed (approved), or live (in progress). Client-side sort: closest time first.
  List<ApiAppointment> _todayActiveQueueFrom(List<ApiAppointment> all) {
    final now = DateTime.now();
    return all.where((a) {
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

  List<ApiAppointment> _filteredQueue(List<ApiAppointment> all) {
    final q = _search.text.trim().toLowerCase();
    final digits = q.replaceAll(RegExp(r'\D'), '');
    final base = _todayActiveQueueFrom(all)
      ..sort((a, b) => a.scheduledAtUtc.compareTo(b.scheduledAtUtc));
    return base.where((a) {
      if (q.isEmpty) return true;
      if (a.patientName.toLowerCase().contains(q)) return true;
      final phoneNorm = a.phoneNumber.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty && phoneNorm.contains(digits)) return true;
      return false;
    }).toList();
  }

  ApiAppointment? _nextPatientFrom(List<ApiAppointment> filtered) {
    final sorted = filtered.toList()
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
      await Navigator.of(context).push<bool>(
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
    final padding = Responsive.screenPadding(context);

    return StreamBuilder<AppointmentPagedLiveState>(
      stream: _live.stream,
      initialData: _live.lastState,
      builder: (context, snapshot) {
        final state = snapshot.data!;
        if (state.isLoading && state.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.error != null && state.items.isEmpty) {
          return Center(
            child: Padding(
              padding: padding,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => _live.loadFirstPage(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final filtered = _filteredQueue(state.items);
        final next = _nextPatientFrom(filtered);

        return RefreshIndicator(
          onRefresh: () => _live.loadFirstPage(),
          child: ListView(
            controller: _scroll,
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
                        if (next.doctorNotes != null && next.doctorNotes!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2F1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF004D40).withValues(alpha: 0.25)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Doctor notes',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: const Color(0xFF004D40),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(next.doctorNotes!, style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        ],
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
                'Today\'s queue (${filtered.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Closest time first. Updates live via SignalR; scroll down to load more rows.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
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
                ...filtered.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${formatAppointmentDateTimeLine(a.scheduledAtUtc)}\n'
                              '${a.phoneNumber}\n'
                              '${_queueStatusLabel(a)}',
                            ),
                            if (a.doctorNotes != null && a.doctorNotes!.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Doctor notes: ${a.doctorNotes!}',
                                  style: const TextStyle(
                                    color: Color(0xFF004D40),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openSession(a),
                      ),
                    ),
                  ),
                ),
              if (state.isLoadingMore)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (state.hasMore && !state.isLoadingMore)
                const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Center(
                    child: Text(
                      'Scroll for more…',
                      style: TextStyle(color: Color(0xFF888888)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
