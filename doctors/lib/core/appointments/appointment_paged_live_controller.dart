import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../models/backend_models.dart';
import '../network/api_service.dart';
import '../network/session_manager.dart';

/// Snapshot for [StreamBuilder] + infinite scroll (closest time first via [_sort]).
class AppointmentPagedLiveState {
  const AppointmentPagedLiveState({
    required this.items,
    required this.totalCount,
    required this.pageNumber,
    required this.hasMore,
    required this.isLoading,
    required this.isLoadingMore,
    this.error,
  });

  final List<ApiAppointment> items;
  final int totalCount;
  final int pageNumber;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
}

/// Offset-paged list + SignalR merge (no polling). Sorts by [ApiAppointment.scheduledAtUtc] ascending after each change.
class AppointmentPagedLiveController {
  AppointmentPagedLiveController({
    required this.fetchPage,
    required this.subscribeHub,
    this.pageSize = 10,
    this.scheduledFromUtc,
    this.scheduledToUtc,
  }) {
    lastState = AppointmentPagedLiveState(
      items: const [],
      totalCount: 0,
      pageNumber: 0,
      hasMore: true,
      isLoading: true,
      isLoadingMore: false,
    );
    _stream.add(lastState);
  }

  final Future<PagedAppointments> Function(int pageNumber, int pageSize) fetchPage;
  final Future<void> Function(HubConnection hub) subscribeHub;
  final int pageSize;
  final DateTime? scheduledFromUtc;
  final DateTime? scheduledToUtc;

  final List<ApiAppointment> _items = [];
  final StreamController<AppointmentPagedLiveState> _stream =
      StreamController<AppointmentPagedLiveState>.broadcast();

  Stream<AppointmentPagedLiveState> get stream => _stream.stream;
  late AppointmentPagedLiveState lastState;

  HubConnection? _hub;
  int _page = 0;
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  bool _started = false;

  bool get _hasMore => _items.length < _total;

  bool _inWindow(ApiAppointment a) {
    final t = a.scheduledAtUtc;
    if (scheduledFromUtc != null && t.isBefore(scheduledFromUtc!)) return false;
    if (scheduledToUtc != null && !t.isBefore(scheduledToUtc!)) return false;
    return true;
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await loadFirstPage();
    await _connectHub();
  }

  Future<void> loadFirstPage() async {
    _page = 0;
    _items.clear();
    _loading = true;
    _error = null;
    _emit();
    try {
      final p = await fetchPage(1, pageSize);
      _page = 1;
      _total = p.totalCount;
      _mergePage(p.items);
      _sort();
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    _emit();
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    _loadingMore = true;
    _emit();
    try {
      final next = _page + 1;
      final p = await fetchPage(next, pageSize);
      _page = next;
      _total = p.totalCount;
      _mergePage(p.items);
      _sort();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loadingMore = false;
    _emit();
  }

  void _mergePage(List<ApiAppointment> chunk) {
    for (final a in chunk) {
      final i = _items.indexWhere((x) => x.id == a.id);
      if (i >= 0) {
        _items[i] = a;
      } else {
        _items.add(a);
      }
    }
  }

  void _sort() {
    _items.sort((a, b) => a.scheduledAtUtc.compareTo(b.scheduledAtUtc));
  }

  void applyPayload(AppointmentChangePayload payload) {
    if (payload.deleted && payload.id != null) {
      _items.removeWhere((a) => a.id == payload.id);
      _emit();
      return;
    }
    final ap = payload.appointment;
    if (ap == null) return;
    if (!_inWindow(ap)) {
      _items.removeWhere((x) => x.id == ap.id);
      _emit();
      return;
    }
    final i = _items.indexWhere((x) => x.id == ap.id);
    if (i >= 0) {
      _items[i] = ap;
    } else {
      _items.add(ap);
    }
    _sort();
    _emit();
  }

  Future<void> _connectHub() async {
    ApiService.instance.syncAuthorizationHeaderFromSession();
    final token = SessionManager.instance.token;
    final url = ApiService.instance.signalRHubUrl;
    final options = HttpConnectionOptions(
      accessTokenFactory: () async => token ?? '',
    );
    final hub = HubConnectionBuilder().withUrl(url, options: options).build();
    hub.on('AppointmentChanged', (List<Object?>? args) {
      final map = _parseFirstArg(args);
      if (map == null) return;
      applyPayload(AppointmentChangePayload.fromJson(map));
    });
    await hub.start();
    await subscribeHub(hub);
    _hub = hub;
  }

  Map<String, dynamic>? _parseFirstArg(List<Object?>? args) {
    if (args == null || args.isEmpty) return null;
    final f = args.first;
    if (f is Map) return Map<String, dynamic>.from(f);
    return null;
  }

  void _emit() {
    lastState = AppointmentPagedLiveState(
      items: List<ApiAppointment>.unmodifiable(_items),
      totalCount: _total,
      pageNumber: _page,
      hasMore: _hasMore,
      isLoading: _loading,
      isLoadingMore: _loadingMore,
      error: _error,
    );
    if (!_stream.isClosed) {
      _stream.add(lastState);
    }
  }

  Future<void> dispose() async {
    try {
      await _hub?.stop();
    } catch (_) {}
    _hub = null;
    await _stream.close();
  }
}
