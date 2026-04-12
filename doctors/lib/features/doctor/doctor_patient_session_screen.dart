import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/enums/doctor_specialization.dart';
import '../../core/formatting/appointment_time_display.dart';
import '../../core/layout/responsive.dart';
import '../../core/models/backend_models.dart';
import '../../core/network/backend_api_client.dart';
import '../../core/network/session_manager.dart';
import 'medication_history_tab.dart';

/// Fallback suggestions when the patient has no prior medications on record.
const _kCommonMedicationNames = <String>[
  'Paracetamol',
  'Acetaminophen',
  'Ibuprofen',
  'Aspirin',
  'Amoxicillin',
  'Azithromycin',
  'Cephalexin',
  'Ciprofloxacin',
  'Metformin',
  'Atorvastatin',
  'Lisinopril',
  'Amlodipine',
  'Omeprazole',
  'Levothyroxine',
  'Metoprolol',
  'Losartan',
  'Gabapentin',
  'Sertraline',
  'Amitriptyline',
  'Prednisolone',
  'Salbutamol',
  'Budesonide',
  'Montelukast',
  'Cetirizine',
  'Loratadine',
  'Diclofenac',
  'Naproxen',
  'Tramadol',
  'Codeine',
  'Vitamin D',
  'Folic acid',
  'Iron supplement',
];

InputDecoration _medicationFieldDecoration(
  ThemeData theme,
  String label, {
  String? hint,
}) {
  final radius = BorderRadius.circular(12);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    border: OutlineInputBorder(borderRadius: radius),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: theme.colorScheme.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: theme.colorScheme.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
    ),
  );
}

/// Digital file for one visit: notes timeline, e-prescription, attachments.
///
/// Notes tab shows all [ApiMedicalRecordDetail] rows for this patient (newest first). New note → POST;
/// edit on a card → PUT that record. Rx/Files use the latest record (or the one just created).
class DoctorPatientSessionScreen extends StatefulWidget {
  const DoctorPatientSessionScreen({
    super.key,
    required this.appointment,
    required this.specialization,
    this.readOnly = false,
  });

  final ApiAppointment appointment;
  final DoctorSpecialization specialization;

  /// Archive / history review: no new notes, edits, meds, or uploads.
  final bool readOnly;

  @override
  State<DoctorPatientSessionScreen> createState() => _DoctorPatientSessionScreenState();
}

class _DoctorPatientSessionScreenState extends State<DoctorPatientSessionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// All visit records for this patient, newest first.
  List<ApiMedicalRecordDetail> _timeline = [];
  ApiMedicalRecordDetail? _record;
  int? _resolvedClinicId;
  bool _loading = true;
  bool _endingSession = false;
  String? _bootstrapError;
  ApiPatient? _patientProfile;
  late final TextEditingController _sessionDoctorNotesCtrl;
  late final TextEditingController _weeksCtrl;
  late final TextEditingController _fetalHrCtrl;
  late final TextEditingController _a1cCtrl;
  late final TextEditingController _weightKgCtrl;
  bool _savingVisitFields = false;
  late ApiAppointment _appointmentSnapshot;
  late final TextEditingController _requestedTestsCtrl;
  List<ApiMedicalFile> _patientUploads = [];

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _appointmentSnapshot = widget.appointment;
    _requestedTestsCtrl =
        TextEditingController(text: widget.appointment.requestedTests ?? '');
    _sessionDoctorNotesCtrl = TextEditingController(text: widget.appointment.doctorNotes ?? '');
    _weeksCtrl = TextEditingController();
    _fetalHrCtrl = TextEditingController();
    _a1cCtrl = TextEditingController();
    _weightKgCtrl = TextEditingController();
    _applySpecializedJsonToControllers(widget.appointment.specializedDataJson);
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _requestedTestsCtrl.dispose();
    _sessionDoctorNotesCtrl.dispose();
    _weeksCtrl.dispose();
    _fetalHrCtrl.dispose();
    _a1cCtrl.dispose();
    _weightKgCtrl.dispose();
    super.dispose();
  }

  void _applySpecializedJsonToControllers(String? raw) {
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>?;
      if (map == null) return;
      final w = map['weeks'];
      final f = map['fetalHeartRate'];
      final a = map['a1cLevel'];
      final kg = map['weightKg'];
      if (w != null) _weeksCtrl.text = w.toString();
      if (f != null) _fetalHrCtrl.text = f.toString();
      if (a != null) _a1cCtrl.text = a.toString();
      if (kg != null) _weightKgCtrl.text = kg.toString();
    } catch (_) {}
  }

  Future<void> _saveVisitClinicalData() async {
    final a = _appointmentSnapshot;
    if (a.id <= 0 || widget.readOnly) return;
    setState(() => _savingVisitFields = true);
    try {
      String? specJson;
      switch (a.type) {
        case ApiAppointmentType.pregnancyFollowUp:
          final o = <String, dynamic>{};
          final w = _weeksCtrl.text.trim();
          final f = _fetalHrCtrl.text.trim();
          if (w.isNotEmpty) o['weeks'] = num.tryParse(w) ?? int.tryParse(w);
          if (f.isNotEmpty) o['fetalHeartRate'] = num.tryParse(f) ?? int.tryParse(f);
          specJson = jsonEncode(o);
          break;
        case ApiAppointmentType.diabetes:
          final o = <String, dynamic>{};
          final ac = _a1cCtrl.text.trim();
          final kg = _weightKgCtrl.text.trim();
          if (ac.isNotEmpty) o['a1cLevel'] = num.tryParse(ac);
          if (kg.isNotEmpty) o['weightKg'] = num.tryParse(kg);
          specJson = jsonEncode(o);
          break;
        default:
          specJson = null;
      }

      final updated = await BackendApiClient.instance.patchDoctorAppointmentSession(
        appointmentId: a.id,
        doctorNotes: _sessionDoctorNotesCtrl.text.trim().isEmpty ? '' : _sessionDoctorNotesCtrl.text.trim(),
        specializedDataJson: specJson,
        requestedTests: _requestedTestsCtrl.text.trim().isEmpty ? '' : _requestedTestsCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _appointmentSnapshot = updated;
        _applySpecializedJsonToControllers(updated.specializedDataJson);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clinical visit data saved.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _savingVisitFields = false);
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _bootstrapError = null;
    });
    try {
      final a = widget.appointment;
      if (a.patientId.trim().isEmpty) {
        throw Exception(
          'Appointment is missing patientId (UUID). Cannot load medical records.',
        );
      }
      if (a.clinicId <= 0) {
        throw Exception(
          'Appointment has invalid clinicId (${a.clinicId}).',
        );
      }

      final me = await BackendApiClient.instance.getDoctorMe();
      final doctorClinicId = _readPositiveInt(me['clinicId']);
      if (doctorClinicId == null) {
        throw Exception(
          'Could not read a positive clinicId from GET /Doctors/me.',
        );
      }
      if (a.clinicId != doctorClinicId) {
        throw Exception(
          'Appointment is for clinic ${a.clinicId}, but your account is for clinic $doctorClinicId.',
        );
      }

      final rawList = await BackendApiClient.instance.getMedicalRecords();
      final patientKey = a.patientId.trim().toLowerCase();
      final matches = <ApiMedicalRecordDetail>[];
      for (final m in rawList) {
        final row = Map<String, dynamic>.from(m);
        final pid = (row['patientId'] ?? row['patient_id'])?.toString().trim().toLowerCase() ?? '';
        if (pid == patientKey) {
          matches.add(ApiMedicalRecordDetail.fromJson(row));
        }
      }
      matches.sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
      final latest = matches.isEmpty ? null : matches.first;

      ApiPatient? profile;
      try {
        profile = await BackendApiClient.instance.getPatientById(a.patientId.trim());
      } catch (_) {
        profile = null;
      }

      ApiAppointment appt = a;
      var uploads = <ApiMedicalFile>[];
      if (a.id > 0) {
        try {
          appt = await BackendApiClient.instance.getAppointmentById(a.id);
          uploads = await BackendApiClient.instance.getAppointmentPatientUploads(a.id);
        } catch (_) {
          uploads = [];
        }
      }

      if (!mounted) return;
      setState(() {
        _resolvedClinicId = doctorClinicId;
        _timeline = matches;
        _record = latest;
        _patientProfile = profile;
        _appointmentSnapshot = appt;
        _requestedTestsCtrl.text = appt.requestedTests ?? '';
        _patientUploads = uploads;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bootstrapError = e.toString();
        _loading = false;
      });
    }
  }

  /// Parses API numeric id; returns null if missing or not positive.
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

  Future<int?> _resolveDoctorIdForApi() async {
    final fromSession = SessionManager.instance.doctorId;
    if (fromSession != null && fromSession > 0) {
      return fromSession;
    }
    final me = await BackendApiClient.instance.getDoctorMe();
    return _readPositiveInt(me['id']);
  }

  void _applyRecord(ApiMedicalRecordDetail r) {
    setState(() {
      final rest = _timeline.where((x) => x.id != r.id).toList(growable: false);
      _timeline = [r, ...rest];
      _timeline.sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
      _record = _timeline.isEmpty ? null : _timeline.first;
    });
  }

  bool _canEditRecord(ApiMedicalRecordDetail r) {
    final my = SessionManager.instance.doctorId;
    if (my == null) return true;
    return my == r.doctorId;
  }

  Future<void> _openNewNoteSheet() async {
    final clinicId = _resolvedClinicId;
    if (clinicId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session not ready. Use refresh in the app bar or reopen.')),
      );
      return;
    }

    final created = await showModalBottomSheet<ApiMedicalRecordDetail?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => _NewClinicalNoteSheet(
        clinicId: clinicId,
        patientId: widget.appointment.patientId,
        resolveDoctorId: _resolveDoctorIdForApi,
      ),
    );
    if (created != null && mounted) {
      _applyRecord(created);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visit record created. Visible under My Records.'),
        ),
      );
    }
  }

  Future<void> _openEditNoteSheet(ApiMedicalRecordDetail record) async {
    if (!_canEditRecord(record)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only edit notes you authored.')),
      );
      return;
    }

    final updated = await showModalBottomSheet<ApiMedicalRecordDetail?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => _EditClinicalNoteSheet(record: record),
    );
    if (updated != null && mounted) {
      _applyRecord(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note updated.')),
      );
    }
  }

  /// Names from this patient's records plus [ _kCommonMedicationNames ], for autocomplete.
  List<String> _medicationAutocompleteOptions(String query) {
    final names = <String>{};
    for (final rec in _timeline) {
      for (final p in rec.prescriptions) {
        for (final m in p.medications) {
          final n = m.name.trim();
          if (n.isNotEmpty) names.add(n);
        }
      }
    }
    names.addAll(_kCommonMedicationNames);
    final sorted = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return sorted.take(12).toList();
    return sorted.where((n) => n.toLowerCase().contains(q)).take(24).toList();
  }

  Future<void> _addMedication() async {
    final prescId = _record?.primaryPrescriptionId;
    if (prescId == null) return;

    final updated = await showModalBottomSheet<ApiMedicalRecordDetail?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddMedicationFormSheet(
        prescriptionId: prescId,
        medicationOptions: _medicationAutocompleteOptions,
      ),
    );
    if (updated != null && mounted) {
      _applyRecord(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription updated. Patient sees it under My Records.')),
      );
    }
  }

  Future<void> _removeMedication(ApiMedication m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove medication?'),
        content: Text(m.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final updated = await BackendApiClient.instance.removeMedication(m.id);
      if (!mounted) return;
      _applyRecord(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _pickAndUpload() async {
    final id = _record?.id;
    if (id == null) return;
    final pick = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
      withData: false,
    );
    if (pick == null || pick.files.isEmpty) return;
    final f = pick.files.single;
    final path = f.path;
    if (path == null || path.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read file path.')),
      );
      return;
    }
    final name = f.name;
    try {
      final updated = await BackendApiClient.instance.uploadMedicalRecordAttachment(
        medicalRecordId: id,
        filePath: path,
        fileName: name,
      );
      if (!mounted) return;
      _applyRecord(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File uploaded. Patient can open it from My Records.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _openAttachment(ApiFileAttachment a) async {
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

  Future<void> _openPatientMedicalFile(ApiMedicalFile f) async {
    final url = BackendApiClient.instance.medicalFileUrl(f);
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open file')),
      );
    }
  }

  List<ApiMedication> get _allMedications {
    final r = _record;
    if (r == null) return const [];
    final out = <ApiMedication>[];
    for (final p in r.prescriptions) {
      out.addAll(p.medications);
    }
    return out;
  }

  Future<void> _copyMedToCurrentVisit(ApiMedication template) async {
    if (widget.readOnly) return;
    final prescId = _record?.primaryPrescriptionId;
    if (prescId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Add a visit note on the Notes tab first so this session has a prescription to add medications to.',
            ),
          ),
        );
      }
      return;
    }
    try {
      final updated = await BackendApiClient.instance.addMedication(
        prescriptionId: prescId,
        name: template.name,
        dosage: template.dosage,
        schedule: template.schedule,
        instructions: template.instructions,
      );
      if (!mounted) return;
      _applyRecord(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medication copied to this visit.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _medicationHistoryTab(BuildContext context) {
    return MedicationHistoryTab(
      timeline: _timeline,
      readOnly: widget.readOnly,
      onCopyToCurrentVisit: widget.readOnly ? null : _copyMedToCurrentVisit,
    );
  }

  Future<void> _onEndSession() async {
    final a = _appointmentSnapshot;
    if (a.id <= 0 || widget.readOnly || a.status != ApiAppointmentStatus.inProgress) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End session?'),
        content: const Text(
          'Are you sure you want to end this session? This will move the patient to the archive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End session'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _endingSession = true);
    try {
      await BackendApiClient.instance.patchDoctorAppointmentStatus(
        appointmentId: a.id,
        status: ApiAppointmentStatus.completed,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not complete visit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _endingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _appointmentSnapshot;
    final readOnly = widget.readOnly;
    final showNotesFab = !readOnly &&
        !_loading &&
        _bootstrapError == null &&
        _tabController.index == 0;

    final showEndSession =
        !readOnly && a.id > 0 && a.status == ApiAppointmentStatus.inProgress;

    return Scaffold(
      floatingActionButton: showNotesFab
          ? FloatingActionButton.extended(
              onPressed: _openNewNoteSheet,
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('New note'),
            )
          : null,
      bottomNavigationBar: showEndSession
          ? SafeArea(
              child: Material(
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: FilledButton.icon(
                    onPressed: _endingSession ? null : _onEndSession,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF004D40),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    icon: _endingSession
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.call_end_outlined),
                    label: Text(_endingSession ? 'Ending…' : 'End session'),
                  ),
                ),
              ),
            )
          : null,
      appBar: AppBar(
        title: Text(a.patientName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload records',
            onPressed: _loading ? null : _bootstrap,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Notes', icon: Icon(Icons.edit_note_outlined)),
            Tab(text: 'E-Prescription', icon: Icon(Icons.medication_outlined)),
            Tab(text: 'Medication history', icon: Icon(Icons.history_outlined)),
            Tab(text: 'Files', icon: Icon(Icons.folder_outlined)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bootstrapError != null
              ? Center(
                  child: Padding(
                    padding: Responsive.screenPadding(context),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_bootstrapError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _bootstrap, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (readOnly)
                      Material(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                size: 20,
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Viewing patient history (read-only).',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_patientProfile != null &&
                        _patientProfile!.hasChronicCondition &&
                        _patientProfile!.chronicDiseases.isNotEmpty)
                      Material(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Chronic conditions on file',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onErrorContainer,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _patientProfile!.chronicDiseases.join(' · '),
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Theme.of(context).colorScheme.onErrorContainer,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!readOnly && a.id > 0)
                      Padding(
                        padding: Responsive.screenPadding(context).copyWith(top: 8, bottom: 8),
                        child: Card(
                          elevation: 0,
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.65),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Visit clinical data',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _sessionDoctorNotesCtrl,
                                  maxLines: 3,
                                  decoration: _medicationFieldDecoration(
                                    Theme.of(context),
                                    'Doctor notes (this session)',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _requestedTestsCtrl,
                                  maxLines: 3,
                                  decoration: _medicationFieldDecoration(
                                    Theme.of(context),
                                    'Requested tests / labs (visible to patient)',
                                    hint: 'e.g. CBC, metabolic panel, ultrasound',
                                  ),
                                ),
                                if (a.type == ApiAppointmentType.pregnancyFollowUp) ...[
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _weeksCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                    decoration: _medicationFieldDecoration(
                                      Theme.of(context),
                                      'Gestational age (weeks)',
                                      hint: 'Optional',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _fetalHrCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                    decoration: _medicationFieldDecoration(
                                      Theme.of(context),
                                      'Fetal heart rate (bpm)',
                                      hint: 'Optional',
                                    ),
                                  ),
                                ],
                                if (a.type == ApiAppointmentType.diabetes) ...[
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _a1cCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: _medicationFieldDecoration(
                                      Theme.of(context),
                                      'HbA1c (%)',
                                      hint: 'Optional',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _weightKgCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: _medicationFieldDecoration(
                                      Theme.of(context),
                                      'Weight (kg)',
                                      hint: 'Optional',
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _savingVisitFields ? null : _saveVisitClinicalData,
                                  icon: _savingVisitFields
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: Text(_savingVisitFields ? 'Saving…' : 'Save clinical data'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (!readOnly &&
                        a.doctorNotes != null &&
                        a.doctorNotes!.trim().isNotEmpty)
                      Material(
                        color: const Color(0xFFE0F2F1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.assignment_outlined, color: Color(0xFF004D40)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Doctor notes (from booking)',
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                            color: const Color(0xFF004D40),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      a.doctorNotes!,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _notesTab(context),
                          _rxTab(context),
                          _medicationHistoryTab(context),
                          _filesTab(context),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  bool _clinicalFieldsEmpty(ApiMedicalRecordDetail r) {
    final s = r.symptoms?.trim() ?? '';
    final d = r.diagnosis?.trim() ?? '';
    final n = r.notes?.trim() ?? '';
    return s.isEmpty && d.isEmpty && n.isEmpty;
  }

  Widget _clinicalNoteCard(BuildContext context, ApiMedicalRecordDetail r) {
    final theme = Theme.of(context);
    final isLatest = r.id == _record?.id;
    final doctorLabel = r.doctorName.trim().isEmpty ? 'Unknown doctor' : r.doctorName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatAppointmentDateTimeLine(r.createdAtUtc),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          doctorLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLatest)
                    Padding(
                      padding: const EdgeInsets.only(right: 4, top: 2),
                      child: Chip(
                        label: const Text('Latest visit'),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  if (!widget.readOnly && _canEditRecord(r))
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _openEditNoteSheet(r),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (r.symptoms != null && r.symptoms!.trim().isNotEmpty) ...[
                    Text('Symptoms', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 2),
                    Text(r.symptoms!, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 10),
                  ],
                  if (r.diagnosis != null && r.diagnosis!.trim().isNotEmpty) ...[
                    Text('Diagnosis', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 2),
                    Text(r.diagnosis!, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 10),
                  ],
                  if (r.notes != null && r.notes!.trim().isNotEmpty) ...[
                    Text('Clinical notes', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 2),
                    Text(r.notes!, style: theme.textTheme.bodyMedium),
                  ],
                  if (_clinicalFieldsEmpty(r))
                    Text(
                      'No symptoms, diagnosis, or notes on file for this entry.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notesTab(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: Responsive.screenPadding(context),
      children: [
        Text(
          '${widget.appointment.patientName} · ${formatAppointmentDateTimeLine(widget.appointment.scheduledAtUtc)}',
          style: theme.textTheme.titleSmall,
        ),
        Text(
          widget.specialization.label,
          style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
        ),
        Text(
          widget.appointment.phoneNumber,
          style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 20),
        Text(
          'Clinical timeline',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          widget.readOnly
              ? 'Newest first. Review past visits below.'
              : 'Newest first. E-Prescription and Files use the latest visit—tap New note to add another.',
          style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        if (_timeline.isEmpty)
          Card(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('No visit notes yet', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    widget.readOnly
                        ? 'No clinical notes on file for this patient.'
                        : 'Tap the New note button to add symptoms, diagnosis, and clinical notes.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          )
        else
          ..._timeline.map((r) => _clinicalNoteCard(context, r)),
      ],
    );
  }

  Future<void> _editAppointmentReminders() async {
    final aid = _appointmentSnapshot.id;
    if (aid <= 0 || widget.readOnly) return;

    final existing = _appointmentSnapshot.appointmentPrescriptions;
    final rows = <_RxRow>[];
    if (existing.isEmpty) {
      rows.add(_RxRow());
    } else {
      for (final e in existing) {
        rows.add(
          _RxRow(
            name: TextEditingController(text: e.medicationName),
            dosage: TextEditingController(text: e.dosage),
            times: TextEditingController(text: '${e.timesPerDay}'),
          ),
        );
      }
    }

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: StatefulBuilder(
              builder: (ctx, setModal) {
                return SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Patient reminder schedule',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Used by the patient app for local notifications (spread across the day by times per day).',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 16),
                        for (var i = 0; i < rows.length; i++) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: rows[i].name,
                                  decoration: _medicationFieldDecoration(
                                    Theme.of(ctx),
                                    'Medication',
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: rows.length <= 1
                                    ? null
                                    : () {
                                        final r = rows.removeAt(i);
                                        r.dispose();
                                        setModal(() {});
                                      },
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: rows[i].dosage,
                            decoration: _medicationFieldDecoration(
                              Theme.of(ctx),
                              'Dosage',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: rows[i].times,
                            keyboardType: TextInputType.number,
                            decoration: _medicationFieldDecoration(
                              Theme.of(ctx),
                              'Times per day',
                              hint: '1–24',
                            ),
                          ),
                          const Divider(height: 24),
                        ],
                        TextButton.icon(
                          onPressed: () {
                            rows.add(_RxRow());
                            setModal(() {});
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add medication line'),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () async {
                            final start = DateTime.now().toUtc();
                            final lines = <Map<String, dynamic>>[];
                            for (final r in rows) {
                              final n = r.name.text.trim();
                              if (n.isEmpty) continue;
                              final t = int.tryParse(r.times.text.trim()) ?? 1;
                              lines.add(<String, dynamic>{
                                'medicationName': n,
                                'dosage': r.dosage.text.trim(),
                                'timesPerDay': t.clamp(1, 24),
                                'startDateUtc': start.toIso8601String(),
                                'endDateUtc': null,
                              });
                            }
                            try {
                              final updated =
                                  await BackendApiClient.instance.replaceAppointmentPrescriptions(
                                appointmentId: aid,
                                lines: lines,
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              if (!mounted) return;
                              setState(() => _appointmentSnapshot = updated);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Reminder schedule saved.'),
                                ),
                              );
                            } catch (e) {
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    } finally {
      for (final r in rows) {
        r.dispose();
      }
    }
  }

  Widget _rxTab(BuildContext context) {
    final meds = _allMedications;
    final aid = _appointmentSnapshot.id;
    return Column(
      children: [
        if (aid > 0 && !widget.readOnly)
          Padding(
            padding: Responsive.screenPadding(context).copyWith(top: 8, bottom: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient app reminders',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF004D40),
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_appointmentSnapshot.appointmentPrescriptions.length} active line(s). '
                      'These power on-device dose reminders for the patient.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonal(
                      onPressed: _editAppointmentReminders,
                      child: const Text('Edit reminder medications'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (!widget.readOnly)
          Padding(
            padding: Responsive.screenPadding(context).copyWith(top: 12, bottom: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _record == null ? null : _addMedication,
                icon: const Icon(Icons.add),
                label: const Text('Add medication'),
              ),
            ),
          ),
        Expanded(
          child: _record == null
              ? Center(
                  child: Padding(
                    padding: Responsive.screenPadding(context),
                    child: Text(
                      widget.readOnly
                          ? 'No prescription data without a visit record on file.'
                          : 'Add a visit note from the Notes tab (New note) before adding medications.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                )
              : meds.isEmpty
                  ? Center(
                      child: Text(
                        'No medications yet.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    )
                  : ListView.separated(
                      padding: Responsive.screenPadding(context),
                      itemCount: meds.length,
                      separatorBuilder: (context, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final m = meds[i];
                        return Card(
                          child: ListTile(
                            title: Text(m.name),
                            subtitle: Text(
                              '${m.dosage} · ${m.schedule}'
                              '${m.instructions != null && m.instructions!.isNotEmpty ? '\n${m.instructions}' : ''}',
                            ),
                            isThreeLine: m.instructions != null && m.instructions!.isNotEmpty,
                            trailing: widget.readOnly
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _removeMedication(m),
                                  ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _filesTab(BuildContext context) {
    final files = _record?.attachments ?? const <ApiFileAttachment>[];
    final apptId = _appointmentSnapshot.id;
    return Column(
      children: [
        if (apptId > 0 && _patientUploads.isNotEmpty) ...[
          Padding(
            padding: Responsive.screenPadding(context).copyWith(top: 12, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Patient attachments (this visit)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF004D40),
                    ),
              ),
            ),
          ),
          for (final f in _patientUploads) ...[
            Padding(
              padding: Responsive.screenPadding(context).copyWith(top: 0, bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Icon(
                    f.fileType.toLowerCase().contains('pdf') ||
                            f.fileName.toLowerCase().endsWith('.pdf')
                        ? Icons.picture_as_pdf
                        : Icons.image_outlined,
                  ),
                  title: Text(f.fileName),
                  subtitle: const Text('Uploaded by patient'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openPatientMedicalFile(f),
                ),
              ),
            ),
          ],
          const Divider(height: 24),
        ],
        Padding(
          padding: Responsive.screenPadding(context).copyWith(top: 12, bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Clinic files (visit record): X-rays and lab PDFs.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
        if (!widget.readOnly)
          Padding(
            padding: Responsive.screenPadding(context).copyWith(top: 0, bottom: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _record == null ? null : _pickAndUpload,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload file'),
              ),
            ),
          ),
        Expanded(
          child: _record == null
              ? Center(
                  child: Padding(
                    padding: Responsive.screenPadding(context),
                    child: Text(
                      widget.readOnly
                          ? 'No visit record on file.'
                          : 'Add a visit note from the Notes tab (New note) before uploading files.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                )
              : files.isEmpty
                  ? Center(
                      child: Text(
                        'No files yet.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    )
                  : ListView.separated(
                      padding: Responsive.screenPadding(context),
                      itemCount: files.length,
                      separatorBuilder: (context, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final f = files[i];
                        final isPdf = f.contentType.contains('pdf') ||
                            f.originalFileName.toLowerCase().endsWith('.pdf');
                        return Card(
                          child: ListTile(
                            leading: Icon(isPdf ? Icons.picture_as_pdf : Icons.image_outlined),
                            title: Text(f.originalFileName),
                            subtitle: Text('${(f.fileSizeBytes / 1024).toStringAsFixed(1)} KB'),
                            trailing: const Icon(Icons.open_in_new),
                            onTap: () => _openAttachment(f),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _NewClinicalNoteSheet extends StatefulWidget {
  const _NewClinicalNoteSheet({
    required this.clinicId,
    required this.patientId,
    required this.resolveDoctorId,
  });

  final int clinicId;
  final String patientId;
  final Future<int?> Function() resolveDoctorId;

  @override
  State<_NewClinicalNoteSheet> createState() => _NewClinicalNoteSheetState();
}

class _NewClinicalNoteSheetState extends State<_NewClinicalNoteSheet> {
  late final TextEditingController _symptoms;
  late final TextEditingController _diagnosis;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _symptoms = TextEditingController();
    _diagnosis = TextEditingController();
    _notes = TextEditingController();
  }

  @override
  void dispose() {
    _symptoms.dispose();
    _diagnosis.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final doctorId = await widget.resolveDoctorId();
      if (doctorId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not resolve doctor id. Sign in again.')),
          );
        }
        return;
      }
      final created = await BackendApiClient.instance.createMedicalRecord(
        patientId: widget.patientId,
        clinicId: widget.clinicId,
        doctorId: doctorId,
        symptoms: _symptoms.text.trim().isEmpty ? null : _symptoms.text.trim(),
        diagnosis: _diagnosis.text.trim().isEmpty ? null : _diagnosis.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, created);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'New clinical note',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _symptoms,
              decoration: const InputDecoration(
                labelText: 'Symptoms',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _diagnosis,
              decoration: const InputDecoration(
                labelText: 'Diagnosis',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Clinical notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 6,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save visit note'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditClinicalNoteSheet extends StatefulWidget {
  const _EditClinicalNoteSheet({required this.record});

  final ApiMedicalRecordDetail record;

  @override
  State<_EditClinicalNoteSheet> createState() => _EditClinicalNoteSheetState();
}

class _EditClinicalNoteSheetState extends State<_EditClinicalNoteSheet> {
  late final TextEditingController _symptoms;
  late final TextEditingController _diagnosis;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _symptoms = TextEditingController(text: r.symptoms ?? '');
    _diagnosis = TextEditingController(text: r.diagnosis ?? '');
    _notes = TextEditingController(text: r.notes ?? '');
  }

  @override
  void dispose() {
    _symptoms.dispose();
    _diagnosis.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = await BackendApiClient.instance.updateMedicalRecord(
        id: widget.record.id,
        symptoms: _symptoms.text.trim().isEmpty ? null : _symptoms.text.trim(),
        diagnosis: _diagnosis.text.trim().isEmpty ? null : _diagnosis.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit visit #${widget.record.id}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _symptoms,
              decoration: const InputDecoration(
                labelText: 'Symptoms',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _diagnosis,
              decoration: const InputDecoration(
                labelText: 'Diagnosis',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Clinical notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 6,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMedicationFormSheet extends StatefulWidget {
  const _AddMedicationFormSheet({
    required this.prescriptionId,
    required this.medicationOptions,
  });

  final int prescriptionId;
  final List<String> Function(String query) medicationOptions;

  @override
  State<_AddMedicationFormSheet> createState() => _AddMedicationFormSheetState();
}

class _AddMedicationFormSheetState extends State<_AddMedicationFormSheet> {
  late final FocusNode _nameFocus;
  late final TextEditingController _name;
  late final TextEditingController _dosage;
  late final TextEditingController _frequency;
  late final TextEditingController _duration;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameFocus = FocusNode();
    _name = TextEditingController();
    _dosage = TextEditingController();
    _frequency = TextEditingController();
    _duration = TextEditingController();
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _name.dispose();
    _dosage.dispose();
    _frequency.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medication name is required.')),
      );
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final durationLine = _duration.text.trim();
      final instructions = durationLine.isEmpty ? null : 'Duration: $durationLine';
      final updated = await BackendApiClient.instance.addMedication(
        prescriptionId: widget.prescriptionId,
        name: _name.text.trim(),
        dosage: _dosage.text.trim(),
        schedule: _frequency.text.trim().isEmpty ? 'As directed' : _frequency.text.trim(),
        instructions: instructions,
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add medication',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Visible to the patient under My Records. Duration is stored in instructions.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            RawAutocomplete<String>(
              textEditingController: _name,
              focusNode: _nameFocus,
              optionsBuilder: (value) {
                if (value.text == '') {
                  return widget.medicationOptions('');
                }
                return widget.medicationOptions(value.text);
              },
              displayStringForOption: (option) => option,
              optionsViewBuilder: (context, onSelected, options) {
                if (options.isEmpty) return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 3,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220, minWidth: 240),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            dense: true,
                            title: Text(option),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  decoration: _medicationFieldDecoration(theme, 'Medication name', hint: 'Search or type…'),
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) {
                    onFieldSubmitted();
                    unawaited(_submit());
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dosage,
              decoration: _medicationFieldDecoration(theme, 'Dosage', hint: 'e.g. 500 mg'),
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _frequency,
              decoration: _medicationFieldDecoration(theme, 'Frequency', hint: 'e.g. 3 times a day'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _duration,
              decoration: _medicationFieldDecoration(theme, 'Duration', hint: 'e.g. 7 days'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RxRow {
  _RxRow({
    TextEditingController? name,
    TextEditingController? dosage,
    TextEditingController? times,
  })  : name = name ?? TextEditingController(),
        dosage = dosage ?? TextEditingController(),
        times = times ?? TextEditingController(text: '3');

  final TextEditingController name;
  final TextEditingController dosage;
  final TextEditingController times;

  void dispose() {
    name.dispose();
    dosage.dispose();
    times.dispose();
  }
}
