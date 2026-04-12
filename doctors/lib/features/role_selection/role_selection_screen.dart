import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/enums/user_role.dart';
import '../../core/layout/responsive.dart';
import '../auth/login_screen.dart';
import '../auth/patient_register_screen.dart';

/// All app roles shown on the entry screen (includes Admin).
final List<UserRole> _kEntryRoles = UserRole.values;

/// Deep teal primary and light grey surface — matches [LoginScreen] / [AuthBrand].
const Color _kDeepTeal = Color(0xFF004D40);
const Color _kLightGrey = Color(0xFFF5F5F5);

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late final int _staggerTotal;

  late final AnimationController _staggerController;
  late final List<Animation<double>> _fadeAnimations;
  late final List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _staggerTotal = 1 + _kEntryRoles.length;
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnimations = [];
    _slideAnimations = [];
    for (var i = 0; i < _staggerTotal; i++) {
      final start = i * 0.12;
      final end = (start + 0.52).clamp(0.0, 1.0);
      _fadeAnimations.add(
        Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _staggerController,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          ),
        ),
      );
      _slideAnimations.add(
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _staggerController,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          ),
        ),
      );
    }
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  void _openLogin(UserRole role) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(role: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.screenPadding(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _kLightGrey,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _kLightGrey,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _kLightGrey,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = Responsive.isTablet(constraints.maxWidth);
              final contentPadding = padding.copyWith(
                top: padding.top + 8,
                bottom: padding.bottom + 24,
              );

              return Padding(
                padding: contentPadding,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: _fadeAnimations.isNotEmpty
                            ? _fadeAnimations[0]
                            : const AlwaysStoppedAnimation(1),
                        child: SlideTransition(
                          position: _slideAnimations.isNotEmpty
                              ? _slideAnimations[0]
                              : const AlwaysStoppedAnimation(Offset.zero),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Who are you?',
                                style: GoogleFonts.inter(
                                  fontSize: isTablet ? 40 : 32,
                                  fontWeight: FontWeight.w800,
                                  height: 1.12,
                                  color: const Color(0xFF1A1A1A),
                                  letterSpacing: -0.8,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Choose how you use the clinic app.',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF616161),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 28),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (isTablet)
                      SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.4,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final role = _kEntryRoles[index];
                            return _animatedRoleCard(index + 1, role);
                          },
                          childCount: _kEntryRoles.length,
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final role = _kEntryRoles[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _animatedRoleCard(index + 1, role),
                            );
                          },
                          childCount: _kEntryRoles.length,
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 32),
                        child: Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => const PatientRegisterScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'New patient? Create account',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: _kDeepTeal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _animatedRoleCard(int animationIndex, UserRole role) {
    final i = animationIndex.clamp(0, _staggerTotal - 1);
    final fade = i < _fadeAnimations.length
        ? _fadeAnimations[i]
        : const AlwaysStoppedAnimation<double>(1);
    final slide = i < _slideAnimations.length
        ? _slideAnimations[i]
        : const AlwaysStoppedAnimation<Offset>(Offset.zero);

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: _ServiceRoleCard(
          role: role,
          onTap: () => _openLogin(role),
        ),
      ),
    );
  }
}

class _ServiceRoleCard extends StatefulWidget {
  const _ServiceRoleCard({
    required this.role,
    required this.onTap,
  });

  final UserRole role;
  final VoidCallback onTap;

  @override
  State<_ServiceRoleCard> createState() => _ServiceRoleCardState();
}

class _ServiceRoleCardState extends State<_ServiceRoleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scale = Tween<double>(begin: 1, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = _roleVisual(widget.role);

    return ScaleTransition(
      scale: _scale,
      child: Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (pressed) {
            if (pressed) {
              _pressController.forward();
            } else {
              _pressController.reverse();
            }
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: spec.accent.withValues(alpha: 0.12),
          highlightColor: spec.accent.withValues(alpha: 0.06),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: spec.accent.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: spec.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: FaIcon(
                        spec.icon,
                        size: 30,
                        color: spec.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.role.label,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.role.shortDescription,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF616161),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FaIcon(
                    FontAwesomeIcons.chevronRight,
                    size: 16,
                    color: spec.accent.withValues(alpha: 0.65),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _RoleVisual _roleVisual(UserRole role) {
    return switch (role) {
      UserRole.doctor => _RoleVisual(
          icon: FontAwesomeIcons.userDoctor,
          accent: _kDeepTeal,
        ),
      UserRole.receptionist => _RoleVisual(
          icon: FontAwesomeIcons.briefcase,
          accent: const Color(0xFF00695C),
        ),
      UserRole.patient => _RoleVisual(
          icon: FontAwesomeIcons.userInjured,
          accent: const Color(0xFF00796B),
        ),
      UserRole.admin => _RoleVisual(
          icon: FontAwesomeIcons.shieldHalved,
          accent: _kDeepTeal,
        ),
      UserRole.clinicManagement => _RoleVisual(
          icon: FontAwesomeIcons.hospital,
          accent: const Color(0xFF00695C),
        ),
    };
  }
}

class _RoleVisual {
  const _RoleVisual({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;
}
