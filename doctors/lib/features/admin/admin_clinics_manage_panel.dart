import 'package:flutter/material.dart';

import '../../core/layout/responsive.dart';
import '../../core/network/backend_api_client.dart';

const Color _kPrimary = Color(0xFF004D40);
const Color _kSurface = Color(0xFFF5F5F5);

bool _clinicIsPaid(Map<String, dynamic> c) {
  final v = c['paymentStatus'];
  if (v is String) {
    final s = v.toLowerCase();
    return s == 'paid' || s == '1';
  }
  if (v is int) return v == 1;
  return false;
}

/// System admin: list / create / delete clinics (GET/POST/DELETE /api/Clinics).
class AdminClinicsManagePanel extends StatefulWidget {
  const AdminClinicsManagePanel({super.key});

  @override
  State<AdminClinicsManagePanel> createState() => AdminClinicsManagePanelState();
}

class AdminClinicsManagePanelState extends State<AdminClinicsManagePanel> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = BackendApiClient.instance.getClinics();
  }

  Future<void> reload() async {
    setState(() {
      _future = BackendApiClient.instance.getClinics();
    });
    await _future;
  }

  Future<void> showAddClinicSheet() async {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final adminEmailCtrl = TextEditingController();
    final adminPassCtrl = TextEditingController();
    final adminFirstCtrl = TextEditingController();
    final adminLastCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final pad = MediaQuery.viewInsetsOf(ctx);
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: pad.bottom + 20),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('New clinic', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Clinic owner (Clinic Management login)',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(color: _kPrimary),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Clinic name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Clinic contact email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  Text('Clinic owner account', style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: adminEmailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Owner email *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: adminPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Owner password *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 8) ? 'Min 8 characters' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: adminFirstCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Owner first name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: adminLastCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Owner last name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _kPrimary),
                    onPressed: () {
                      if (formKey.currentState?.validate() ?? false) {
                        Navigator.pop(ctx, true);
                      }
                    },
                    child: const Text('Create'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      if (ok == true) {
        await BackendApiClient.instance.createClinic(
          name: nameCtrl.text.trim(),
          address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
          phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
          email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
          clinicAdminEmail: adminEmailCtrl.text.trim(),
          clinicAdminPassword: adminPassCtrl.text,
          clinicAdminFirstName: adminFirstCtrl.text.trim(),
          clinicAdminLastName: adminLastCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Clinic created. Owner can sign in under Clinic Management.')),
          );
          reload();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      nameCtrl.dispose();
      addressCtrl.dispose();
      phoneCtrl.dispose();
      emailCtrl.dispose();
      adminEmailCtrl.dispose();
      adminPassCtrl.dispose();
      adminFirstCtrl.dispose();
      adminLastCtrl.dispose();
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> c) async {
    final id = (c['id'] as num?)?.toInt();
    if (id == null) return;
    final name = c['name']?.toString() ?? 'Clinic';
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete clinic?'),
        content: Text('Remove "$name" from the system? This may fail if data exists.'),
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
      await BackendApiClient.instance.deleteClinic(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clinic removed.')));
        reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.screenPadding(context);
    return Container(
      color: _kSurface,
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
                    Text('Could not load clinics: ${snap.error}'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: reload,
                      child: const Text('Retry'),
                    ),
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
                onRefresh: () async => reload(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: padding,
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Clinics',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1A1A1A),
                              ),
                        ),
                      ),
                    ),
                    if (tablet && items.isNotEmpty)
                      SliverPadding(
                        padding: padding.copyWith(top: 0),
                        sliver: SliverToBoxAdapter(
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Phone')),
                                  DataColumn(label: Text('Email')),
                                  DataColumn(label: Text('Doctors')),
                                  DataColumn(label: Text('Active')),
                                  DataColumn(label: Text('')),
                                ],
                                rows: [
                                  for (final c in items)
                                    DataRow(
                                      cells: [
                                        DataCell(Text(c['name']?.toString() ?? '-')),
                                        DataCell(Text(c['phone']?.toString() ?? '—')),
                                        DataCell(Text(c['email']?.toString() ?? '—')),
                                        DataCell(Text('${c['doctorCount'] ?? 0}')),
                                        DataCell(
                                          _ClinicPaymentSwitch(
                                            clinicId: (c['id'] as num).toInt(),
                                            isPaid: _clinicIsPaid(c),
                                            onUpdated: reload,
                                          ),
                                        ),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline),
                                            onPressed: () => _confirmDelete(c),
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
                                  child: Text('No clinics yet. Tap + to add one.'),
                                );
                              }
                              final c = items[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ClinicAdminCard(
                                  data: c,
                                  onDelete: () => _confirmDelete(c),
                                  onPaymentUpdated: reload,
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
}

class _ClinicAdminCard extends StatelessWidget {
  const _ClinicAdminCard({
    required this.data,
    required this.onDelete,
    required this.onPaymentUpdated,
  });

  final Map<String, dynamic> data;
  final VoidCallback onDelete;
  final Future<void> Function() onPaymentUpdated;

  @override
  Widget build(BuildContext context) {
    final name = data['name']?.toString() ?? 'Clinic';
    final address = data['address']?.toString();
    final phone = data['phone']?.toString();
    final email = data['email']?.toString();
    final count = data['doctorCount'] ?? 0;
    final id = (data['id'] as num?)?.toInt();
    final paid = _clinicIsPaid(data);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: _kPrimary.withValues(alpha: 0.12),
                  foregroundColor: _kPrimary,
                  child: const Icon(Icons.local_hospital),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (address != null && address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(address, style: Theme.of(context).textTheme.bodySmall),
                      ],
                      const SizedBox(height: 8),
                      if (phone != null && phone.isNotEmpty)
                        Text('Phone: $phone', style: Theme.of(context).textTheme.bodySmall),
                      if (email != null && email.isNotEmpty)
                        Text('Email: $email', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Text(
                        '$count doctors',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: _kPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              paid ? 'Account active (paid)' : 'Frozen — staff blocked until paid',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: paid ? const Color(0xFF2E7D32) : const Color(0xFFB00020),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (id != null)
                            _ClinicPaymentSwitch(
                              clinicId: id,
                              isPaid: paid,
                              onUpdated: onPaymentUpdated,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClinicPaymentSwitch extends StatefulWidget {
  const _ClinicPaymentSwitch({
    required this.clinicId,
    required this.isPaid,
    required this.onUpdated,
  });

  final int clinicId;
  final bool isPaid;
  final Future<void> Function() onUpdated;

  @override
  State<_ClinicPaymentSwitch> createState() => _ClinicPaymentSwitchState();
}

class _ClinicPaymentSwitchState extends State<_ClinicPaymentSwitch> {
  late bool _paid;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _paid = widget.isPaid;
  }

  @override
  void didUpdateWidget(covariant _ClinicPaymentSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPaid != widget.isPaid) {
      _paid = widget.isPaid;
    }
  }

  Future<void> _onChanged(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await BackendApiClient.instance.setClinicPaymentStatus(
        widget.clinicId,
        value ? 'Paid' : 'Unpaid',
      );
      if (mounted) {
        setState(() => _paid = value);
        await widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _paid
          ? 'Deactivate — block doctor & reception logins'
          : 'Activate — allow doctor & reception logins',
      child: Switch.adaptive(
        value: _paid,
        onChanged: _busy ? null : _onChanged,
      ),
    );
  }
}
