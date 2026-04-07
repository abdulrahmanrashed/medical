import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/enums/doctor_specialization.dart';
import '../../core/formatting/appointment_time_display.dart';
import '../../core/layout/responsive.dart';
import '../../core/models/backend_models.dart';
import '../../core/network/backend_api_client.dart';
import '../../core/network/session_manager.dart';

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

/// Digital file for one visit: notes timeline, e-prescription, attachments.
///
/// Notes tab shows all [ApiMedicalRecordDetail] rows for this patient (newest first). New note → POST;
/// edit on a card → PUT that record. Rx/Files use the latest record (or the one just created).
class DoctorPatientSessionScreen extends StatefulWidget {
  const DoctorPatientSessionScreen({
    super.key,
    required this.appointment,
    required this.specialization,
  });

  final ApiAppointment appointment;
  final DoctorSpecialization specialization;

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
  String? _bootstrapError;

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
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

      if (!mounted) return;
      setState(() {
        _resolvedClinicId = doctorClinicId;
        _timeline = matches;
        _record = latest;
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

    final symptoms = TextEditingController();
    final diagnosis = TextEditingController();
    final notes = TextEditingController();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) {
          var saving = false;
          return StatefulBuilder(
            builder: (_, setModal) {
              final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
              return Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'New clinical note',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: symptoms,
                        decoration: const InputDecoration(
                          labelText: 'Symptoms',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: diagnosis,
                        decoration: const InputDecoration(
                          labelText: 'Diagnosis',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notes,
                        decoration: const InputDecoration(
                          labelText: 'Clinical notes',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 6,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                setModal(() => saving = true);
                                try {
                                  final doctorId = await _resolveDoctorIdForApi();
                                  if (doctorId == null) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                          content: Text('Could not resolve doctor id. Sign in again.'),
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                  final created = await BackendApiClient.instance.createMedicalRecord(
                                    patientId: widget.appointment.patientId,
                                    clinicId: clinicId,
                                    doctorId: doctorId,
                                    symptoms: symptoms.text.trim().isEmpty ? null : symptoms.text.trim(),
                                    diagnosis: diagnosis.text.trim().isEmpty ? null : diagnosis.text.trim(),
                                    notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
                                  );
                                  if (!mounted) return;
                                  _applyRecord(created);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Visit record created. Visible under My Records.'),
                                    ),
                                  );
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
                                  }
                                } finally {
                                  if (ctx.mounted) setModal(() => saving = false);
                                }
                              },
                        child: saving
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
            },
          );
        },
      );
    } finally {
      symptoms.dispose();
      diagnosis.dispose();
      notes.dispose();
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

    final symptoms = TextEditingController(text: record.symptoms ?? '');
    final diagnosis = TextEditingController(text: record.diagnosis ?? '');
    final notes = TextEditingController(text: record.notes ?? '');
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) {
          var saving = false;
          return StatefulBuilder(
            builder: (_, setModal) {
              final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
              return Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Edit visit #${record.id}',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: symptoms,
                        decoration: const InputDecoration(
                          labelText: 'Symptoms',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: diagnosis,
                        decoration: const InputDecoration(
                          labelText: 'Diagnosis',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notes,
                        decoration: const InputDecoration(
                          labelText: 'Clinical notes',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 6,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                setModal(() => saving = true);
                                try {
                                  final updated = await BackendApiClient.instance.updateMedicalRecord(
                                    id: record.id,
                                    symptoms: symptoms.text.trim().isEmpty ? null : symptoms.text.trim(),
                                    diagnosis: diagnosis.text.trim().isEmpty ? null : diagnosis.text.trim(),
                                    notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
                                  );
                                  if (!mounted) return;
                                  _applyRecord(updated);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Note updated.')),
                                  );
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
                                  }
                                } finally {
                                  if (ctx.mounted) setModal(() => saving = false);
                                }
                              },
                        child: saving
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
            },
          );
        },
      );
    } finally {
      symptoms.dispose();
      diagnosis.dispose();
      notes.dispose();
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

  Future<void> _addMedication() async {
    final prescId = _record?.primaryPrescriptionId;
    if (prescId == null) return;

    final nameFocus = FocusNode();
    final name = TextEditingController();
    final dosage = TextEditingController();
    final frequency = TextEditingController();
    final duration = TextEditingController();

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) {
          var saving = false;
          return StatefulBuilder(
            builder: (_, setModal) {
              final theme = Theme.of(sheetCtx);
              final bottomInset = MediaQuery.viewInsetsOf(sheetCtx).bottom;
              final deco = _medicationFieldDecoration;

              Future<void> submit() async {
                if (name.text.trim().isEmpty) {
                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                    const SnackBar(content: Text('Medication name is required.')),
                  );
                  return;
                }
                setModal(() => saving = true);
                try {
                  final durationLine = duration.text.trim();
                  final instructions = durationLine.isEmpty ? null : 'Duration: $durationLine';
                  final updated = await BackendApiClient.instance.addMedication(
                    prescriptionId: prescId,
                    name: name.text.trim(),
                    dosage: dosage.text.trim(),
                    schedule: frequency.text.trim().isEmpty ? 'As directed' : frequency.text.trim(),
                    instructions: instructions,
                  );
                  if (!mounted) return;
                  _applyRecord(updated);
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Prescription updated. Patient sees it under My Records.')),
                  );
                } catch (e) {
                  if (sheetCtx.mounted) {
                    ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (sheetCtx.mounted) setModal(() => saving = false);
                }
              }

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
                        textEditingController: name,
                        focusNode: nameFocus,
                        optionsBuilder: (value) {
                          if (value.text == '') {
                            return _medicationAutocompleteOptions('');
                          }
                          return _medicationAutocompleteOptions(value.text);
                        },
                        displayStringForOption: (option) => option,
                        optionsViewBuilder: (context, onSelected, options) {
                          if (options.isEmpty) return const SizedBox.shrink();
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 8,
                              shadowColor: theme.colorScheme.shadow,
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
                            decoration: deco(theme, 'Medication name', hint: 'Search or type…'),
                            textCapitalization: TextCapitalization.words,
                            onSubmitted: (_) {
                              onFieldSubmitted();
                              submit();
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: dosage,
                        decoration: deco(theme, 'Dosage', hint: 'e.g. 500 mg'),
                        textCapitalization: TextCapitalization.none,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: frequency,
                        decoration: deco(theme, 'Frequency', hint: 'e.g. 3 times a day'),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: duration,
                        decoration: deco(theme, 'Duration', hint: 'e.g. 7 days'),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: saving ? null : () => Navigator.pop(sheetCtx),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: saving ? null : submit,
                              child: saving
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
            },
          );
        },
      );
    } finally {
      nameFocus.dispose();
      name.dispose();
      dosage.dispose();
      frequency.dispose();
      duration.dispose();
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

  List<ApiMedication> get _allMedications {
    final r = _record;
    if (r == null) return const [];
    final out = <ApiMedication>[];
    for (final p in r.prescriptions) {
      out.addAll(p.medications);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final showNotesFab = !_loading &&
        _bootstrapError == null &&
        _tabController.index == 0;

    return Scaffold(
      floatingActionButton: showNotesFab
          ? FloatingActionButton.extended(
              onPressed: _openNewNoteSheet,
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('New note'),
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
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _notesTab(context),
                    _rxTab(context),
                    _filesTab(context),
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
        elevation: 0,
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
                  if (_canEditRecord(r))
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
          'Newest first. E-Prescription and Files use the latest visit—tap New note to add another.',
          style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        if (_timeline.isEmpty)
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('No visit notes yet', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the New note button to add symptoms, diagnosis, and clinical notes.',
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

  Widget _rxTab(BuildContext context) {
    final meds = _allMedications;
    return Column(
      children: [
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
                      'Add a visit note from the Notes tab (New note) before adding medications.',
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
                            trailing: IconButton(
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
    return Column(
      children: [
        Padding(
          padding: Responsive.screenPadding(context).copyWith(top: 12, bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'X-rays (images) and lab results (PDF).',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
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
                      'Add a visit note from the Notes tab (New note) before uploading files.',
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
