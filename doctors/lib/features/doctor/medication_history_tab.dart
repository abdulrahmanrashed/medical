import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/formatting/appointment_time_display.dart';
import '../../core/layout/responsive.dart';
import '../../core/models/backend_models.dart';

const Color _kMedicalTeal = Color(0xFF004D40);

/// One prescribed line with its clinical session context (visit = medical record).
class MedicationHistoryLine {
  const MedicationHistoryLine({
    required this.med,
    required this.sessionId,
    required this.visitUtc,
    required this.doctorName,
    required this.prescriptionId,
  });

  final ApiMedication med;
  final int sessionId;
  final DateTime visitUtc;
  final String doctorName;
  final int prescriptionId;
}

List<MedicationHistoryLine> medicationHistoryLinesFromTimeline(
  List<ApiMedicalRecordDetail> timeline,
) {
  final out = <MedicationHistoryLine>[];
  for (final r in timeline) {
    for (final p in r.prescriptions) {
      for (final m in p.medications) {
        out.add(
          MedicationHistoryLine(
            med: m,
            sessionId: r.id,
            visitUtc: r.createdAtUtc,
            doctorName: r.doctorName,
            prescriptionId: p.id,
          ),
        );
      }
    }
  }
  return out;
}

String? _durationFromInstructions(String? instructions) {
  if (instructions == null || instructions.trim().isEmpty) return null;
  final m = RegExp(
    r'(\d+)\s*(day|days|week|weeks|month|months)',
    caseSensitive: false,
  ).firstMatch(instructions);
  if (m != null) return '${m[1]} ${m[2]}';
  return null;
}

bool _chronicHeuristic(ApiMedication m) {
  final t = '${m.instructions ?? ''} ${m.schedule} ${m.name}'.toLowerCase();
  return t.contains('chronic') ||
      t.contains('long-term') ||
      t.contains('long term') ||
      t.contains('ongoing') ||
      t.contains('maintenance');
}

/// Timeline of all prescriptions for this patient, grouped by visit date → session.
class MedicationHistoryTab extends StatefulWidget {
  const MedicationHistoryTab({
    super.key,
    required this.timeline,
    required this.readOnly,
    this.onCopyToCurrentVisit,
  });

  final List<ApiMedicalRecordDetail> timeline;
  final bool readOnly;

  /// When non-null and [readOnly] is false, shows "Copy to current visit" on each row.
  final Future<void> Function(ApiMedication med)? onCopyToCurrentVisit;

  @override
  State<MedicationHistoryTab> createState() => _MedicationHistoryTabState();
}

class _MedicationHistoryTabState extends State<MedicationHistoryTab> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.screenPadding(context);
    final dateFmt = DateFormat.yMMMMd();
    final allLines = medicationHistoryLinesFromTimeline(widget.timeline);
    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? allLines
        : allLines.where((l) => l.med.name.toLowerCase().contains(q)).toList();

    // Group: date → sessionId → lines
    final byDate = <DateTime, Map<int, List<MedicationHistoryLine>>>{};
    for (final line in filtered) {
      final local = line.visitUtc.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      byDate.putIfAbsent(day, () => {});
      byDate[day]!.putIfAbsent(line.sessionId, () => []).add(line);
    }
    final sortedDays = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    if (allLines.isEmpty) {
      return ListView(
        padding: padding,
        children: [
          Text(
            'Medication history',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _kMedicalTeal,
                ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No prescriptions on file yet. Entries appear after visits with medications.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medication history',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _kMedicalTeal,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Grouped by visit date. Session = clinical visit (medical record).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search by medicine name',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: padding,
                child: Text(
                  'No medicines match “${_search.text.trim()}”.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: padding.copyWith(top: 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final day = sortedDays[index];
                  final sessions = byDate[day]!;
                  final sessionIds = sessions.keys.toList()
                    ..sort((a, b) {
                      final ta = sessions[a]!.first.visitUtc;
                      final tb = sessions[b]!.first.visitUtc;
                      return tb.compareTo(ta);
                    });
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _VisitDateSection(
                      day: day,
                      dateFmt: dateFmt,
                      sessionIds: sessionIds,
                      sessions: sessions,
                      onCopy: widget.readOnly ? null : widget.onCopyToCurrentVisit,
                    ),
                  );
                },
                childCount: sortedDays.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _VisitDateSection extends StatelessWidget {
  const _VisitDateSection({
    required this.day,
    required this.dateFmt,
    required this.sessionIds,
    required this.sessions,
    required this.onCopy,
  });

  final DateTime day;
  final DateFormat dateFmt;
  final List<int> sessionIds;
  final Map<int, List<MedicationHistoryLine>> sessions;
  final Future<void> Function(ApiMedication med)? onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: _kMedicalTeal,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              dateFmt.format(day),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _kMedicalTeal,
                  ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.only(left: 14),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: _kMedicalTeal.withValues(alpha: 0.35), width: 2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: sessionIds
                  .map(
                    (sid) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SessionMedCard(
                        lines: sessions[sid]!,
                        onCopy: onCopy,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionMedCard extends StatelessWidget {
  const _SessionMedCard({
    required this.lines,
    required this.onCopy,
  });

  final List<MedicationHistoryLine> lines;
  final Future<void> Function(ApiMedication med)? onCopy;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final first = lines.first;
    final visit = first.visitUtc;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.event_note_outlined, size: 18, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Session #${first.sessionId}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${formatAppointmentTimeHm(visit)} · ${first.doctorName.trim().isEmpty ? 'Doctor' : first.doctorName.trim()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Visit date: ${formatAppointmentDateIso(visit)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const Divider(height: 20),
            ...lines.map((l) => _MedicineRow(line: l, onCopy: onCopy)),
          ],
        ),
      ),
    );
  }
}

class _MedicineRow extends StatefulWidget {
  const _MedicineRow({
    required this.line,
    required this.onCopy,
  });

  final MedicationHistoryLine line;
  final Future<void> Function(ApiMedication med)? onCopy;

  @override
  State<_MedicineRow> createState() => _MedicineRowState();
}

class _MedicineRowState extends State<_MedicineRow> {
  bool _copying = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.line.med;
    final chronic = _chronicHeuristic(m);
    final duration = _durationFromInstructions(m.instructions);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: chronic ? const Color(0xFFE8F5E9) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: chronic ? const Color(0xFF2E7D32).withValues(alpha: 0.45) : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      m.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  if (chronic)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Chip(
                        avatar: Icon(Icons.all_inclusive, size: 16, color: Colors.green.shade700),
                        label: const Text('Chronic'),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.green.shade100,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _detailRow(context, 'Dosage', m.dosage.isEmpty ? '—' : m.dosage),
              _detailRow(context, 'Frequency', m.schedule.isEmpty ? '—' : m.schedule),
              _detailRow(context, 'Duration', duration ?? '—'),
              if (m.instructions != null && m.instructions!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Instructions: ${m.instructions}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (widget.onCopy != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _copying
                        ? null
                        : () async {
                            setState(() => _copying = true);
                            try {
                              await widget.onCopy!(m);
                            } finally {
                              if (mounted) setState(() => _copying = false);
                            }
                          },
                    icon: _copying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.copy_all_outlined, size: 18),
                    label: Text(_copying ? 'Adding…' : 'Copy to current visit'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
