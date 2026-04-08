import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/layout/responsive.dart';
import '../../core/network/backend_api_client.dart';
import 'clinic_owner_ui.dart';

const Color _kPrimary = Color(0xFF004D40);
const Color _kWorkingGreen = Color(0xFF2E7D32);
const Color _kOffRust = Color(0xFFB71C1C);

/// Clinic admin: bulk and per-row doctor schedules; list grouped by calendar month for browsing.
class ClinicScheduleManagementScreen extends StatefulWidget {
  const ClinicScheduleManagementScreen({
    super.key,
    required this.clinicId,
    this.embedded = false,
    this.onReloadReady,
  });

  final int clinicId;
  final bool embedded;
  final void Function(Future<void> Function() reload)? onReloadReady;

  @override
  State<ClinicScheduleManagementScreen> createState() => _ClinicScheduleManagementScreenState();
}

class _ClinicScheduleManagementScreenState extends State<ClinicScheduleManagementScreen> {
  late Future<_SchedulePageData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onReloadReady?.call(() async {
        await _reload();
      });
    });
  }

  Future<_SchedulePageData> _load() async {
    final doctors = await BackendApiClient.instance.getDoctorsByClinic(widget.clinicId);
    final active = doctors.where((d) => d['isActive'] != false).toList();
    final now = DateTime.now();
    final from = DateTime(now.year - 1, now.month, now.day);
    final to = DateTime(now.year + 2, now.month, now.day);
    final schedules = await BackendApiClient.instance.getWorkSchedules(
      widget.clinicId,
      from: from.toIso8601String().split('T').first,
      to: to.toIso8601String().split('T').first,
    );
    return _SchedulePageData(activeDoctors: active, schedules: schedules);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.screenPadding(context);
    final body = _buildScheduleBody(padding);

    if (widget.embedded) {
      return Container(color: ClinicOwnerUi.surface, child: body);
    }

    return Scaffold(
      backgroundColor: ClinicOwnerUi.surface,
      appBar: AppBar(
        title: const Text('Manage schedules'),
        backgroundColor: ClinicOwnerUi.surface,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showClinicOwnerAddScheduleSheet(
            context,
            clinicId: widget.clinicId,
            onSuccess: _reload,
          );
        },
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add schedule'),
      ),
      body: body,
    );
  }

  Widget _buildScheduleBody(EdgeInsets padding) {
    final bottomInset = widget.embedded ? 24.0 : 100.0;

    return FutureBuilder<_SchedulePageData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: padding,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Could not load schedules: ${snap.error}'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }
        final data = snap.data!;
        if (data.schedules.isEmpty) {
          return Center(
            child: Padding(
              padding: padding,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month_outlined, size: 56, color: Colors.grey.shade500),
                  const SizedBox(height: 16),
                  Text(
                    'No schedule entries yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.embedded
                        ? 'Use the Add schedule action to set working hours or days off.'
                        : 'Use Add schedule to set working hours or days off.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          );
        }

        final grouped = _groupSchedulesByMonth(data.schedules);
        final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.builder(
            padding: padding.copyWith(bottom: bottomInset),
            itemCount: keys.length,
            itemBuilder: (context, sectionIndex) {
              final key = keys[sectionIndex];
              final items = grouped[key]!;
              final headerDate = _monthKeyToDate(key);
              final title = headerDate != null ? DateFormat.yMMMM().format(headerDate) : key;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final cols = Responsive.gridColumnCount(constraints.maxWidth);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          top: sectionIndex == 0 ? 0 : 20,
                          bottom: 10,
                        ),
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: _kPrimary,
                              ),
                        ),
                      ),
                      if (cols == 1)
                        ...items.map(
                          (row) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ScheduleEntryCard(
                              row: row,
                              onChanged: _reload,
                            ),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 280,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, i) => _ScheduleEntryCard(
                            row: items[i],
                            onChanged: _reload,
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// Opens add-schedule sheet (for embedded shell FAB or external callers).
Future<void> showClinicOwnerAddScheduleSheet(
  BuildContext context, {
  required int clinicId,
  required Future<void> Function() onSuccess,
}) async {
  final doctors = await BackendApiClient.instance.getDoctorsByClinic(clinicId);
  final active = doctors.where((d) => d['isActive'] != false).toList();
  if (!context.mounted) return;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => _AddScheduleSheet(clinicId: clinicId, doctors: active),
  );
  if (ok == true && context.mounted) await onSuccess();
}

class _SchedulePageData {
  const _SchedulePageData({required this.activeDoctors, required this.schedules});

  final List<Map<String, dynamic>> activeDoctors;
  final List<Map<String, dynamic>> schedules;
}

Map<String, List<Map<String, dynamic>>> _groupSchedulesByMonth(List<Map<String, dynamic>> schedules) {
  final map = <String, List<Map<String, dynamic>>>{};
  for (final s in schedules) {
    final dt = _parseShiftDate(s['shiftDate']);
    if (dt == null) continue;
    final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
    map.putIfAbsent(key, () => []).add(s);
  }
  for (final list in map.values) {
    list.sort((a, b) {
      final da = _parseShiftDate(a['shiftDate']);
      final db = _parseShiftDate(b['shiftDate']);
      if (da == null || db == null) return 0;
      return db.compareTo(da);
    });
  }
  return map;
}

DateTime? _parseShiftDate(dynamic v) {
  if (v == null) return null;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

DateTime? _monthKeyToDate(String key) {
  final parts = key.split('-');
  if (parts.length != 2) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (y == null || m == null) return null;
  return DateTime(y, m);
}

/// Label for weekly bulk: start date through +6 days (7 total).
String _weekRangeSubtitle(DateTime weekStart) {
  final s = DateTime(weekStart.year, weekStart.month, weekStart.day);
  final e = s.add(const Duration(days: 6));
  return '${DateFormat.yMMMd().format(s)} – ${DateFormat.yMMMd().format(e)} · 7 days';
}

bool _isScheduleWorking(Map<String, dynamic> row) {
  final s = row['status'];
  if (s is int) return s == 0;
  final t = s?.toString().toLowerCase() ?? '';
  return t == '0' || t == 'working';
}

bool _canEditSchedule(Map<String, dynamic> row) {
  final dt = _parseShiftDate(row['shiftDate']);
  if (dt == null) return false;
  final today = DateTime.now();
  final d = DateTime(dt.year, dt.month, dt.day);
  final t = DateTime(today.year, today.month, today.day);
  return !d.isBefore(t);
}

class _ScheduleEntryCard extends StatelessWidget {
  const _ScheduleEntryCard({
    required this.row,
    required this.onChanged,
  });

  final Map<String, dynamic> row;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final working = _isScheduleWorking(row);
    final dt = _parseShiftDate(row['shiftDate']);
    final dateStr = dt != null ? DateFormat.yMMMd().format(dt) : '—';
    final first = row['doctorFirstName']?.toString() ?? '';
    final last = row['doctorLastName']?.toString() ?? '';
    final name = '$first $last'.trim().isEmpty ? 'Doctor #${row['doctorId']}' : '$first $last'.trim();
    final canEdit = _canEditSchedule(row);

    final accent = working ? _kWorkingGreen : _kOffRust;
    final bg = working ? Colors.green.shade50 : Colors.red.shade50;

    TimeOfDay? parseTime(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      final parts = s.split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0].trim());
      final m = int.tryParse(parts[1].trim());
      if (h == null || m == null) return null;
      return TimeOfDay(hour: h, minute: m);
    }

    final start = parseTime(row['startTime']);
    final end = parseTime(row['endTime']);
    final timeLine = working && start != null && end != null
        ? '${start.format(context)} – ${end.format(context)}'
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: accent.withValues(alpha: 0.35)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!working)
                            Chip(
                              label: const Text('OFF'),
                              backgroundColor: _kOffRust.withValues(alpha: 0.15),
                              labelStyle: const TextStyle(
                                color: _kOffRust,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            )
                          else
                            Chip(
                              label: const Text('Working'),
                              backgroundColor: _kWorkingGreen.withValues(alpha: 0.15),
                              labelStyle: const TextStyle(
                                color: _kWorkingGreen,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              dateStr,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (working && timeLine != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 16, color: _kWorkingGreen),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                timeLine,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: _kWorkingGreen,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (row['notes'] != null && row['notes'].toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          row['notes'].toString(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: canEdit
                              ? () async {
                                  final ok = await showModalBottomSheet<bool>(
                                    context: context,
                                    isScrollControlled: true,
                                    showDragHandle: true,
                                    useSafeArea: true,
                                    builder: (ctx) => _EditScheduleSheet(row: row),
                                  );
                                  if (ok == true && context.mounted) await onChanged();
                                }
                              : null,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _BulkMode { daily, weekly }

class _AddScheduleSheet extends StatefulWidget {
  const _AddScheduleSheet({required this.clinicId, required this.doctors});

  final int clinicId;
  final List<Map<String, dynamic>> doctors;

  @override
  State<_AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends State<_AddScheduleSheet> {
  _BulkMode _mode = _BulkMode.daily;
  int? _doctorId;
  DateTime _singleDay = DateTime.now();
  /// First day of a fixed 7-day block (server applies this day through +6).
  DateTime _weekStart = DateTime.now();
  bool _working = true;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  String _fmtTimeApi(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String _fmtDateApi(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_doctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a doctor.')));
      return;
    }
    if (_working) {
      final sm = _start.hour * 60 + _start.minute;
      final em = _end.hour * 60 + _end.minute;
      if (em <= sm) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time.')),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final body = <String, dynamic>{
        'doctorId': _doctorId,
        'mode': _mode.index,
        'status': _working ? 0 : 1,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        if (_working) 'startTime': _fmtTimeApi(_start),
        if (_working) 'endTime': _fmtTimeApi(_end),
        if (!_working) 'startTime': null,
        if (!_working) 'endTime': null,
      };
      if (_mode == _BulkMode.daily) {
        body['singleDate'] = _fmtDateApi(_singleDay);
      } else {
        body['rangeStart'] = _fmtDateApi(_weekStart);
      }

      await BackendApiClient.instance.bulkWorkSchedules(widget.clinicId, body);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewInsetsOf(context);
    final docs = widget.doctors;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: pad.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add schedules', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Daily: one day. Weekly: 7 consecutive days from the start date you pick. Active doctors only.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: ValueKey(_doctorId),
              decoration: const InputDecoration(
                labelText: 'Doctor *',
                border: OutlineInputBorder(),
              ),
              initialValue: _doctorId,
              items: [
                for (final d in docs)
                  DropdownMenuItem(
                    value: (d['id'] as num?)?.toInt(),
                    child: Text(
                      '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: docs.isEmpty ? null : (v) => setState(() => _doctorId = v),
            ),
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No active doctors. Unfreeze a doctor or add one first.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            SegmentedButton<_BulkMode>(
              segments: const [
                ButtonSegment(value: _BulkMode.daily, label: Text('Daily'), icon: Icon(Icons.today)),
                ButtonSegment(value: _BulkMode.weekly, label: Text('Weekly'), icon: Icon(Icons.date_range)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 16),
            if (_mode == _BulkMode.daily)
              ListTile(
                title: const Text('Day'),
                subtitle: Text(DateFormat.yMMMd().format(_singleDay)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _singleDay.isBefore(today) ? today : _singleDay,
                    firstDate: today,
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (d != null) setState(() => _singleDay = d);
                },
              ),
            if (_mode == _BulkMode.weekly) ...[
              ListTile(
                title: const Text('Week starting'),
                subtitle: Text(_weekRangeSubtitle(_weekStart)),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _weekStart.isBefore(today) ? today : _weekStart,
                    firstDate: today,
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (d != null) setState(() => _weekStart = d);
                },
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Working'),
              subtitle: Text(_working ? 'Set shift hours' : 'Day off / holiday (no hours)'),
              value: _working,
              activeThumbColor: _kWorkingGreen,
              onChanged: (v) => setState(() => _working = v),
            ),
            if (_working) ...[
              ListTile(
                title: const Text('Start'),
                subtitle: Text(_start.format(context)),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _start);
                  if (t != null) setState(() => _start = t);
                },
              ),
              ListTile(
                title: const Text('End'),
                subtitle: Text(_end.format(context)),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _end);
                  if (t != null) setState(() => _end = t);
                },
              ),
            ],
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Annual leave, sick leave…',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kPrimary),
              onPressed: _submitting || docs.isEmpty || _doctorId == null ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save schedules'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditScheduleSheet extends StatefulWidget {
  const _EditScheduleSheet({required this.row});

  final Map<String, dynamic> row;

  @override
  State<_EditScheduleSheet> createState() => _EditScheduleSheetState();
}

class _EditScheduleSheetState extends State<_EditScheduleSheet> {
  late DateTime _day;
  late bool _working;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late final TextEditingController _notesCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final dt = _parseShiftDate(widget.row['shiftDate']) ?? DateTime.now();
    _day = DateTime(dt.year, dt.month, dt.day);
    _working = _isScheduleWorking(widget.row);
    TimeOfDay? pt(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      final parts = s.split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0].trim()) ?? 0;
      final m = int.tryParse(parts[1].trim()) ?? 0;
      return TimeOfDay(hour: h, minute: m);
    }

    _start = pt(widget.row['startTime']) ?? const TimeOfDay(hour: 9, minute: 0);
    _end = pt(widget.row['endTime']) ?? const TimeOfDay(hour: 17, minute: 0);
    _notesCtrl = TextEditingController(text: widget.row['notes']?.toString() ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  String _fmtTimeApi(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String _fmtDateApi(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_working) {
      final sm = _start.hour * 60 + _start.minute;
      final em = _end.hour * 60 + _end.minute;
      if (em <= sm) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time.')),
        );
        return;
      }
    }

    final id = (widget.row['id'] as num?)?.toInt();
    if (id == null) return;

    setState(() => _submitting = true);
    try {
      await BackendApiClient.instance.updateWorkSchedule(id, <String, dynamic>{
        'shiftDate': _fmtDateApi(_day),
        'status': _working ? 0 : 1,
        if (_working) 'startTime': _fmtTimeApi(_start),
        if (_working) 'endTime': _fmtTimeApi(_end),
        if (!_working) 'startTime': null,
        if (!_working) 'endTime': null,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: pad.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit schedule', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Date'),
              subtitle: Text(DateFormat.yMMMd().format(_day)),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _day,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (d != null) setState(() => _day = DateTime(d.year, d.month, d.day));
              },
            ),
            SwitchListTile(
              title: const Text('Working'),
              value: _working,
              onChanged: (v) => setState(() => _working = v),
            ),
            if (_working) ...[
              ListTile(
                title: const Text('Start'),
                subtitle: Text(_start.format(context)),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _start);
                  if (t != null) setState(() => _start = t);
                },
              ),
              ListTile(
                title: const Text('End'),
                subtitle: Text(_end.format(context)),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _end);
                  if (t != null) setState(() => _end = t);
                },
              ),
            ],
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kPrimary),
              onPressed: _submitting ? null : _save,
              child: _submitting
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
