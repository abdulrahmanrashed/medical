import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting/appointment_time_display.dart';
import '../../core/models/backend_models.dart';
import '../../core/network/backend_api_client.dart';
import '../../core/network/session_manager.dart';
import 'reception_dashboard_controller.dart';

Future<void> showReceptionAddAppointmentSheet(BuildContext parentContext) {
  return showModalBottomSheet<void>(
    context: parentContext,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: _AddAppointmentForm(
          scaffoldContext: parentContext,
          controller: parentContext.read<ReceptionDashboardController>(),
        ),
      );
    },
  );
}

class _AddAppointmentForm extends StatefulWidget {
  const _AddAppointmentForm({
    required this.scaffoldContext,
    required this.controller,
  });

  final BuildContext scaffoldContext;
  final ReceptionDashboardController controller;

  @override
  State<_AddAppointmentForm> createState() => _AddAppointmentFormState();
}

class _AddAppointmentFormState extends State<_AddAppointmentForm> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  Timer? _phoneDebounce;
  bool _lookupLoading = false;
  ApiPatient? _resolvedPatient;
  String? _lookupError;

  ApiAppointmentType _type = ApiAppointmentType.general;
  int? _doctorId;
  List<Map<String, dynamic>> _doctors = [];
  bool _doctorsLoading = false;
  DateTime? _scheduledLocal;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _scheduledLocal = DateTime.now().add(const Duration(hours: 1));
    _scheduledLocal = DateTime(
      _scheduledLocal!.year,
      _scheduledLocal!.month,
      _scheduledLocal!.day,
      _scheduledLocal!.hour,
      (_scheduledLocal!.minute ~/ 15) * 15,
    );
    _loadDoctors();
  }

  @override
  void dispose() {
    _phoneDebounce?.cancel();
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    final clinicId = SessionManager.instance.assignedClinicId;
    if (clinicId == null) return;
    setState(() => _doctorsLoading = true);
    try {
      final list = await BackendApiClient.instance.getDoctorsByClinic(clinicId);
      if (mounted) setState(() => _doctors = list);
    } catch (_) {
      if (mounted) setState(() => _doctors = []);
    } finally {
      if (mounted) setState(() => _doctorsLoading = false);
    }
  }

  void _onPhoneChanged(String value) {
    _phoneDebounce?.cancel();
    _phoneDebounce = Timer(const Duration(milliseconds: 550), () {
      unawaited(_runPhoneLookup(value));
    });
  }

  Future<void> _runPhoneLookup(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.length < 6) {
      if (!mounted) return;
      setState(() {
        _resolvedPatient = null;
        _lookupError = null;
        _lookupLoading = false;
      });
      return;
    }

    setState(() {
      _lookupLoading = true;
      _lookupError = null;
    });

    try {
      final p = await widget.controller.lookupPatientByPhone(trimmed);
      if (!mounted) return;
      setState(() {
        _resolvedPatient = p;
        if (p != null) {
          _nameCtrl.text = p.fullName;
        }
        _lookupLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lookupLoading = false;
        _lookupError = e.toString();
        _resolvedPatient = null;
      });
    }
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final initial = _scheduledLocal ?? now.add(const Duration(hours: 1));
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (t == null || !mounted) return;

    setState(() {
      _scheduledLocal = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final clinicId = SessionManager.instance.assignedClinicId;
    if (clinicId == null) {
      _toast('No clinic is assigned to this reception account.');
      return;
    }

    if (_type == ApiAppointmentType.specificDoctor && _doctorId == null) {
      _toast('Select a doctor for this booking type.');
      return;
    }

    final schedule = _scheduledLocal;
    if (schedule == null) {
      _toast('Pick date and time for the visit.');
      return;
    }

    final navigator = Navigator.of(context);
    final rootMessenger = ScaffoldMessenger.of(widget.scaffoldContext);

    setState(() => _submitting = true);
    try {
      String patientId;
      final phone = _phoneCtrl.text.trim();
      final name = _nameCtrl.text.trim();

      if (_resolvedPatient != null) {
        patientId = _resolvedPatient!.id;
      } else {
        final draft = await widget.controller.ensureDraftPatient(
          fullName: name,
          phone: phone,
        );
        patientId = draft.id;
      }

      await widget.controller.createAppointment(
        patientId: patientId,
        clinicId: clinicId,
        doctorId: _type == ApiAppointmentType.specificDoctor ? _doctorId : null,
        patientName: name,
        phoneNumber: phone,
        scheduledAtUtc: schedule.toUtc(),
        type: _type,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      if (!mounted) return;
      navigator.pop();
      if (widget.scaffoldContext.mounted) {
        rootMessenger.showSnackBar(
          const SnackBar(content: Text('Appointment created')),
        );
      }
    } on DioException catch (e) {
      final body = e.response?.data;
      final msg = body is Map
          ? body['message']?.toString() ?? body.toString()
          : body?.toString();
      _toast(msg ?? e.message ?? 'Could not create appointment');
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheduleLabel = _scheduledLocal == null
        ? 'Tap to choose'
        : formatLocalWallDateTimeLine(_scheduledLocal!);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('New appointment', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                border: OutlineInputBorder(),
              ),
              onChanged: _onPhoneChanged,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
            ),
            const SizedBox(height: 8),
            if (_lookupLoading)
              const LinearProgressIndicator(minHeight: 2)
            else if (_lookupError != null)
              Text(_lookupError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12))
            else if (_phoneCtrl.text.trim().length >= 6)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_resolvedPatient != null)
                    Chip(
                      avatar: const Icon(Icons.person, size: 18),
                      label: const Text('On file'),
                      visualDensity: VisualDensity.compact,
                    )
                  else
                    Chip(
                      avatar: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('New patient'),
                      backgroundColor: const Color(0xFFE8F5E9),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Patient name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            Text('Booking type', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<ApiAppointmentType>(
              segments: const [
                ButtonSegment(
                  value: ApiAppointmentType.general,
                  label: Text('General'),
                  icon: Icon(Icons.medical_services_outlined),
                ),
                ButtonSegment(
                  value: ApiAppointmentType.specificDoctor,
                  label: Text('Doctor'),
                  icon: Icon(Icons.person_outline),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) {
                setState(() {
                  _type = s.first;
                  if (_type == ApiAppointmentType.general) _doctorId = null;
                });
              },
            ),
            if (_type == ApiAppointmentType.specificDoctor) ...[
              const SizedBox(height: 12),
              if (_doctorsLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_doctors.isEmpty)
                Text(
                  'No doctors are registered for this clinic yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                )
              else
                DropdownButtonFormField<int>(
                  value: _doctorId,
                  decoration: const InputDecoration(
                    labelText: 'Doctor',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final d in _doctors)
                      DropdownMenuItem<int>(
                        value: (d['id'] as num).toInt(),
                        child: Text(
                          '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim(),
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _doctorId = v),
                ),
            ],
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visit time'),
              subtitle: Text(scheduleLabel),
              trailing: const Icon(Icons.schedule),
              onTap: _pickSchedule,
            ),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g. Patient arrived — checked in at desk',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF004D40),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Text('Create appointment'),
            ),
          ],
        ),
      ),
    );
  }
}
