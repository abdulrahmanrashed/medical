import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/backend_models.dart';
import '../../core/network/backend_api_client.dart';
import '../../core/network/session_manager.dart';
import '../../core/storage/patient_local_storage.dart';
import '../patient/patient_shell_screen.dart';
import 'login_screen.dart';

/// Patient self-registration: phone lookup → complete profile (DRAFT from reception or new).
class PatientRegisterScreen extends StatefulWidget {
  const PatientRegisterScreen({super.key});

  @override
  State<PatientRegisterScreen> createState() => _PatientRegisterScreenState();
}

class _PatientRegisterScreenState extends State<PatientRegisterScreen> {
  final _formPhone = GlobalKey<FormState>();
  final _formDetails = GlobalKey<FormState>();

  final _phoneCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _insuranceDetailsCtrl = TextEditingController();
  final _chronicCtrl = TextEditingController();

  int _step = 0;
  bool _loading = false;
  bool _insurance = false;
  PatientRegistrationLookupResult? _lookup;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _insuranceDetailsCtrl.dispose();
    _chronicCtrl.dispose();
    super.dispose();
  }

  Future<void> _onPhoneContinue() async {
    if (!_formPhone.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final result = await BackendApiClient.instance.registrationLookupByPhone(
        _phoneCtrl.text.trim(),
      );
      if (!mounted) return;

      if (result.found && result.registrationStatus == ApiPatientRegistrationStatus.completed) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Already registered'),
            content: const Text(
              'This phone number already has a completed account. Please sign in instead.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      _lookup = result;
      if (result.found && result.registrationStatus == ApiPatientRegistrationStatus.draft) {
        _fullNameCtrl.text = result.fullName ?? '';
        _emailCtrl.text = result.email ?? '';
        _insurance = result.insuranceStatus;
        _insuranceDetailsCtrl.text = result.insuranceDetails ?? '';
        _chronicCtrl.text = result.chronicDiseases ?? '';
        if (result.patientId != null && result.patientId!.isNotEmpty) {
          await PatientLocalStorage.instance.savePatientId(result.patientId!);
        }
      } else {
        _fullNameCtrl.clear();
        _emailCtrl.clear();
        _insurance = false;
        _insuranceDetailsCtrl.clear();
        _chronicCtrl.clear();
      }

      setState(() => _step = 1);
    } on DioException catch (e) {
      if (!mounted) return;
      _showError(e.response?.data?.toString() ?? e.message ?? 'Lookup failed');
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRegister() async {
    if (!_formDetails.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await BackendApiClient.instance.registerPatient(
        phone: _phoneCtrl.text.trim(),
        password: _passwordCtrl.text,
        fullName: _fullNameCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        insuranceStatus: _insurance,
        insuranceDetails:
            _insuranceDetailsCtrl.text.trim().isEmpty ? null : _insuranceDetailsCtrl.text.trim(),
        chronicDiseases: _chronicCtrl.text.trim().isEmpty ? null : _chronicCtrl.text.trim(),
      );
      if (!mounted) return;
      final id = SessionManager.instance.patientId;
      if (id != null && id.isNotEmpty) {
        await PatientLocalStorage.instance.savePatientId(id);
      }
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const PatientShellScreen()),
        (route) => false,
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final body = e.response?.data;
      final msg = body is Map ? body['message']?.toString() ?? body.toString() : body?.toString();
      _showError(msg ?? e.message ?? 'Registration failed');
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthBrand.lightGrey,
      appBar: AppBar(
        backgroundColor: AuthBrand.lightGrey,
        foregroundColor: AuthBrand.deepTeal,
        title: Text(
          _step == 0 ? 'Create account' : 'Your details',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _step == 0 ? _buildPhoneStep() : _buildDetailsStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Form(
      key: _formPhone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter your mobile number. We will check if your clinic already started a profile for you.',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: const Color(0xFF616161),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            autocorrect: false,
            decoration: _decoration('Phone number'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Phone is required';
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _loading ? null : _onPhoneContinue,
              style: FilledButton.styleFrom(
                backgroundColor: AuthBrand.deepTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text('Continue', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    final draftHint = _lookup?.found == true &&
            _lookup!.registrationStatus == ApiPatientRegistrationStatus.draft
        ? 'We found a draft profile from your clinic. Complete the form to activate your account.'
        : 'Create your login and health information.';

    return Form(
      key: _formDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            draftHint,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF616161),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _fullNameCtrl,
            decoration: _decoration('Full name'),
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: _decoration('Email (optional)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: _decoration('Password (min 8 characters)'),
            validator: (v) {
              if (v == null || v.length < 8) return 'Password must be at least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _insurance,
            onChanged: (v) => setState(() => _insurance = v),
            title: Text('I have insurance', style: GoogleFonts.inter()),
            activeThumbColor: AuthBrand.deepTeal,
          ),
          TextFormField(
            controller: _insuranceDetailsCtrl,
            maxLines: 2,
            decoration: _decoration('Insurance details (optional)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _chronicCtrl,
            maxLines: 2,
            decoration: _decoration('Chronic conditions (optional)'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _loading ? null : _onRegister,
              style: FilledButton.styleFrom(
                backgroundColor: AuthBrand.deepTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text('Register', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          ),
          TextButton(
            onPressed: _loading ? null : () => setState(() => _step = 0),
            child: Text('Back to phone', style: GoogleFonts.inter(color: AuthBrand.deepTeal)),
          ),
        ],
      ),
    );
  }

  static InputDecoration _decoration(String label) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AuthBrand.border),
    );
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AuthBrand.deepTeal, width: 1.5),
      ),
    );
  }
}
