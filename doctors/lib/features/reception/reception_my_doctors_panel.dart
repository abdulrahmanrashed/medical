import 'package:flutter/material.dart';

import '../../core/enums/doctor_specialization.dart';
import '../../core/layout/responsive.dart';
import '../../core/network/backend_api_client.dart';
import '../../core/network/session_manager.dart';

const Color _kPrimary = Color(0xFF004D40);

/// Clinic reception: doctors for [SessionManager.instance.assignedClinicId] only.
class ReceptionMyDoctorsPanel extends StatefulWidget {
  const ReceptionMyDoctorsPanel({super.key});

  @override
  ReceptionMyDoctorsPanelState createState() => ReceptionMyDoctorsPanelState();
}

class ReceptionMyDoctorsPanelState extends State<ReceptionMyDoctorsPanel> {
  late Future<List<Map<String, dynamic>>> _future;

  int? get _clinicId => SessionManager.instance.assignedClinicId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final id = _clinicId;
    if (id == null) return const [];
    return BackendApiClient.instance.getDoctorsByClinic(id);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _showAddDoctor() async {
    final clinicId = _clinicId;
    if (clinicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No clinic assigned to this account.')),
      );
      return;
    }

    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final licenseCtrl = TextEditingController();
    DoctorSpecialization spec = DoctorSpecialization.general;
    final formKey = GlobalKey<FormState>();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final pad = MediaQuery.viewInsetsOf(ctx);
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: pad.bottom + 20),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Add doctor', style: Theme.of(ctx).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        'Creates a login for your clinic (clinic #$clinicId).',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Temporary password *',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (v) =>
                            (v == null || v.length < 8) ? 'Min 8 characters' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: firstCtrl,
                        decoration: const InputDecoration(
                          labelText: 'First name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: lastCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Last name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<DoctorSpecialization>(
                        // ignore: deprecated_member_use
                        value: spec,
                        decoration: const InputDecoration(
                          labelText: 'Specialization',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final s in DoctorSpecialization.values)
                            DropdownMenuItem(value: s, child: Text(s.label)),
                        ],
                        onChanged: (v) {
                          if (v != null) setModal(() => spec = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: licenseCtrl,
                        decoration: const InputDecoration(
                          labelText: 'License (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: _kPrimary),
                        onPressed: () {
                          if (formKey.currentState?.validate() ?? false) {
                            Navigator.pop(ctx, true);
                          }
                        },
                        child: const Text('Register doctor'),
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

    try {
      if (ok == true) {
        await BackendApiClient.instance.registerDoctor(
          clinicId: clinicId,
          email: emailCtrl.text.trim(),
          password: passCtrl.text,
          firstName: firstCtrl.text.trim(),
          lastName: lastCtrl.text.trim(),
          specialization: spec.label,
          licenseNumber: licenseCtrl.text.trim().isEmpty ? null : licenseCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Doctor registered.')),
          );
          _reload();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    } finally {
      emailCtrl.dispose();
      passCtrl.dispose();
      firstCtrl.dispose();
      lastCtrl.dispose();
      licenseCtrl.dispose();
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> d) async {
    final id = (d['id'] as num?)?.toInt();
    if (id == null) return;
    final name =
        '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove doctor?'),
        content: Text(
          'Remove $name from the clinic? This only works if they have no appointments or records.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    try {
      await BackendApiClient.instance.deleteDoctor(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doctor removed.')));
        _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.screenPadding(context);
    final clinicId = _clinicId;

    if (clinicId == null) {
      return Center(
        child: Padding(
          padding: padding,
          child: const Text(
            'Your account has no assigned clinic. Ask a system administrator to link this reception user to a clinic.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFFF5F5F5),
      child: FutureBuilder<List<Map<String, dynamic>>>(
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
                    Text('Could not load doctors: ${snap.error}'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _reload, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }
          final items = snap.data ?? const <Map<String, dynamic>>[];

          return LayoutBuilder(
            builder: (context, constraints) {
              final tablet = Responsive.isTablet(constraints.maxWidth);
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: padding,
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Doctors',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Clinic ID $clinicId · ${items.length} doctors',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (tablet && items.isNotEmpty)
                      SliverPadding(
                        padding: padding.copyWith(top: 0),
                        sliver: SliverToBoxAdapter(
                          child: Card(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Email')),
                                  DataColumn(label: Text('Specialization')),
                                  DataColumn(label: Text('')),
                                ],
                                rows: [
                                  for (final d in items)
                                    DataRow(
                                      cells: [
                                        DataCell(Text(
                                          '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim(),
                                        )),
                                        DataCell(Text(d['email']?.toString() ?? '—')),
                                        DataCell(Text(d['specialization']?.toString() ?? '—')),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline),
                                            onPressed: () => _confirmDelete(d),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: padding.copyWith(top: 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              if (items.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text('No doctors yet. Tap + Add doctor.'),
                                );
                              }
                              final d = items[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                  child: ListTile(
                                    title: Text(
                                      '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim(),
                                    ),
                                    subtitle: Text(
                                      '${d['email'] ?? ''}\n${d['specialization'] ?? ''}',
                                    ),
                                    isThreeLine: true,
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _confirmDelete(d),
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: items.isEmpty ? 1 : items.length,
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 88)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Called from parent [Scaffold.floatingActionButton].
  void openAddDoctor() => _showAddDoctor();
}
