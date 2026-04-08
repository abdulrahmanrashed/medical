import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/layout/responsive.dart';
import '../../core/network/backend_api_client.dart';

const Color _kPrimary = Color(0xFF004D40);

/// Lists all [ClinicInvoice] rows from GET /api/Clinics/invoices/all (admin).
class AdminBillingHistoryScreen extends StatefulWidget {
  const AdminBillingHistoryScreen({super.key});

  @override
  State<AdminBillingHistoryScreen> createState() => _AdminBillingHistoryScreenState();
}

class _AdminBillingHistoryScreenState extends State<AdminBillingHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = BackendApiClient.instance.getAllBillingInvoices();
  }

  Future<void> _reload() async {
    setState(() {
      _future = BackendApiClient.instance.getAllBillingInvoices();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.screenPadding(context);
    final dateFmt = DateFormat.yMMMd();

    return Container(
      color: const Color(0xFFF5F5F5),
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
                    Text('Could not load billing history: ${snap.error}'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _reload,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final items = snap.data ?? const <Map<String, dynamic>>[];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: padding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade500),
                    const SizedBox(height: 16),
                    Text(
                      'No invoices yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Payments from clinic registration or the Clinics tab will appear here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: padding.copyWith(bottom: 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final row = items[i];
                final name = row['clinicName']?.toString() ?? 'Clinic';
                final linePayment = (row['amountPaid'] as num?)?.toDouble() ?? 0;
                final total = (row['totalAmount'] as num?)?.toDouble();
                final paid = (row['clinicPaidAmount'] as num?)?.toDouble();
                final remaining = (row['remainingAmount'] as num?)?.toDouble();
                final payRaw = row['paymentDate'];
                DateTime? payDate;
                if (payRaw is String) payDate = DateTime.tryParse(payRaw);
                final money = NumberFormat.currency(symbol: r'$');

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: _kPrimary.withValues(alpha: 0.12),
                          foregroundColor: _kPrimary,
                          child: const Icon(Icons.payments_outlined, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              if (total != null && paid != null && remaining != null)
                                Text(
                                  'Total amount: ${money.format(total)} · Paid: ${money.format(paid)} · Remaining: ${money.format(remaining)}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                )
                              else
                                Text(
                                  'This payment: ${money.format(linePayment)}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'Payment on this record: ${money.format(linePayment)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                payDate != null ? dateFmt.format(payDate.toLocal()) : '—',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
