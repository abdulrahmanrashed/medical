import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/formatting/appointment_time_display.dart';
import '../../core/models/backend_models.dart';
import '../../core/network/api_service.dart';
import '../../core/network/backend_api_client.dart';
import '../../core/network/session_manager.dart';
import 'package:signalr_netcore/signalr_client.dart';

/// Single activity line for the reception live feed (appointments + notifications).
class ReceptionFeedItem {
  const ReceptionFeedItem({
    required this.timestampUtc,
    required this.headline,
    required this.detail,
    this.icon = Icons.notifications_active_outlined,
  });

  final DateTime timestampUtc;
  final String headline;
  final String detail;
  final IconData icon;
}

/// Keeps reception timeline, live feed, and booking flows in sync with the API.
class ReceptionDashboardController extends ChangeNotifier {
  ReceptionDashboardController();

  List<ApiAppointment> _appointments = [];
  List<Map<String, dynamic>> _notifications = [];
  bool loading = false;
  String? lastError;
  Timer? _graceTimer;
  HubConnection? _hub;

  /// When an appointment becomes [ApiAppointmentStatus.completed], it stays visible this long before dropping off the active list.
  final Map<int, DateTime> _completedGraceUntil = {};

  /// Emits [pendingAppointments.length] after each appointment fetch (including poll).
  final StreamController<int> _pendingCountController = StreamController<int>.broadcast();

  /// Use with [StreamBuilder] for header/sidebar badges; updates whenever appointments are reloaded.
  Stream<int> get pendingAppointmentCountStream => _pendingCountController.stream;

  void _emitPendingCount() {
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(pendingAppointments.length);
    }
  }

  List<ApiAppointment> get appointments => List.unmodifiable(_appointments);

  /// Active timeline: non-cancelled rows; completed only during a short grace after the doctor ends the session.
  List<ApiAppointment> get activeAppointmentsForTimeline {
    final now = DateTime.now();
    final list = _appointments.where((a) {
      if (a.status == ApiAppointmentStatus.cancelled) return false;
      if (a.status == ApiAppointmentStatus.completed) {
        final until = _completedGraceUntil[a.id];
        return until != null && now.isBefore(until);
      }
      return true;
    }).toList();
    list.sort((a, b) => a.scheduledAtUtc.compareTo(b.scheduledAtUtc));
    return list;
  }

  /// Patient-submitted bookings awaiting staff action (`Pending` in API).
  List<ApiAppointment> get pendingAppointments {
    final list = _appointments
        .where((a) => a.status == ApiAppointmentStatus.pending)
        .toList(growable: false);
    list.sort((a, b) => a.scheduledAtUtc.compareTo(b.scheduledAtUtc));
    return list;
  }

  int? _busyAppointmentId;
  int? get busyAppointmentId => _busyAppointmentId;

  List<ReceptionFeedItem> get feedItems {
    final items = <ReceptionFeedItem>[];

    for (final n in _notifications) {
      final ts = DateTime.tryParse(n['createdAtUtc']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      items.add(
        ReceptionFeedItem(
          timestampUtc: ts,
          headline: n['title']?.toString() ?? 'Notification',
          detail: n['message']?.toString() ?? '',
          icon: Icons.notifications_outlined,
        ),
      );
    }

    for (final a in _appointments) {
      final created = a.createdAtUtc ?? a.scheduledAtUtc;
      items.add(
        ReceptionFeedItem(
          timestampUtc: created,
          headline: 'New booking',
          detail: '${a.patientName} · ${_formatWhen(a.scheduledAtUtc)}',
          icon: Icons.event_available_outlined,
        ),
      );

      final blob = '${a.notes ?? ''} ${a.receptionNotes ?? ''}'.toLowerCase();
      if (blob.contains('arrived') || blob.contains('checked in')) {
        items.add(
          ReceptionFeedItem(
            timestampUtc: a.updatedAtUtc ?? a.createdAtUtc ?? a.scheduledAtUtc,
            headline: 'Patient arrived',
            detail: a.patientName,
            icon: Icons.hail_outlined,
          ),
        );
      }

      final updated = a.updatedAtUtc;
      if (updated != null &&
          updated.isAfter(created.add(const Duration(seconds: 2))) &&
          a.status == ApiAppointmentStatus.completed) {
        items.add(
          ReceptionFeedItem(
            timestampUtc: updated,
            headline: 'Visit completed',
            detail: a.patientName,
            icon: Icons.check_circle_outline,
          ),
        );
      }
    }

    items.sort((a, b) => b.timestampUtc.compareTo(a.timestampUtc));
    return items.take(80).toList();
  }

  static String _formatWhen(DateTime utc) => formatAppointmentDateTimeLine(utc);

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    try {
      await Future.wait<void>([
        _loadAppointments(),
        _loadNotifications(),
      ]);
      lastError = null;
    } catch (e) {
      lastError = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshQuiet() async {
    try {
      await Future.wait<void>([
        _loadAppointments(),
        _loadNotifications(),
      ]);
      lastError = null;
      notifyListeners();
    } catch (_) {
      // keep last good data
    }
  }

  void _applyCompletedGraceTransition(List<ApiAppointment> before, List<ApiAppointment> after) {
    final prevMap = {for (final x in before) x.id: x};
    final now = DateTime.now();
    for (final a in after) {
      if (a.status != ApiAppointmentStatus.completed) continue;
      final prev = prevMap[a.id];
      final transitioned = prev != null && prev.status != ApiAppointmentStatus.completed;
      if (transitioned) {
        _completedGraceUntil[a.id] = now.add(const Duration(seconds: 5));
      }
    }
    _completedGraceUntil.removeWhere((id, _) => !after.any((a) => a.id == id));
  }

  void _scheduleGraceTicker() {
    _graceTimer?.cancel();
    if (!_completedGraceUntil.values.any((t) => DateTime.now().isBefore(t))) return;
    _graceTimer = Timer(const Duration(seconds: 1), () {
      notifyListeners();
      _scheduleGraceTicker();
    });
  }

  Future<void> _loadAppointments() async {
    final previous = List<ApiAppointment>.from(_appointments);
    _appointments = await BackendApiClient.instance.getAllAppointmentsAccumulated(pageSize: 40);
    _applyCompletedGraceTransition(previous, _appointments);
    _scheduleGraceTicker();
    _emitPendingCount();
    await _ensureSignalR();
  }

  Future<void> _ensureSignalR() async {
    if (_hub != null) return;
    final cid = SessionManager.instance.assignedClinicId;
    if (cid == null) return;
    ApiService.instance.syncAuthorizationHeaderFromSession();
    final options = HttpConnectionOptions(
      accessTokenFactory: () async => SessionManager.instance.token ?? '',
    );
    final hub = HubConnectionBuilder()
        .withUrl(ApiService.instance.signalRHubUrl, options: options)
        .build();
    hub.on('AppointmentChanged', (List<Object?>? args) {
      if (args == null || args.isEmpty) return;
      final f = args.first;
      if (f is! Map) return;
      final map = Map<String, dynamic>.from(f);
      final payload = AppointmentChangePayload.fromJson(map);
      _applySignalRPayload(payload);
    });
    await hub.start();
    await hub.invoke('SubscribeReceptionClinic', args: <Object>[cid]);
    _hub = hub;
  }

  void _applySignalRPayload(AppointmentChangePayload payload) {
    if (payload.deleted && payload.id != null) {
      final previous = List<ApiAppointment>.from(_appointments);
      _appointments = _appointments.where((x) => x.id != payload.id).toList();
      _applyCompletedGraceTransition(previous, _appointments);
      _emitPendingCount();
      notifyListeners();
      return;
    }
    final ap = payload.appointment;
    if (ap == null) return;
    _upsertAppointment(ap);
  }

  Future<void> _loadNotifications() async {
    _notifications = await BackendApiClient.instance.getNotifications();
  }

  /// Applies server row after PUT so lists update before the next GET finishes.
  void _upsertAppointment(ApiAppointment updated) {
    final previous = List<ApiAppointment>.from(_appointments);
    final i = _appointments.indexWhere((x) => x.id == updated.id);
    final next = List<ApiAppointment>.from(_appointments);
    if (i >= 0) {
      next[i] = updated;
    } else {
      next.add(updated);
    }
    next.sort((a, b) => a.scheduledAtUtc.compareTo(b.scheduledAtUtc));
    _appointments = next;
    _applyCompletedGraceTransition(previous, _appointments);
    _scheduleGraceTicker();
    _emitPendingCount();
    notifyListeners();
  }

  Future<ApiPatient?> lookupPatientByPhone(String phone) =>
      BackendApiClient.instance.lookupPatientByPhoneForReception(phone);

  Future<ApiPatient> ensureDraftPatient({
    required String fullName,
    required String phone,
  }) async {
    final raw = await BackendApiClient.instance.receptionFindOrCreateDraft(
      phone: phone,
      fullName: fullName,
    );
    return ApiPatient.fromJson(raw);
  }

  Future<void> createAppointment({
    required String patientId,
    required int clinicId,
    int? doctorId,
    required String patientName,
    required String phoneNumber,
    required DateTime scheduledAtUtc,
    required ApiAppointmentType type,
    String? notes,
    String? doctorNotes,
    String? receptionNotes,
  }) async {
    await BackendApiClient.instance.createAppointment(
      patientId: patientId,
      clinicId: clinicId,
      doctorId: doctorId,
      patientName: patientName,
      phoneNumber: phoneNumber,
      scheduledAtUtc: scheduledAtUtc,
      type: type.value,
      notes: notes,
      doctorNotes: doctorNotes,
      receptionNotes: receptionNotes,
    );
    await refreshQuiet();
  }

  /// Maps to API `AppointmentStatus.Approved` (confirmed booking).
  Future<void> approvePendingAppointment(
    ApiAppointment a, {
    DateTime? scheduledAtUtc,
  }) async {
    final at = scheduledAtUtc ?? a.scheduledAtUtc;
    _busyAppointmentId = a.id;
    notifyListeners();
    try {
      final updated = await BackendApiClient.instance.updateAppointment(
        id: a.id,
        patientName: a.patientName,
        phoneNumber: a.phoneNumber,
        scheduledAtUtc: at,
        type: a.type.value,
        status: ApiAppointmentStatus.approved.value,
        doctorId: a.doctorId,
        notes: a.notes,
        doctorNotes: a.doctorNotes,
        receptionNotes: a.receptionNotes,
      );
      _upsertAppointment(updated);
      await refreshQuiet();
    } finally {
      _busyAppointmentId = null;
      notifyListeners();
    }
  }

  /// Sets status to cancelled (pending, approved, etc.).
  Future<void> cancelAppointment(ApiAppointment a) async {
    if (a.status == ApiAppointmentStatus.cancelled) return;
    _busyAppointmentId = a.id;
    notifyListeners();
    try {
      final updated = await BackendApiClient.instance.updateAppointment(
        id: a.id,
        patientName: a.patientName,
        phoneNumber: a.phoneNumber,
        scheduledAtUtc: a.scheduledAtUtc,
        type: a.type.value,
        status: ApiAppointmentStatus.cancelled.value,
        doctorId: a.doctorId,
        notes: a.notes,
        doctorNotes: a.doctorNotes,
        receptionNotes: a.receptionNotes,
      );
      _upsertAppointment(updated);
      await refreshQuiet();
    } finally {
      _busyAppointmentId = null;
      notifyListeners();
    }
  }

  Future<void> cancelPendingAppointment(ApiAppointment a) => cancelAppointment(a);

  Future<void> reschedulePendingAppointment(
    ApiAppointment a,
    DateTime newScheduledUtc,
  ) async {
    _busyAppointmentId = a.id;
    notifyListeners();
    try {
      final updated = await BackendApiClient.instance.updateAppointment(
        id: a.id,
        patientName: a.patientName,
        phoneNumber: a.phoneNumber,
        scheduledAtUtc: newScheduledUtc,
        type: a.type.value,
        status: ApiAppointmentStatus.rescheduled.value,
        doctorId: a.doctorId,
        notes: a.notes,
        doctorNotes: a.doctorNotes,
        receptionNotes: a.receptionNotes,
      );
      _upsertAppointment(updated);
      await refreshQuiet();
    } finally {
      _busyAppointmentId = null;
      notifyListeners();
    }
  }

  /// Change time only; keeps current status (e.g. approved stays approved).
  Future<void> updateAppointmentTimeKeepingStatus(
    ApiAppointment a,
    DateTime newScheduledUtc,
  ) async {
    _busyAppointmentId = a.id;
    notifyListeners();
    try {
      final updated = await BackendApiClient.instance.updateAppointment(
        id: a.id,
        patientName: a.patientName,
        phoneNumber: a.phoneNumber,
        scheduledAtUtc: newScheduledUtc,
        type: a.type.value,
        status: a.status.value,
        doctorId: a.doctorId,
        notes: a.notes,
        doctorNotes: a.doctorNotes,
        receptionNotes: a.receptionNotes,
      );
      _upsertAppointment(updated);
      await refreshQuiet();
    } finally {
      _busyAppointmentId = null;
      notifyListeners();
    }
  }

  /// Hard delete (optional); use [cancelAppointment] for normal cancellation.
  Future<void> deleteAppointmentPermanently(ApiAppointment a) async {
    _busyAppointmentId = a.id;
    notifyListeners();
    try {
      await BackendApiClient.instance.deleteAppointment(a.id);
      final previous = List<ApiAppointment>.from(_appointments);
      _appointments = _appointments.where((x) => x.id != a.id).toList();
      _applyCompletedGraceTransition(previous, _appointments);
      _emitPendingCount();
      notifyListeners();
      await refreshQuiet();
    } finally {
      _busyAppointmentId = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_hub?.stop() ?? Future.value());
    _graceTimer?.cancel();
    _pendingCountController.close();
    super.dispose();
  }
}
