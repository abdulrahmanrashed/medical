import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/models/backend_models.dart';
import '../core/network/backend_api_client.dart';

/// Name + phone only; calls `POST /Patients/reception/find-or-create-draft` (Reception or Admin JWT).
class AddPatientDraftCard extends StatefulWidget {
  const AddPatientDraftCard({super.key, this.compact = false});

  final bool compact;

  @override
  State<AddPatientDraftCard> createState() => _AddPatientDraftCardState();
}

class _AddPatientDraftCardState extends State<AddPatientDraftCard> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final raw = await BackendApiClient.instance.receptionFindOrCreateDraft(
        phone: _phoneCtrl.text.trim(),
        fullName: _nameCtrl.text.trim(),
      );
      if (!mounted) return;
      final p = ApiPatient.fromJson(raw);
      final status = p.registrationStatus ?? p.registrationStatusEnum.name;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Patient saved ($status). ID: ${p.patientId}',
          ),
        ),
      );
      _nameCtrl.clear();
      _phoneCtrl.clear();
    } on DioException catch (e) {
      if (!mounted) return;
      final body = e.response?.data;
      final msg = body is Map
          ? body['message']?.toString() ?? body.toString()
          : body?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg ?? e.message ?? 'Request failed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.compact ? 0.0 : 20.0;
    return Padding(
      padding: EdgeInsets.all(pad),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.compact) ...[
              Text(
                'Add patient (draft)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Only full name and phone are required. The patient can complete registration in the app.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
            ],
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF004D40),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create draft profile'),
            ),
          ],
        ),
      ),
    );
  }
}
