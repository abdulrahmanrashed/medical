import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/layout/adaptive_sheet.dart';
import '../../core/layout/responsive.dart';
import '../../core/network/backend_api_client.dart';
import 'clinic_owner_ui.dart';


/// Use the [BuildContext] from the screen that owns the FAB (e.g. [Scaffold]).
Future<void> showAddClinicReceptionistSheet(
  BuildContext anchorContext, {
  required int clinicId,
  required Future<void> Function() onSuccess,
}) async {
  final ok = await showAdaptiveSheet<bool>(
    context: anchorContext,
    maxWidth: 520,
    builder: (ctx) => _AddReceptionistFormSheet(clinicId: clinicId),
  );

  if (ok == true && anchorContext.mounted) {
    ScaffoldMessenger.of(anchorContext).showSnackBar(
      const SnackBar(content: Text('Receptionist registered.')),
    );
    await onSuccess();
  }
}

class _AddReceptionistFormSheet extends StatefulWidget {
  const _AddReceptionistFormSheet({required this.clinicId});

  final int clinicId;

  @override
  State<_AddReceptionistFormSheet> createState() => _AddReceptionistFormSheetState();
}

class _AddReceptionistFormSheetState extends State<_AddReceptionistFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController();
    _passCtrl = TextEditingController();
    _firstCtrl = TextEditingController();
    _lastCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await BackendApiClient.instance.registerReception(
        clinicId: widget.clinicId,
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        firstName: _firstCtrl.text.trim(),
        lastName: _lastCtrl.text.trim(),
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
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: pad.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add receptionist', style: Theme.of(context).textTheme.titleLarge),
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
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Temporary password *',
                  border: OutlineInputBorder(),
                ),
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
                    : const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClinicReceptionistsPanel extends StatefulWidget {
  const ClinicReceptionistsPanel({
    super.key,
    required this.clinicId,
    this.embedded = false,
    this.onReloadReady,
  });

  final int clinicId;
  final bool embedded;

  /// Parent shell calls this to refresh after FAB add (e.g. when [embedded] is true).
  final void Function(Future<void> Function() reload)? onReloadReady;

  @override
  State<ClinicReceptionistsPanel> createState() => _ClinicReceptionistsPanelState();
}

class _ClinicReceptionistsPanelState extends State<ClinicReceptionistsPanel> {
  late Future<List<Map<String, dynamic>>> _future;

  int? _selectedReceptionistIndex;

  @override
  void initState() {
    super.initState();
    _future = BackendApiClient.instance.getClinicReceptionists(widget.clinicId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onReloadReady?.call(() async {
        await _reload();
      });
    });
  }

  Future<void> _reload() async {
    setState(() {
      _future = BackendApiClient.instance.getClinicReceptionists(widget.clinicId);
      _selectedReceptionistIndex = null;
    });
    await _future;
  }

  void _showAddSheet(BuildContext anchorContext) {
    showAddClinicReceptionistSheet(
      anchorContext,
      clinicId: widget.clinicId,
      onSuccess: _reload,
    );
  }

  Widget _buildBody(EdgeInsets padding) {
    return FutureBuilder<List<Map<String, dynamic>>>(
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
                  Text('Could not load: ${snap.error}'),
                  FilledButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }
        final list = snap.data ?? const <Map<String, dynamic>>[];
        if (list.isEmpty) {
          return RefreshIndicator(
            onRefresh: _reload,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.45,
                child: Center(
                  child: Padding(
                    padding: padding,
                    child: Text(
                      'No receptionists yet. Use Add receptionist to register staff.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: ClinicOwnerUi.onSurfaceMuted),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final master = Responsive.useMasterLayout(constraints.maxWidth);
            final bottomInset = widget.embedded ? 24.0 : 100.0;
            if (master) {
              final idx = (_selectedReceptionistIndex ?? 0).clamp(0, list.length - 1);
              final r = list[idx];
              return RefreshIndicator(
                onRefresh: _reload,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 300,
                            child: ColoredBox(
                              color: ClinicOwnerUi.surface,
                              child: ListView.separated(
                                padding: EdgeInsets.fromLTRB(
                                  padding.left,
                                  padding.top,
                                  8,
                                  padding.bottom + bottomInset,
                                ),
                                itemCount: list.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final item = list[i];
                                  final name =
                                      '${item['firstName'] ?? ''} ${item['lastName'] ?? ''}'.trim();
                                  final sel = i == idx;
                                  return ListTile(
                                    selected: sel,
                                    title: Text(
                                      name.isEmpty ? '—' : name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      item['email']?.toString() ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => setState(() => _selectedReceptionistIndex = i),
                                  );
                                },
                              ),
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: padding.copyWith(top: 0, bottom: bottomInset),
                              child: _receptionistCard(r),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            final cols = Responsive.gridColumnCount(constraints.maxWidth);
            return RefreshIndicator(
              onRefresh: _reload,
              child: cols == 1
                  ? ListView.builder(
                      padding: padding.copyWith(bottom: bottomInset),
                      itemCount: list.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _receptionistCard(list[i]),
                      ),
                    )
                  : GridView.builder(
                      padding: padding.copyWith(bottom: bottomInset),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 88,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, i) => _receptionistCard(list[i]),
                    ),
            );
          },
        );
      },
    );
  }

  Widget _receptionistCard(Map<String, dynamic> r) {
    return Container(
      decoration: ClinicOwnerUi.premiumCardDecoration(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          '${r['firstName'] ?? ''} ${r['lastName'] ?? ''}'.trim(),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: ClinicOwnerUi.onSurfaceTitle),
        ),
        subtitle: Text(
          r['email']?.toString() ?? '',
          style: GoogleFonts.inter(color: ClinicOwnerUi.onSurfaceMuted, fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.screenPadding(context);
    final body = _buildBody(padding);

    if (widget.embedded) {
      return Container(color: ClinicOwnerUi.surface, child: body);
    }

    return Scaffold(
      backgroundColor: ClinicOwnerUi.surface,
      appBar: AppBar(
        title: const Text('Manage receptionists'),
        backgroundColor: ClinicOwnerUi.surface,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        backgroundColor: ClinicOwnerUi.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add receptionist'),
      ),
      body: body,
    );
  }
}
