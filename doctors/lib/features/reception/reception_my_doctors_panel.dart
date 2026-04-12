import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/enums/doctor_specialization.dart';
import '../../core/layout/adaptive_sheet.dart';
import '../../core/layout/responsive.dart';
import '../../core/network/backend_api_client.dart';
import '../../core/network/session_manager.dart';
import '../clinic_owner/clinic_owner_ui.dart';

String _doctorFullName(Map<String, dynamic> d) {
  final n = '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim();
  return n.isEmpty ? 'Doctor #${d['id'] ?? ''}' : n;
}

String _yearsOfExpLabel(Map<String, dynamic> d) {
  final v = d['yearsOfExperience'];
  final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
  if (n <= 0) return '—';
  return n == 1 ? '1 Year of Exp' : '$n Years of Exp';
}

IconData _genderIcon(String? gender) {
  if (gender == null || gender.trim().isEmpty) return Icons.person_outline;
  final s = gender.trim().toLowerCase();
  if (s == 'female') return Icons.female;
  if (s == 'male') return Icons.male;
  return Icons.transgender_outlined;
}

Future<void> _launchTel(String? raw) async {
  if (raw == null || raw.trim().isEmpty) return;
  final trimmed = raw.trim();
  final uri = Uri.parse('tel:${trimmed.replaceAll(RegExp(r'\s'), '')}');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({
    required this.d,
    required this.frozen,
    required this.onToggleActive,
    this.premiumStyle = false,
  });

  final Map<String, dynamic> d;
  final bool frozen;
  final ValueChanged<bool> onToggleActive;
  final bool premiumStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = d['specialization']?.toString().trim();
    final phone = d['phoneNumber']?.toString().trim();
    final email = d['email']?.toString().trim();
    final gender = d['gender']?.toString().trim();

    final titleColor = frozen ? Colors.grey.shade700 : theme.colorScheme.onSurface;
    final bodyColor = frozen ? Colors.grey.shade600 : theme.colorScheme.onSurfaceVariant;
    final iconColor = frozen ? Colors.grey.shade600 : ClinicOwnerUi.primary.withValues(alpha: 0.85);

    final inner = Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _doctorFullName(d),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(frozen ? 'Frozen' : 'Active'),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  backgroundColor: frozen ? Colors.grey.shade600 : ClinicOwnerUi.primary.withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    color: frozen ? Colors.white : ClinicOwnerUi.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Switch.adaptive(
                  value: !frozen,
                  onChanged: onToggleActive,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CardDetailLine(
              icon: Icons.medical_information_outlined,
              iconColor: iconColor,
              child: Text.rich(
                TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(color: bodyColor, height: 1.35),
                  children: [
                    TextSpan(
                      text: (spec == null || spec.isEmpty) ? '—' : spec,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: ' · ',
                      style: TextStyle(color: bodyColor.withValues(alpha: 0.7)),
                    ),
                    TextSpan(text: _yearsOfExpLabel(d)),
                  ],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            _CardDetailLine(
              icon: Icons.phone_outlined,
              iconColor: iconColor,
              child: (phone == null || phone.isEmpty)
                  ? Text('—', style: theme.textTheme.bodyMedium?.copyWith(color: bodyColor))
                  : InkWell(
                      onTap: () => _launchTel(phone),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                phone,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: frozen ? Colors.grey.shade700 : ClinicOwnerUi.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: frozen ? Colors.grey.shade600 : ClinicOwnerUi.primary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.call, size: 18, color: iconColor),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            _CardDetailLine(
              icon: _genderIcon(gender),
              iconColor: iconColor,
              child: Text(
                (gender == null || gender.isEmpty) ? '—' : gender,
                style: theme.textTheme.bodyMedium?.copyWith(color: bodyColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            _CardDetailLine(
              icon: Icons.alternate_email,
              iconColor: iconColor,
              child: Text(
                (email == null || email.isEmpty) ? '—' : email,
                style: theme.textTheme.bodyMedium?.copyWith(color: bodyColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
    );

    if (premiumStyle) {
      return Container(
        decoration: ClinicOwnerUi.premiumCardDecoration(
          color: frozen ? const Color(0xFFE8E8E8) : Colors.white,
        ),
        child: inner,
      );
    }

    return Card(
      color: frozen ? const Color(0xFFE8E8E8) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withValues(alpha: frozen ? 0.06 : 0.08)),
      ),
      child: inner,
    );
  }
}

class _CardDetailLine extends StatelessWidget {
  const _CardDetailLine({
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Icon(icon, size: 20, color: iconColor),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Use the [BuildContext] from the screen that owns the FAB (e.g. [Scaffold]), not a [GlobalKey].
Future<void> showReceptionAddDoctorSheet(
  BuildContext anchorContext, {
  required Future<void> Function() onSuccess,
}) async {
  final clinicId = SessionManager.instance.assignedClinicId;
  if (clinicId == null) {
    if (anchorContext.mounted) {
      ScaffoldMessenger.of(anchorContext).showSnackBar(
        const SnackBar(content: Text('No clinic assigned to this account.')),
      );
    }
    return;
  }

  final ok = await showAdaptiveSheet<bool>(
    context: anchorContext,
    maxWidth: 560,
    builder: (ctx) => _AddDoctorFormSheet(clinicId: clinicId),
  );

  if (ok == true && anchorContext.mounted) {
    ScaffoldMessenger.of(anchorContext).showSnackBar(
      const SnackBar(content: Text('Doctor registered.')),
    );
    await onSuccess();
  }
}

class _AddDoctorFormSheet extends StatefulWidget {
  const _AddDoctorFormSheet({required this.clinicId});

  final int clinicId;

  @override
  State<_AddDoctorFormSheet> createState() => _AddDoctorFormSheetState();
}

class _AddDoctorFormSheetState extends State<_AddDoctorFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _licenseCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _yearsCtrl;
  DoctorSpecialization _spec = DoctorSpecialization.general;
  String? _gender;
  bool _submitting = false;

  static const _genders = ['Male', 'Female'];

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController();
    _passCtrl = TextEditingController();
    _firstCtrl = TextEditingController();
    _lastCtrl = TextEditingController();
    _licenseCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _yearsCtrl = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _licenseCtrl.dispose();
    _phoneCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final years = int.tryParse(_yearsCtrl.text.trim()) ?? 0;
      await BackendApiClient.instance.registerDoctor(
        clinicId: widget.clinicId,
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        firstName: _firstCtrl.text.trim(),
        lastName: _lastCtrl.text.trim(),
        specialization: _spec.label,
        licenseNumber: _licenseCtrl.text.trim().isEmpty ? null : _licenseCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        yearsOfExperience: years < 0 ? 0 : years,
        gender: _gender,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewInsetsOf(context);
    final clinicId = widget.clinicId;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: pad.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add doctor', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Creates a login for your clinic (clinic #$clinicId).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passCtrl,
                decoration: const InputDecoration(
                  labelText: 'Temporary password *',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (v) => (v == null || v.length < 8) ? 'Min 8 characters' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _firstCtrl,
                decoration: const InputDecoration(
                  labelText: 'First name *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastCtrl,
                decoration: const InputDecoration(
                  labelText: 'Last name *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _yearsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Years of experience',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 0 || n > 80) return 'Enter 0–80';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                // ignore: deprecated_member_use
                value: _gender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('—')),
                  for (final g in _genders)
                    DropdownMenuItem<String?>(value: g, child: Text(g)),
                ],
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<DoctorSpecialization>(
                // ignore: deprecated_member_use
                value: _spec,
                decoration: const InputDecoration(
                  labelText: 'Specialization',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final s in DoctorSpecialization.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _spec = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _licenseCtrl,
                decoration: const InputDecoration(
                  labelText: 'License (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: ClinicOwnerUi.primary),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Register doctor'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Clinic reception: doctors for [SessionManager.instance.assignedClinicId] only.
class ReceptionMyDoctorsPanel extends StatefulWidget {
  const ReceptionMyDoctorsPanel({
    super.key,
    this.onReloadReady,
    this.useClinicOwnerLayout = false,
  });

  final void Function(Future<void> Function() reload)? onReloadReady;

  /// When true (clinic owner shell): responsive grid on tablet + premium cards.
  final bool useClinicOwnerLayout;

  @override
  State<ReceptionMyDoctorsPanel> createState() => _ReceptionMyDoctorsPanelState();
}

class _ReceptionMyDoctorsPanelState extends State<ReceptionMyDoctorsPanel> {
  late Future<List<Map<String, dynamic>>> _future;

  /// Master–detail selection on wide layouts; defaults to first doctor in the list.
  int? _selectedDoctorIndex;

  int? get _clinicId => SessionManager.instance.assignedClinicId;

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

  Future<List<Map<String, dynamic>>> _load() async {
    final id = _clinicId;
    if (id == null) return const [];
    return BackendApiClient.instance.getDoctorsByClinic(id);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
      _selectedDoctorIndex = null;
    });
    await _future;
  }

  Future<void> _setDoctorActive(Map<String, dynamic> d, bool isActive) async {
    final id = (d['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      await BackendApiClient.instance.setDoctorActive(id, isActive: isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isActive ? 'Doctor is now active.' : 'Doctor frozen. They cannot sign in or receive bookings.'),
          ),
        );
        _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
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
      color: widget.useClinicOwnerLayout ? ClinicOwnerUi.surface : const Color(0xFFF5F5F5),
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
              final master = Responsive.useMasterLayout(constraints.maxWidth) && items.isNotEmpty;

              final header = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.useClinicOwnerLayout) ...[
                    Text(
                      'My Doctors',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    'Clinic ID $clinicId · ${items.length} doctors',
                    style: widget.useClinicOwnerLayout
                        ? Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: ClinicOwnerUi.onSurfaceTitle,
                            )
                        : Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                  ),
                ],
              );

              if (master) {
                final selectedIdx = (_selectedDoctorIndex ?? 0).clamp(0, items.length - 1);
                final d = items[selectedIdx];
                final frozen = d['isActive'] == false;
                final listBg = widget.useClinicOwnerLayout
                    ? ClinicOwnerUi.surface
                    : Theme.of(context).colorScheme.surface;

                return RefreshIndicator(
                  onRefresh: () async => _reload(),
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
                                color: listBg,
                                child: ListView.separated(
                                  padding: const EdgeInsets.only(right: 4),
                                  itemCount: items.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final doc = items[i];
                                    final f = doc['isActive'] == false;
                                    final sel = i == selectedIdx;
                                    final spec = doc['specialization']?.toString().trim();
                                    return ListTile(
                                      selected: sel,
                                      title: Text(
                                        _doctorFullName(doc),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        (spec == null || spec.isEmpty) ? '—' : spec,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Icon(
                                        f ? Icons.ac_unit : Icons.check_circle_outline,
                                        size: 20,
                                        color: f ? Colors.grey.shade600 : ClinicOwnerUi.primary,
                                      ),
                                      onTap: () => setState(() => _selectedDoctorIndex = i),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: padding.copyWith(top: 0),
                                child: _DoctorCard(
                                  d: d,
                                  frozen: frozen,
                                  premiumStyle: widget.useClinicOwnerLayout,
                                  onToggleActive: (v) => _setDoctorActive(d, v),
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
                onRefresh: () async => _reload(),
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
                                child: Text('No doctors yet. Tap + Add doctor.'),
                              );
                            }
                            final doc = items[i];
                            final fr = doc['isActive'] == false;
                            final narrow = MediaQuery.sizeOf(context).width < Responsive.breakpointMasterLayout;
                            return Padding(
                              padding: EdgeInsets.only(bottom: narrow ? 16 : 12),
                              child: _DoctorCard(
                                d: doc,
                                frozen: fr,
                                premiumStyle: widget.useClinicOwnerLayout,
                                onToggleActive: (v) => _setDoctorActive(doc, v),
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
