import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/enums/appointment_booking_type.dart';
import '../../core/enums/doctor_specialization.dart';
import '../../core/formatting/appointment_time_display.dart';
import '../../core/models/backend_models.dart';
import '../../core/models/clinic_summary.dart';
import '../../core/models/doctor_summary.dart';
import '../../core/network/backend_api_client.dart';
import '../../core/network/session_manager.dart';

/// Multi-step booking: clinic → department → general vs doctor → time → submit.
/// Request is scoped to the chosen clinic’s reception (integrate with backend).
class PatientBookingFlowScreen extends StatefulWidget {
  const PatientBookingFlowScreen({super.key, this.initialClinic});

  /// When null, the first step lists all registered clinics.
  final ClinicSummary? initialClinic;

  @override
  State<PatientBookingFlowScreen> createState() => _PatientBookingFlowScreenState();
}

class _PatientBookingFlowScreenState extends State<PatientBookingFlowScreen> {
  ClinicSummary? _clinic;
  DoctorSpecialization? _department;
  AppointmentBookingType _bookingType = AppointmentBookingType.general;
  DoctorSummary? _selectedDoctor;
  DateTime? _preferredDateTime;

  static const int _wizardStepsAfterClinic = 4;

  /// 0 = department, 1 = assignment, 2 = schedule, 3 = review
  int _wizardStep = 0;

  late Future<List<ClinicSummary>> _clinicsFuture;
  bool _rosterLoading = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _clinic = widget.initialClinic;
    _clinicsFuture = _fetchClinics();
    if (_clinic != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateRoster());
    }
  }

  Future<List<ClinicSummary>> _fetchClinics() async {
    final raw = await BackendApiClient.instance.getClinics();
    return raw.map(ClinicSummary.fromApiClinic).toList();
  }

  Future<void> _hydrateRoster() async {
    final c = _clinic;
    if (c == null || !mounted) return;
    if (c.doctors != null) return;

    setState(() => _rosterLoading = true);
    try {
      final id = int.parse(c.id);
      final raw = await BackendApiClient.instance.getDoctorsByClinic(id);
      final roster = raw.map(DoctorSummary.fromApi).toList();
      if (!mounted) return;
      setState(() {
        _clinic = c.withDoctors(roster);
        _rosterLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _clinic = c.withDoctors(const []);
        _rosterLoading = false;
      });
    }
  }

  void _selectClinic(ClinicSummary c) {
    setState(() {
      _clinic = c;
      _department = null;
      _selectedDoctor = null;
      _wizardStep = 0;
    });
    _hydrateRoster();
  }

  bool get _clinicChosen => _clinic != null;

  int get _totalSteps =>
      (widget.initialClinic == null ? 1 : 0) + _wizardStepsAfterClinic;

  int get _currentOverallStep {
    if (!_clinicChosen) return 0;
    return (widget.initialClinic == null ? 1 : 0) + _wizardStep;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book a visit'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_clinicChosen) _RecordLinkBanner(clinicName: _clinic!.name),
          LinearProgressIndicator(
            value: (_currentOverallStep + 1) / _totalSteps,
          ),
          Expanded(
            child: !_clinicChosen ? _buildClinicPicker() : _buildWizardPage(),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildClinicPicker() {
    return FutureBuilder<List<ClinicSummary>>(
      future: _clinicsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Could not load clinics: ${snap.error}'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(() => _clinicsFuture = _fetchClinics()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final list = snap.data ?? const <ClinicSummary>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Select a clinic',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Clinics from the server. After you choose one, we load doctors for booking.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            if (list.isEmpty)
              const Text('No clinics are available yet.'),
            for (final c in list)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _selectClinic(c),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: Theme.of(context).textTheme.titleMedium),
                        if (c.address != null && c.address!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            c.address!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (c.phone != null && c.phone!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            c.phone!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          '${c.doctorCount ?? 0} doctors',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWizardPage() {
    if (_rosterLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return switch (_wizardStep) {
      0 => _DepartmentStep(
          clinic: _clinic!,
          selected: _department,
          onSelected: (d) => setState(() {
            _department = d;
            _selectedDoctor = null;
            _bookingType = AppointmentBookingType.general;
          }),
        ),
      1 => _AssignmentStep(
          department: _department!,
          clinic: _clinic!,
          bookingType: _bookingType,
          selectedDoctor: _selectedDoctor,
          onTypeChanged: (t) => setState(() {
            _bookingType = t;
            if (t == AppointmentBookingType.general) {
              _selectedDoctor = null;
            }
          }),
          onDoctorSelected: (d) => setState(() => _selectedDoctor = d),
        ),
      2 => _ScheduleStep(
          preferred: _preferredDateTime,
          onChanged: (dt) => setState(() => _preferredDateTime = dt),
        ),
      _ => _ReviewStep(
          clinic: _clinic!,
          department: _department!,
          bookingType: _bookingType,
          doctor: _selectedDoctor,
          preferred: _preferredDateTime,
        ),
    };
  }

  Widget _buildBottomBar() {
    if (!_clinicChosen) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Tap a clinic to continue.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final isFirstWizard = _wizardStep == 0;
    final isLastWizard = _wizardStep == 3;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (!isFirstWizard)
              TextButton(
                onPressed: () => setState(() => _wizardStep -= 1),
                child: const Text('Back'),
              )
            else if (widget.initialClinic == null)
              TextButton(
                onPressed: () => setState(() {
                  _clinic = null;
                  _department = null;
                  _selectedDoctor = null;
                  _preferredDateTime = null;
                  _wizardStep = 0;
                }),
                child: const Text('Change clinic'),
              ),
            const Spacer(),
            if (!isLastWizard)
              FilledButton(
                onPressed: _canGoNext ? () => setState(() => _wizardStep += 1) : null,
                child: const Text('Next'),
              )
            else
              FilledButton(
                onPressed: (_canSubmit && !_submitting) ? _submit : null,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Text('Submit request'),
              ),
          ],
        ),
      ),
    );
  }

  bool get _canGoNext {
    return switch (_wizardStep) {
      0 => _department != null,
      1 =>
        _bookingType == AppointmentBookingType.general ||
            (_bookingType == AppointmentBookingType.specificDoctor &&
                _selectedDoctor != null),
      2 => _preferredDateTime != null,
      _ => false,
    };
  }

  bool get _canSubmit =>
      _department != null &&
      _preferredDateTime != null &&
      (_bookingType == AppointmentBookingType.general || _selectedDoctor != null);

  Future<void> _submit() async {
    if (!_canSubmit || _clinic == null || _department == null) return;

    final patientId = SessionManager.instance.patientId;
    if (patientId == null || patientId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your account is missing a patient id. Sign out and sign in again, then retry.',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final profile = await BackendApiClient.instance.getPatientMe();
      if (profile.id.isNotEmpty && profile.id != patientId) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile id does not match your session. Please sign in again.'),
          ),
        );
        return;
      }

      final clinicId = int.parse(_clinic!.id);
      final doctorId = _bookingType == AppointmentBookingType.specificDoctor
          ? int.tryParse(_selectedDoctor!.id)
          : null;

      await BackendApiClient.instance.createAppointment(
        patientId: patientId,
        clinicId: clinicId,
        doctorId: doctorId,
        patientName: profile.fullName,
        phoneNumber: profile.phoneNumber,
        scheduledAtUtc: _preferredDateTime!.toUtc(),
        type: _bookingType == AppointmentBookingType.general
            ? ApiAppointmentType.general.value
            : ApiAppointmentType.specificDoctor.value,
        notes: 'Requested department: ${_department!.label}',
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Request sent'),
          content: Text(
            'Your booking at ${_clinic!.name} is linked to your profile and is waiting for clinic approval. '
            'You can track it under My appointments.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final body = e.response?.data;
      final msg = body is Map
          ? body['message']?.toString() ?? body.toString()
          : body?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg ?? e.message ?? 'Could not submit booking')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _RecordLinkBanner extends StatelessWidget {
  const _RecordLinkBanner({required this.clinicName});

  final String clinicName;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You can have records in multiple clinics. For $clinicName: '
                'if a record already exists it will be linked; if not, a new '
                'patient record is created automatically when your visit is confirmed.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentStep extends StatelessWidget {
  const _DepartmentStep({
    required this.clinic,
    required this.selected,
    required this.onSelected,
  });

  final ClinicSummary clinic;
  final DoctorSpecialization? selected;
  final ValueChanged<DoctorSpecialization> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Department', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Choose the type of visit at ${clinic.name}.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        for (final spec in clinic.availableSpecialties)
          RadioListTile<DoctorSpecialization>(
            title: Text(spec.label),
            value: spec,
            groupValue: selected,
            onChanged: (value) {
              if (value != null) onSelected(value);
            },
          ),
      ],
    );
  }
}

class _AssignmentStep extends StatelessWidget {
  const _AssignmentStep({
    required this.department,
    required this.clinic,
    required this.bookingType,
    required this.selectedDoctor,
    required this.onTypeChanged,
    required this.onDoctorSelected,
  });

  final DoctorSpecialization department;
  final ClinicSummary clinic;
  final AppointmentBookingType bookingType;
  final DoctorSummary? selectedDoctor;
  final ValueChanged<AppointmentBookingType> onTypeChanged;
  final ValueChanged<DoctorSummary> onDoctorSelected;

  List<DoctorSummary> get _doctorsInDept {
    final all = clinic.doctors;
    if (all == null) return const [];
    return all.where((d) => d.specialization == department).toList();
  }

  @override
  Widget build(BuildContext context) {
    final doctors = _doctorsInDept;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Doctor', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Pick a specific doctor or request any available doctor in ${department.label}.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        RadioListTile<AppointmentBookingType>(
          title: const Text('General booking'),
          subtitle: const Text('Any available doctor in this department'),
          value: AppointmentBookingType.general,
          groupValue: bookingType,
          onChanged: (value) {
            if (value != null) onTypeChanged(value);
          },
        ),
        RadioListTile<AppointmentBookingType>(
          title: const Text('Specific doctor'),
          value: AppointmentBookingType.specificDoctor,
          groupValue: bookingType,
          onChanged: doctors.isEmpty
              ? null
              : (value) {
                  if (value != null) onTypeChanged(value);
                },
        ),
        if (bookingType == AppointmentBookingType.specificDoctor && doctors.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Text(
              'No doctors are listed for this department yet. Choose general booking or contact reception.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
        if (bookingType == AppointmentBookingType.specificDoctor)
          for (final d in doctors)
            RadioListTile<DoctorSummary>(
              title: Text(d.name),
              subtitle: Text(d.specialization.label),
              value: d,
              groupValue: selectedDoctor,
              onChanged: (value) {
                if (value != null) onDoctorSelected(value);
              },
            ),
      ],
    );
  }
}

class _ScheduleStep extends StatelessWidget {
  const _ScheduleStep({
    required this.preferred,
    required this.onChanged,
  });

  final DateTime? preferred;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: preferred ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(preferred ?? now),
    );
    if (time == null || !context.mounted) return;

    onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Preferred time', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Reception will confirm or propose another slot.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 24),
        if (preferred != null)
          Text(
            formatLocalWallDateTimeLine(preferred!),
            style: Theme.of(context).textTheme.titleMedium,
          )
        else
          Text(
            'No time selected',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _pickDateTime(context),
          icon: const Icon(Icons.event),
          label: const Text('Choose date & time'),
        ),
      ],
    );
  }

}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.clinic,
    required this.department,
    required this.bookingType,
    required this.doctor,
    required this.preferred,
  });

  final ClinicSummary clinic;
  final DoctorSpecialization department;
  final AppointmentBookingType bookingType;
  final DoctorSummary? doctor;
  final DateTime? preferred;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Review', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _ReviewRow(label: 'Clinic', value: clinic.name),
        _ReviewRow(label: 'Department', value: department.label),
        _ReviewRow(
          label: 'Booking',
          value: bookingType == AppointmentBookingType.general
              ? 'General (any available doctor)'
              : 'Dr. ${doctor?.name ?? '—'}',
        ),
        _ReviewRow(
          label: 'Preferred time',
          value: preferred != null ? formatLocalWallDateTimeLine(preferred!) : '—',
        ),
        const SizedBox(height: 16),
        Text(
          'This request goes only to ${clinic.name} reception.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
