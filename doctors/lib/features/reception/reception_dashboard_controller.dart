import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/formatting/appointment_time_display.dart';
import '../../core/models/backend_models.dart';
import '../../core/network/backend_api_client.dart';

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
  ReceptionDashboardController() {
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(refreshQuiet());
    });
  }

  List<ApiAppointment> _appointments = [];
  List<Map<String, dynamic>> _notifications = [];
  bool loading = false;
  String? lastError;
  Timer? _pollTimer;

  /// Emits [pendingAppointments.length] after each appointment fetch (including the 30s poll).
  final StreamController<int> _pendingCountController = StreamController<int>.broadcast();

  /// Use with [StreamBuilder] for header/sidebar badges; updates whenever appointments are reloaded.
  Stream<int> get pendingAppointmentCountStream => _pendingCountController.stream;

  void _emitPendingCount() {
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(pendingAppointments.length);
    }
  }

  List<ApiAppointment> get appointments => List.unmodifiable(_appointments);

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

      final notes = (a.notes ?? '').toLowerCase();
      if (notes.contains('arrived') || notes.contains('checked in')) {
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

  Future<void> _loadAppointments() async {
    final raw = await BackendApiClient.instance.getAppointments();
    _appointments = raw.map(ApiAppointment.fromJson).toList()
      ..sort((a, b) => a.scheduledAtUtc.compareTo(b.scheduledAtUtc));
    _emitPendingCount();
  }

  Future<void> _loadNotifications() async {
    _notifications = await BackendApiClient.instance.getNotifications();
  }

  /// Applies server row after PUT so the Pending list updates before the next GET finishes.
  void _upsertAppointment(ApiAppointment updated) {
    final i = _appointments.indexWhere((x) => x.id == updated.id);
    final next = List<ApiAppointment>.from(_appointments);
    if (i >= 0) {
      next[i] = updated;
    } else {
      next.add(updated);
    }
    next.sort((a, b) => a.scheduledAtUtc.compareTo(b.scheduledAtUtc));
    _appointments = next;
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
    );
    await refreshQuiet();
  }

  /// Maps to API `AppointmentStatus.Approved` (confirmed booking).
  /// [scheduledAtUtc] overrides the list row time when reception changed the slot.
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
      );
      _upsertAppointment(updated);
      await refreshQuiet();
    } finally {
      _busyAppointmentId = null;
      notifyListeners();
    }
  }

  Future<void> cancelPendingAppointment(ApiAppointment a) async {
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
      );
      _upsertAppointment(updated);
      await refreshQuiet();
    } finally {
      _busyAppointmentId = null;
      notifyListeners();
    }
  }

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
      );
      _upsertAppointment(updated);
      await refreshQuiet();
    } finally {
      _busyAppointmentId = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pendingCountController.close();
    super.dispose();
  }
}
