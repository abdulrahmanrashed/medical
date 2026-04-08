import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/enums/user_role.dart';
import '../../core/layout/responsive.dart';
import '../../core/network/auth_exceptions.dart';
import '../../core/network/backend_api_client.dart';
import '../../core/network/session_manager.dart';
import '../admin/admin_shell_screen.dart';
import '../clinic_owner/clinic_owner_shell_screen.dart';
import '../doctor/doctor_dashboard_screen.dart';
import '../patient/patient_shell_screen.dart';
import '../reception/reception_dashboard_controller.dart';
import '../reception/reception_shell_screen.dart';
import 'patient_register_screen.dart';
import 'account_suspended_screen.dart';

/// Brand palette for auth flows (deep teal primary, light grey surfaces).
abstract final class AuthBrand {
  static const Color deepTeal = Color(0xFF004D40);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color border = Color(0xFFE0E0E0);
}

/// Full-page login for a pre-selected role. Responsive: mobile = column;
/// tablet = split (illustration | form).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _loading = false;
  bool _obscurePassword = true;

  String get _title => '${widget.role.label} Login';

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await BackendApiClient.instance.login(
        email: widget.role == UserRole.patient ? null : _emailController.text.trim(),
        phone: widget.role == UserRole.patient ? _emailController.text.trim() : null,
        password: _passwordController.text,
      );
      if (!mounted) return;

      if (!SessionManager.instance.hasRole(widget.role)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Signed in, but this account does not have the selected role.',
            ),
          ),
        );
        return;
      }

      if (widget.role == UserRole.doctor) {
        try {
          final me = await BackendApiClient.instance.getDoctorMe();
          if (!mounted) return;
          SessionManager.instance.applyDoctorMe(me);
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not load doctor profile. Using defaults; pull to refresh on the dashboard.',
              ),
            ),
          );
        }
      }

      final Widget destination = switch (widget.role) {
        UserRole.admin => const AdminShellScreen(),
        UserRole.clinicManagement => const ClinicOwnerShellScreen(),
        UserRole.doctor => const DoctorDashboardScreen(),
        UserRole.receptionist => ChangeNotifierProvider(
            create: (_) {
              final c = ReceptionDashboardController();
              c.refresh();
              return c;
            },
            child: const ReceptionShellScreen(),
          ),
        UserRole.patient => const PatientShellScreen(),
      };

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => destination),
      );
    } on AccountSuspendedException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AccountSuspendedScreen(message: e.message),
        ),
      );
    } on AccountFrozenException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in failed. Check your credentials and API.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onForgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contact your clinic administrator to reset your password.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.screenPadding(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AuthBrand.lightGrey,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AuthBrand.lightGrey,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AuthBrand.lightGrey,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = Responsive.isTablet(constraints.maxWidth);
              if (isTablet) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _BrandedIllustration(role: widget.role),
                    ),
                    Expanded(
                      flex: 5,
                      child: _LoginFormPanel(
                        title: _title,
                        role: widget.role,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        obscurePassword: _obscurePassword,
                        onToggleObscure: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        loading: _loading,
                        onSignIn: _signIn,
                        onForgotPassword: _onForgotPassword,
                        onPatientRegister: widget.role == UserRole.patient
                            ? () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const PatientRegisterScreen(),
                                  ),
                                );
                              }
                            : null,
                        padding: padding,
                        showBackAsIcon: true,
                      ),
                    ),
                  ],
                );
              }
              return SingleChildScrollView(
                padding: padding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - padding.vertical,
                  ),
                  child: _LoginFormPanel(
                    title: _title,
                    role: widget.role,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    obscurePassword: _obscurePassword,
                    onToggleObscure: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    loading: _loading,
                    onSignIn: _signIn,
                    onForgotPassword: _onForgotPassword,
                    onPatientRegister: widget.role == UserRole.patient
                        ? () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => const PatientRegisterScreen(),
                              ),
                            );
                          }
                        : null,
                    padding: EdgeInsets.zero,
                    showBackAsIcon: false,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BrandedIllustration extends StatelessWidget {
  const _BrandedIllustration({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final icon = switch (role) {
      UserRole.doctor => FontAwesomeIcons.userDoctor,
      UserRole.receptionist => FontAwesomeIcons.briefcase,
      UserRole.patient => FontAwesomeIcons.userInjured,
      UserRole.admin => FontAwesomeIcons.shieldHalved,
      UserRole.clinicManagement => FontAwesomeIcons.hospital,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AuthBrand.deepTeal,
            AuthBrand.deepTeal.withValues(alpha: 0.85),
            AuthBrand.deepTeal.withValues(alpha: 0.65),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _SoftGridPainter()),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: FaIcon(
                      icon,
                      size: 88,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Care, connected.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Secure access to your clinic workspace.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.45,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoginFormPanel extends StatelessWidget {
  const _LoginFormPanel({
    required this.title,
    required this.role,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.loading,
    required this.onSignIn,
    required this.onForgotPassword,
    this.onPatientRegister,
    required this.padding,
    required this.showBackAsIcon,
  });

  final String title;
  final UserRole role;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final bool loading;
  final VoidCallback onSignIn;
  final VoidCallback onForgotPassword;
  final VoidCallback? onPatientRegister;
  final EdgeInsets padding;
  final bool showBackAsIcon;

  @override
  Widget build(BuildContext context) {
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment:
          showBackAsIcon ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        if (!showBackAsIcon) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              label: Text(
                'Back',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AuthBrand.deepTeal,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ] else
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              color: AuthBrand.deepTeal,
            ),
          ),
        const SizedBox(height: 8),
        _LogoHeader(),
        const SizedBox(height: 28),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1A1A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your credentials to continue.',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: const Color(0xFF616161),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: emailController,
          keyboardType: role == UserRole.patient
              ? TextInputType.phone
              : TextInputType.emailAddress,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration(
            label: role == UserRole.patient ? 'Phone number' : 'Email',
            prefix: FaIcon(
              role == UserRole.patient
                  ? FontAwesomeIcons.phone
                  : FontAwesomeIcons.envelope,
              size: 18,
              color: const Color(0xFF757575),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSignIn(),
          decoration: _fieldDecoration(
            label: 'Password',
            prefix: const FaIcon(
              FontAwesomeIcons.lock,
              size: 18,
              color: Color(0xFF757575),
            ),
            suffix: IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: const Color(0xFF757575),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onForgotPassword,
            child: Text(
              'Forgot Password?',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AuthBrand.deepTeal,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: loading ? null : onSignIn,
            style: FilledButton.styleFrom(
              backgroundColor: AuthBrand.deepTeal,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AuthBrand.deepTeal.withValues(alpha: 0.45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Sign In',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        if (onPatientRegister != null) ...[
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: loading ? null : onPatientRegister,
              child: Text(
                'New patient? Create account',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AuthBrand.deepTeal,
                ),
              ),
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: form,
        ),
      ),
    );
  }

  static InputDecoration _fieldDecoration({
    required String label,
    required Widget prefix,
    Widget? suffix,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AuthBrand.border),
    );
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: prefix,
      suffixIcon: suffix,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AuthBrand.deepTeal, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }
}

class _LogoHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AuthBrand.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.medical_services_rounded,
            size: 32,
            color: AuthBrand.deepTeal,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MedRecords',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Multi-clinic platform',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF757575),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
