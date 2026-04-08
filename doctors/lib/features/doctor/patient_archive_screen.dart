import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/enums/doctor_specialization.dart';
import '../../core/layout/responsive.dart';
import '../../core/models/backend_models.dart';
import '../../core/network/backend_api_client.dart';
import '../../core/network/session_manager.dart';
import 'doctor_patient_session_screen.dart';

/// One row in the archive: patients this doctor has visit records for.
class ArchivePatientEntry {
  const ArchivePatientEntry({
    required this.patientId,
    required this.patientName,
    required this.phoneNumber,
    required this.clinicId,
    required this.lastVisitUtc,
  });

  final String patientId;
  final String patientName;
  final String phoneNumber;
  final int clinicId;
  final DateTime lastVisitUtc;
}

/// Searchable list of patients the doctor has seen (via medical records), with last visit date.
class PatientArchiveScreen extends StatefulWidget {
  const PatientArchiveScreen({super.key, required this.specialization});

  final DoctorSpecialization specialization;

  @override
  State<PatientArchiveScreen> createState() => PatientArchiveScreenState();
}

class PatientArchiveScreenState extends State<PatientArchiveScreen> {
  /// Called from the dashboard app bar refresh action.
  Future<void> reload() => _load();

  final TextEditingController _search = TextEditingController();

  List<ArchivePatientEntry> _all = [];
  List<ArchivePatientEntry> _visible = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(_applySearch);
    _load();
  }

  @override
  void dispose() {
    _search.removeListener(_applySearch);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var doctorId = SessionManager.instance.doctorId;
      final meFirst = await BackendApiClient.instance.getDoctorMe();
      SessionManager.instance.applyDoctorMe(meFirst);
      doctorId = _parseOptionalInt(meFirst['id']) ?? doctorId;
      if (doctorId == null) {
        throw StateError('Doctor id not available.');
      }

      final clinicId = _readPositiveInt(meFirst['clinicId']);
      if (clinicId == null) {
        throw Exception('Could not read clinic from doctor profile.');
      }

      final rawRecords = await BackendApiClient.instance.getMedicalRecords();
      final records = <ApiMedicalRecordDetail>[];
      for (final m in rawRecords) {
        final row = Map<String, dynamic>.from(m);
        final detail = ApiMedicalRecordDetail.fromJson(row);
        if (detail.clinicId != clinicId) continue;
        if (detail.doctorId != doctorId) continue;
        records.add(detail);
      }

      final byPatient = <String, List<ApiMedicalRecordDetail>>{};
      for (final r in records) {
        final k = r.patientId.trim().toLowerCase();
        byPatient.putIfAbsent(k, () => []).add(r);
      }

      final rawAppts = await BackendApiClient.instance.getAppointments(doctorId: doctorId);
      final appts = rawAppts.map(ApiAppointment.fromJson).toList();
      final phoneByPatient = <String, String>{};
      for (final a in appts) {
        final k = a.patientId.trim().toLowerCase();
        if (a.phoneNumber.trim().isNotEmpty) {
          phoneByPatient[k] = a.phoneNumber.trim();
        }
      }

      final entries = <ArchivePatientEntry>[];
      for (final e in byPatient.entries) {
        final list = e.value..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
        final latest = list.first;
        entries.add(
          ArchivePatientEntry(
            patientId: latest.patientId,
            patientName: latest.patientName.trim().isEmpty ? 'Patient' : latest.patientName.trim(),
            phoneNumber: phoneByPatient[e.key] ?? '',
            clinicId: latest.clinicId,
            lastVisitUtc: latest.createdAtUtc,
          ),
        );
      }
      entries.sort((a, b) => b.lastVisitUtc.compareTo(a.lastVisitUtc));

      if (!mounted) return;
      setState(() {
        _all = entries;
        _applySearch();
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

  int? _parseOptionalInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  int? _readPositiveInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw > 0 ? raw : null;
    if (raw is num) {
      final i = raw.toInt();
      return i > 0 ? i : null;
    }
    final i = int.tryParse(raw.toString().trim());
    if (i == null || i <= 0) return null;
    return i;
  }

  void _applySearch() {
    final q = _search.text.trim().toLowerCase();
    final digits = q.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _visible = _all.where((e) {
        if (q.isEmpty) return true;
        if (e.patientName.toLowerCase().contains(q)) return true;
        if (e.phoneNumber.isNotEmpty) {
          final phoneNorm = e.phoneNumber.replaceAll(RegExp(r'\D'), '');
          if (digits.isNotEmpty && phoneNorm.contains(digits)) return true;
        }
        return false;
      }).toList();
    });
  }

  void _openHistory(ArchivePatientEntry e) {
    final appt = ApiAppointment.forHistoryReview(
      patientId: e.patientId,
      patientName: e.patientName,
      phoneNumber: e.phoneNumber,
      clinicId: e.clinicId,
      lastVisitUtc: e.lastVisitUtc,
    );
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => DoctorPatientSessionScreen(
          appointment: appt,
          specialization: widget.specialization,
          readOnly: true,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.screenPadding(context);
    final dateFmt = DateFormat.yMMMd();

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
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: padding,
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const SizedBox(height: 8),
                  Text(
                    'Patients you have seen at this clinic (${_visible.length})',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
          if (_visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: padding,
                  child: Text(
                    _search.text.isEmpty
                        ? 'No patient history yet. Completed visits will appear here.'
                        : 'No patients match this search.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: padding.copyWith(top: 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final e = _visible[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                e.patientName,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                e.phoneNumber.isEmpty ? '—' : e.phoneNumber,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Last visit: ${dateFmt.format(e.lastVisitUtc.toLocal())}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () => _openHistory(e),
                                icon: const Icon(Icons.folder_open_outlined),
                                label: const Text('View profile / history'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF004D40),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _visible.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
