import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/layout/adaptive_sheet.dart';
import '../../core/layout/responsive.dart';
import '../../core/network/backend_api_client.dart';

const Color _kPrimary = Color(0xFF004D40);
const Color _kSurface = Color(0xFFF5F5F5);
const Color _kAlertRed = Color(0xFFB00020);

bool _clinicSwitchIsPaid(Map<String, dynamic> c) {
  final v = c['paymentStatus'];
  if (v is int) return v == 1;
  if (v is String) return v.toLowerCase() == 'paid';
  return false;
}

bool _paymentStatusIsFrozen(Map<String, dynamic> c) {
  final v = c['paymentStatus'];
  if (v is int) return v == 2;
  if (v is String) return v.toLowerCase() == 'frozen';
  return false;
}

bool _subscriptionUiIsFrozen(Map<String, dynamic> c) {
  final v = c['subscriptionStatus'];
  if (v is int) return v == 2;
  if (v is String) return v.toLowerCase() == 'frozen';
  return false;
}

DateTime? _parseJsonDate(dynamic v) {
  if (v == null) return null;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

/// Red highlight: API frozen, subscription UI frozen, or subscription end date in the past.
bool _isClinicBillingAlert(Map<String, dynamic> c) {
  if (_paymentStatusIsFrozen(c) || _subscriptionUiIsFrozen(c)) return true;
  final end = _parseJsonDate(c['subscriptionEndDate']);
  if (end == null) return false;
  return !end.toUtc().isAfter(DateTime.now().toUtc());
}

String _formatMoney(dynamic v) {
  final n = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
  return NumberFormat.currency(symbol: r'$').format(n);
}

/// Mapped from API `ownerFullName` (Identity first + last name).
String? _clinicOwnerFullName(Map<String, dynamic> c) {
  final v = c['ownerFullName']?.toString().trim();
  if (v != null && v.isNotEmpty) return v;
  return null;
}

/// Mapped from API `ownerEmail` (ClinicAdmin login).
String? _clinicOwnerEmail(Map<String, dynamic> c) {
  final v = c['ownerEmail']?.toString().trim();
  if (v != null && v.isNotEmpty) return v;
  return null;
}

Future<void> showAddClinicSheet(
  BuildContext anchorContext, {
  required Future<void> Function() onSuccess,
}) async {
  final ok = await showAdaptiveSheet<bool>(
    context: anchorContext,
    maxWidth: 560,
    builder: (ctx) => const _AddClinicFormSheet(),
  );

  if (ok == true && anchorContext.mounted) {
    ScaffoldMessenger.of(anchorContext).showSnackBar(
      const SnackBar(content: Text('Clinic created. Owner can sign in under Clinic Management.')),
    );
    await onSuccess();
  }
}

Future<void> showEditPaymentSheet(
  BuildContext anchorContext, {
  required Map<String, dynamic> clinic,
  required Future<void> Function() onSuccess,
}) async {
  final ok = await showAdaptiveSheet<bool>(
    context: anchorContext,
    maxWidth: 480,
    builder: (ctx) => _EditPaymentSheet(clinic: clinic),
  );
  if (ok == true && anchorContext.mounted) {
    ScaffoldMessenger.of(anchorContext).showSnackBar(
      const SnackBar(content: Text('Payment recorded.')),
    );
    await onSuccess();
  }
}

class _AddClinicFormSheet extends StatefulWidget {
  const _AddClinicFormSheet();

  @override
  State<_AddClinicFormSheet> createState() => _AddClinicFormSheetState();
}

class _AddClinicFormSheetState extends State<_AddClinicFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _adminEmailCtrl;
  late final TextEditingController _adminPassCtrl;
  late final TextEditingController _adminFirstCtrl;
  late final TextEditingController _adminLastCtrl;
  late final TextEditingController _totalCtrl;
  late final TextEditingController _paidCtrl;
  DateTime? _subscriptionEndDate;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _adminEmailCtrl = TextEditingController();
    _adminPassCtrl = TextEditingController();
    _adminFirstCtrl = TextEditingController();
    _adminLastCtrl = TextEditingController();
    _totalCtrl = TextEditingController(text: '0');
    _paidCtrl = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _adminEmailCtrl.dispose();
    _adminPassCtrl.dispose();
    _adminFirstCtrl.dispose();
    _adminLastCtrl.dispose();
    _totalCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final initial = _subscriptionEndDate ?? now.add(const Duration(days: 365));
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (d == null || !mounted) return;
    setState(() {
      _subscriptionEndDate = DateTime(d.year, d.month, d.day, 23, 59, 59).toUtc();
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final total = double.tryParse(_totalCtrl.text.trim()) ?? 0;
    final paid = double.tryParse(_paidCtrl.text.trim()) ?? 0;
    if (paid > total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paid amount cannot exceed total.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await BackendApiClient.instance.createClinic(
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        clinicAdminEmail: _adminEmailCtrl.text.trim(),
        clinicAdminPassword: _adminPassCtrl.text,
        clinicAdminFirstName: _adminFirstCtrl.text.trim(),
        clinicAdminLastName: _adminLastCtrl.text.trim(),
        totalAmount: total,
        paidAmount: paid,
        subscriptionEndDate: _subscriptionEndDate,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewInsetsOf(context);
    final dateFmt = DateFormat.yMMMd();
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: pad.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New clinic', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Clinic owner (Clinic Management login)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: _kPrimary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Clinic name *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Clinic contact email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              Text('Billing', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _totalCtrl,
                decoration: const InputDecoration(
                  labelText: 'Total amount',
                  border: OutlineInputBorder(),
                  prefixText: r'$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _paidCtrl,
                decoration: const InputDecoration(
                  labelText: 'Paid amount',
                  border: OutlineInputBorder(),
                  prefixText: r'$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Subscription end date'),
                subtitle: Text(
                  _subscriptionEndDate == null
                      ? 'Optional — tap to choose'
                      : dateFmt.format(_subscriptionEndDate!.toLocal()),
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickEndDate,
              ),
              const SizedBox(height: 12),
              Text('Clinic owner account', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              TextFormField(
                controller: _adminEmailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Owner email *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _adminPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Owner password *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.length < 8) ? 'Min 8 characters' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _adminFirstCtrl,
                decoration: const InputDecoration(
                  labelText: 'Owner first name *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _adminLastCtrl,
                decoration: const InputDecoration(
                  labelText: 'Owner last name *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _kPrimary),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditPaymentSheet extends StatefulWidget {
  const _EditPaymentSheet({required this.clinic});

  final Map<String, dynamic> clinic;

  @override
  State<_EditPaymentSheet> createState() => _EditPaymentSheetState();
}

class _EditPaymentSheetState extends State<_EditPaymentSheet> {
  late final TextEditingController _amountCtrl;
  DateTime? _nextExpiry;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController();
    final end = _parseJsonDate(widget.clinic['subscriptionEndDate']);
    _nextExpiry = end ?? DateTime.now().add(const Duration(days: 365));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final initial = _nextExpiry ?? now.add(const Duration(days: 365));
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (d == null || !mounted) return;
    setState(() {
      _nextExpiry = DateTime(d.year, d.month, d.day, 23, 59, 59).toUtc();
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a payment amount greater than zero.')),
      );
      return;
    }
    final expiry = _nextExpiry;
    if (expiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a subscription end date.')),
      );
      return;
    }
    final id = (widget.clinic['id'] as num?)?.toInt();
    if (id == null) return;

    setState(() => _submitting = true);
    try {
      await BackendApiClient.instance.recordClinicPayment(
        clinicId: id,
        amountPaid: amount,
        nextExpiryDate: expiry,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewInsetsOf(context);
    final dateFmt = DateFormat.yMMMd();
    final name = widget.clinic['name']?.toString() ?? 'Clinic';

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: pad.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit payment · $name', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Adds to paid balance and records an invoice. Set the new subscription end date.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            decoration: const InputDecoration(
              labelText: 'Payment amount *',
              border: OutlineInputBorder(),
              prefixText: r'$ ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('New subscription end date *'),
            subtitle: Text(
              _nextExpiry == null ? 'Choose date' : dateFmt.format(_nextExpiry!.toLocal()),
            ),
            trailing: const Icon(Icons.event_outlined),
            onTap: _pickExpiry,
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kPrimary),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save payment'),
          ),
        ],
      ),
    );
  }
}

class AdminClinicsManagePanel extends StatefulWidget {
  const AdminClinicsManagePanel({super.key, this.onReloadReady});

  final void Function(Future<void> Function() reload)? onReloadReady;

  @override
  State<AdminClinicsManagePanel> createState() => AdminClinicsManagePanelState();
}

class AdminClinicsManagePanelState extends State<AdminClinicsManagePanel> {
  late Future<List<Map<String, dynamic>>> _future;
  final _searchController = TextEditingController();

  int? _selectedClinicIndex;

  @override
  void initState() {
    super.initState();
    _future = _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onReloadReady?.call(() async {
        await reload();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() {
    final q = _searchController.text.trim();
    return BackendApiClient.instance.getClinics(search: q.isEmpty ? null : q);
  }

  Future<void> reload() async {
    setState(() {
      _future = _load();
      _selectedClinicIndex = null;
    });
    await _future;
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
              final master = Responsive.useMasterLayout(constraints.maxWidth) && items.isNotEmpty;
              final header = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      FocusScope.of(context).unfocus();
                      reload();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search clinics by name',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Clinics',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1A1A),
                        ),
                  ),
                ],
              );

              if (master) {
                final idx = (_selectedClinicIndex ?? 0).clamp(0, items.length - 1);
                final c = items[idx];
                return RefreshIndicator(
                  onRefresh: () async => reload(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: padding,
                        sliver: SliverToBoxAdapter(child: header),
                      ),
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 300,
                              child: ColoredBox(
                                color: _kSurface,
                                child: ListView.separated(
                                  padding: const EdgeInsets.only(right: 8),
                                  itemCount: items.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final clinic = items[i];
                                    final alert = _isClinicBillingAlert(clinic);
                                    final sel = i == idx;
                                    return ListTile(
                                      selected: sel,
                                      title: Text(
                                        clinic['name']?.toString() ?? '—',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        _clinicOwnerEmail(clinic) ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: alert
                                          ? Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20)
                                          : const Icon(Icons.chevron_right, size: 20),
                                      onTap: () => setState(() => _selectedClinicIndex = i),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: padding.copyWith(top: 0),
                                child: _ClinicAdminCard(
                                  data: c,
                                  onDelete: () => _confirmDelete(c),
                                  onPaymentUpdated: reload,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 88)),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => reload(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: padding,
                      sliver: SliverToBoxAdapter(child: header),
                    ),
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
                            final clinic = items[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ClinicAdminCard(
                                data: clinic,
                                onDelete: () => _confirmDelete(clinic),
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
    final paid = _clinicSwitchIsPaid(data);
    final alert = _isClinicBillingAlert(data);
    final remaining = _formatMoney(data['remainingAmount']);
    final end = _parseJsonDate(data['subscriptionEndDate']);
    final dateFmt = DateFormat.yMMMd();
    final expiryLabel = end == null ? 'No expiry set' : 'Expires ${dateFmt.format(end.toLocal())}';

    final borderColor = alert ? _kAlertRed : Colors.black.withValues(alpha: 0.06);
    final bgTint = alert ? Colors.red.shade50 : Colors.white;

    return Card(
      color: bgTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: alert ? 1.5 : 1),
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
                  backgroundColor: (alert ? _kAlertRed : _kPrimary).withValues(alpha: 0.12),
                  foregroundColor: alert ? _kAlertRed : _kPrimary,
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
                        Text('Clinic email: $email', style: Theme.of(context).textTheme.bodySmall),
                      if (_clinicOwnerFullName(data) != null || _clinicOwnerEmail(data) != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Owner',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 2),
                        if (_clinicOwnerFullName(data) != null)
                          Text(
                            _clinicOwnerFullName(data)!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        if (_clinicOwnerEmail(data) != null)
                          Text(
                            _clinicOwnerEmail(data)!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '$count doctors',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: _kPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Remaining: $remaining',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: alert ? _kAlertRed : const Color(0xFF1A1A1A),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        expiryLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: alert ? _kAlertRed : Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: alert ? FontWeight.w600 : null,
                            ),
                      ),
                      if (alert) ...[
                        const SizedBox(height: 6),
                        Text(
                          _paymentStatusIsFrozen(data) || _subscriptionUiIsFrozen(data)
                              ? 'Subscription frozen or overdue'
                              : 'Subscription end date has passed',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: _kAlertRed,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              paid ? 'Account active (paid)' : 'Staff blocked until paid / renewed',
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
                Column(
                  children: [
                    IconButton(
                      tooltip: 'Edit payment',
                      icon: const Icon(Icons.edit_calendar_outlined),
                      onPressed: () => showEditPaymentSheet(
                        context,
                        clinic: data,
                        onSuccess: onPaymentUpdated,
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
