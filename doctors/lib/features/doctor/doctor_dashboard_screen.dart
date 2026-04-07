import 'package:flutter/material.dart';

import '../../core/enums/doctor_specialization.dart';
import '../../core/formatting/appointment_time_display.dart';
import '../../core/layout/responsive.dart';
import '../../core/models/backend_models.dart';
import '../../core/network/backend_api_client.dart';
import '../../core/network/session_manager.dart';
import 'doctor_patient_session_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key, required this.specialization});

  final DoctorSpecialization specialization;

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  final TextEditingController _search = TextEditingController();

  List<ApiAppointment> _all = [];
  List<ApiAppointment> _filtered = [];
  bool _loading = true;
  String? _error;

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
      if (did == null) {
        final me = await BackendApiClient.instance.getDoctorMe();
        did = _parseDoctorId(me['id']);
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
        _applyFilter();
        _loading = false;
      });
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

  void _applyFilter() {
    final q = _search.text.trim().toLowerCase();
    final digits = q.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _filtered = _all.where((a) {
        if (q.isEmpty) return true;
        if (a.patientName.toLowerCase().contains(q)) return true;
        final phoneNorm = a.phoneNumber.replaceAll(RegExp(r'\D'), '');
        if (digits.isNotEmpty && phoneNorm.contains(digits)) return true;
        return false;
      }).toList();
    });
  }

  ApiAppointment? _nextPatient() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final approved = _filtered.where((a) => a.status == ApiAppointmentStatus.approved).toList()
      ..sort((a, b) => a.scheduledAtUtc.compareTo(b.scheduledAtUtc));
    if (approved.isEmpty) return null;
    for (final a in approved) {
      final local = a.scheduledAtUtc.toLocal();
      if (!local.isBefore(todayStart)) {
        return a;
      }
    }
    return approved.first;
  }

  void _openSession(ApiAppointment a) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DoctorPatientSessionScreen(
          appointment: a,
          specialization: widget.specialization,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextPatient();
    final padding = Responsive.screenPadding(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Doctor · ${widget.specialization.label}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
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
                )
              : RefreshIndicator(
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
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: () => _openSession(next),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF004D40),
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Start Session'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        'Your appointments (${_filtered.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      if (_filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            _search.text.isEmpty
                                ? 'No appointments in your queue.'
                                : 'No matches for this search.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        )
                      else
                        ..._filtered.map(
                          (a) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: ListTile(
                                title: Text(a.patientName),
                                subtitle: Text(
                                  '${formatAppointmentDateTimeLine(a.scheduledAtUtc)}\n${a.phoneNumber}\n${a.status.name}',
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
                ),
    );
  }
}
