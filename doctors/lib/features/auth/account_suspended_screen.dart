import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shown when doctor/reception login is blocked because the clinic is unpaid.
class AccountSuspendedScreen extends StatelessWidget {
  const AccountSuspendedScreen({super.key, this.message});

  final String? message;

  static const String defaultMessage =
      'Please contact your clinic administrator regarding payment.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.pause_circle_filled_rounded,
                size: 88,
                color: Colors.amber.shade800,
              ),
              const SizedBox(height: 24),
              Text(
                'Account suspended',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message?.trim().isNotEmpty == true ? message!.trim() : defaultMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  height: 1.5,
                  color: const Color(0xFF616161),
                ),
              ),
              const SizedBox(height: 36),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Back to sign-in',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
