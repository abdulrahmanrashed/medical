/// Thrown when login returns 403 for suspended clinic staff (doctor/reception).
class AccountSuspendedException implements Exception {
  AccountSuspendedException([this.message =
      'Account Suspended. Please contact your clinic administrator regarding payment.']);

  final String message;

  @override
  String toString() => message;
}
