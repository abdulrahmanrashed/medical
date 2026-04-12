import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatting/appointment_time_display.dart';
import '../../core/layout/responsive.dart';
import '../../core/models/backend_models.dart';
import '../../core/network/backend_api_client.dart';
import '../../core/notifications/medication_reminder_service.dart';

/// Diagnosis, medications with local reminder toggles, requested tests, and uploads.
class PatientMedicalHistoryScreen extends StatefulWidget {
  const PatientMedicalHistoryScreen({super.key});

  @override
  State<PatientMedicalHistoryScreen> createState() =>
      _PatientMedicalHistoryScreenState();
}

class _PatientMedicalHistoryScreenState
    extends State<PatientMedicalHistoryScreen> {
  late Future<PatientMedicalHistory> _future;
  Map<int, bool> _reminderOn = {};
  int? _uploadForAppointmentId;
  late Future<List<ApiAppointment>> _myAppointments;

  @override
  void initState() {
    super.initState();
    _myAppointments =
        BackendApiClient.instance.getAllAppointmentsAccumulated(pageSize: 40);
    _future = _load();
  }

  Future<PatientMedicalHistory> _load() async {
    final h = await BackendApiClient.instance.getPatientMedicalHistory();
    final map = <int, bool>{};
    for (final p in h.activeAppointmentPrescriptions) {
      map[p.id] = await MedicationReminderService.instance.isReminderEnabled(p.id);
    }
    await MedicationReminderService.instance.syncAppointmentPrescriptions(
      h.activeAppointmentPrescriptions,
    );
    if (mounted) {
      setState(() => _reminderOn = map);
    } else {
      _reminderOn = map;
    }
    return h;
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _openFile(ApiMedicalFile f) async {
    final url = BackendApiClient.instance.medicalFileUrl(f);
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open file')),
      );
    }
  }

  Future<void> _pickUpload() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
      withData: false,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.single;
    final path = f.path;
    if (path == null || path.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file path')),
        );
      }
      return;
    }
    try {
      await BackendApiClient.instance.uploadPatientMedicalFile(
        appointmentId: _uploadForAppointmentId,
        filePath: path,
        fileName: f.name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload complete')),
        );
      }
      await _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _toggleReminder(ApiAppointmentPrescription p, bool on) async {
    await MedicationReminderService.instance.setReminderEnabled(p.id, on);
    if (on) {
      await MedicationReminderService.instance.schedulePrescription(p);
    } else {
      await MedicationReminderService.instance.cancelPrescriptionNotifications(
        p.id,
        p.timesPerDay,
      );
    }
    if (mounted) {
      setState(() => _reminderOn[p.id] = on);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.screenPadding(context);
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<PatientMedicalHistory>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
                const Center(child: CircularProgressIndicator()),
              ],
            );
          }
          if (snap.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              children: [
                Text('Could not load: ${snap.error}'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _reload, child: const Text('Retry')),
              ],
            );
          }
          final h = snap.data!;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            children: [
              Text(
                'Medical history',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: Responsive.titleSize(context),
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Diagnosis from your latest visit record, active prescriptions, and your documents.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              _SectionTitle(icon: Icons.assignment_outlined, label: 'Current diagnosis & notes'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (h.latestMedicalRecordAtUtc != null)
                        Text(
                          'Last visit record: ${formatAppointmentDateTimeLine(h.latestMedicalRecordAtUtc!)}',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      if (h.latestMedicalRecordAtUtc != null) const SizedBox(height: 8),
                      Text(
                        h.currentDiagnosis?.trim().isNotEmpty == true
                            ? h.currentDiagnosis!.trim()
                            : 'No diagnosis on file yet.',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        h.currentClinicalNotes?.trim().isNotEmpty == true
                            ? h.currentClinicalNotes!.trim()
                            : 'No clinical notes on file yet.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SectionTitle(icon: Icons.science_outlined, label: 'Requested tests'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    h.requestedTests?.trim().isNotEmpty == true
                        ? h.requestedTests!.trim()
                        : 'No pending test requests from your clinic.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SectionTitle(icon: Icons.medication_outlined, label: 'Medications & reminders'),
              const SizedBox(height: 8),
              if (h.activeAppointmentPrescriptions.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No active appointment prescriptions. Your doctor can add these during a visit.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                for (final p in h.activeAppointmentPrescriptions)
                  Card(
                    child: ListTile(
                      title: Text(p.medicationName),
                      subtitle: Text(
                        '${p.dosage} · ${p.timesPerDay}× daily · '
                        'from ${formatAppointmentDateIso(p.startDateUtc)}'
                        '${p.endDateUtc != null ? ' to ${formatAppointmentDateIso(p.endDateUtc!)}' : ''}',
                      ),
                      isThreeLine: true,
                      trailing: Switch(
                        value: _reminderOn[p.id] ?? true,
                        onChanged: (v) => _toggleReminder(p, v),
                      ),
                    ),
                  ),
              const SizedBox(height: 20),
              _SectionTitle(icon: Icons.folder_open_outlined, label: 'Documents'),
              const SizedBox(height: 8),
              FutureBuilder<List<ApiAppointment>>(
                future: _myAppointments,
                builder: (context, snap) {
                  final items = snap.data ?? const <ApiAppointment>[];
                  if (items.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<int?>(
                      value: _uploadForAppointmentId,
                      decoration: const InputDecoration(
                        labelText: 'Link upload to a visit (so your doctor sees it)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Not linked to a specific visit'),
                        ),
                        ...items.map(
                          (a) => DropdownMenuItem<int?>(
                            value: a.id,
                            child: Text(
                              '${a.clinicName ?? "Clinic"} · ${formatAppointmentDateIso(a.scheduledAtUtc)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _uploadForAppointmentId = v),
                    ),
                  );
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: _pickUpload,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload lab / imaging'),
                ),
              ),
              const SizedBox(height: 8),
              if (h.medicalFiles.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No files uploaded yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                for (final f in h.medicalFiles)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        f.fileType.toLowerCase().contains('pdf')
                            ? Icons.picture_as_pdf
                            : Icons.image_outlined,
                      ),
                      title: Text(f.fileName),
                      subtitle: Text(
                        formatAppointmentDateTimeLine(f.createdAtUtc),
                      ),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _openFile(f),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: const Color(0xFF004D40)),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF004D40),
              ),
        ),
      ],
    );
  }
}
