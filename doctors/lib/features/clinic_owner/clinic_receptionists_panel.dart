import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/layout/responsive.dart';
import '../../core/network/backend_api_client.dart';

const Color _kPrimary = Color(0xFF004D40);

class ClinicReceptionistsPanel extends StatefulWidget {
  const ClinicReceptionistsPanel({super.key, required this.clinicId});

  final int clinicId;

  @override
  State<ClinicReceptionistsPanel> createState() => _ClinicReceptionistsPanelState();
}

class _ClinicReceptionistsPanelState extends State<ClinicReceptionistsPanel> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = BackendApiClient.instance.getClinicReceptionists(widget.clinicId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = BackendApiClient.instance.getClinicReceptionists(widget.clinicId);
    });
    await _future;
  }

  Future<void> _showAdd() async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
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
                  Text('Add receptionist', style: Theme.of(ctx).textTheme.titleLarge),
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
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Temporary password *',
                      border: OutlineInputBorder(),
                    ),
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
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _kPrimary),
                    onPressed: () {
                      if (formKey.currentState?.validate() ?? false) {
                        Navigator.pop(ctx, true);
                      }
                    },
                    child: const Text('Register'),
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
        await BackendApiClient.instance.registerReception(
          clinicId: widget.clinicId,
          email: emailCtrl.text.trim(),
          password: passCtrl.text,
          firstName: firstCtrl.text.trim(),
          lastName: lastCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receptionist registered.')),
          );
          _reload();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      emailCtrl.dispose();
      passCtrl.dispose();
      firstCtrl.dispose();
      lastCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.screenPadding(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Manage receptionists')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAdd,
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add receptionist'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              padding: padding,
              itemCount: list.length,
              itemBuilder: (context, i) {
                final r = list[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(
                      '${r['firstName'] ?? ''} ${r['lastName'] ?? ''}'.trim(),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(r['email']?.toString() ?? ''),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
