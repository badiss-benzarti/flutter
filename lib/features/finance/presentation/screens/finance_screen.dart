import 'package:barber_shop_owner/core/ui/ui_helpers.dart';
import 'package:barber_shop_owner/features/finance/domain/finance_summary.dart';
import 'package:barber_shop_owner/features/finance/domain/service_ticket.dart';
import 'package:barber_shop_owner/features/finance/presentation/finance_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financeAsync = ref.watch(financeProvider);
    final range = ref.watch(financeRangeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(financeProvider.notifier).loadSummary(),
          ),
        ],
      ),
      body: Column(
        children: [
          _PeriodSelector(range: range),
          Expanded(
            child: financeAsync.when(
              skipLoadingOnRefresh: true,
              skipLoadingOnReload: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: TextButton(
                  onPressed: () =>
                      ref.read(financeProvider.notifier).loadSummary(),
                  child: const Text('Could not load finances. Tap to retry.'),
                ),
              ),
              data: (summary) => RefreshIndicator(
                onRefresh: () =>
                    ref.read(financeProvider.notifier).loadSummary(),
                child: _FinanceBody(summary: summary, range: range),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector({required this.range});

  final FinanceRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(financeRangeProvider.notifier);
    final dateFormat = DateFormat('d MMM');
    final customLabel = range.period == FinancePeriod.custom
        ? range.isSingleDay
              ? dateFormat.format(range.start)
              : '${dateFormat.format(range.start)} – '
                    '${dateFormat.format(range.end.subtract(const Duration(days: 1)))}'
        : 'Custom…';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _chip('Today', FinancePeriod.today, notifier),
          _chip('Last 7 days', FinancePeriod.last7Days, notifier),
          _chip('Last 30 days', FinancePeriod.last30Days, notifier),
          ChoiceChip(
            avatar: const Icon(Icons.date_range, size: 16),
            label: Text(customLabel),
            selected: range.period == FinancePeriod.custom,
            onSelected: (_) async {
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 5),
                lastDate: now,
                initialDateRange: DateTimeRange(
                  start: range.start,
                  end: range.end.subtract(const Duration(days: 1)),
                ),
              );
              if (picked != null) notifier.selectCustom(picked);
            },
          ),
        ],
      ),
    );
  }

  Widget _chip(
    String label,
    FinancePeriod period,
    FinanceRangeNotifier notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: range.period == period,
        onSelected: (_) => notifier.select(period),
      ),
    );
  }
}

class _FinanceBody extends StatelessWidget {
  const _FinanceBody({required this.summary, required this.range});

  final FinanceSummary summary;
  final FinanceRange range;

  @override
  Widget build(BuildContext context) {
    final periodLabel = switch (range.period) {
      FinancePeriod.today => "TODAY'S",
      FinancePeriod.last7Days => 'LAST 7 DAYS',
      FinancePeriod.last30Days => 'LAST 30 DAYS',
      FinancePeriod.custom => 'PERIOD',
    };

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$periodLabel SERVICE REVENUE',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatMoney(summary.grossRevenue),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 20,
                runSpacing: 10,
                children: [
                  _stat(
                    'Shop Net Profit',
                    formatMoney(summary.shopNetRevenue),
                    const Color(0xFF10B981),
                  ),
                  _stat(
                    'Barber Commissions',
                    formatMoney(summary.barberPayouts),
                    const Color(0xFF60A5FA),
                  ),
                  _stat('Tips', formatMoney(summary.tipsTotal), Colors.white),
                  _stat(
                    'Clients Served',
                    '${summary.totalClientsServed}',
                    Colors.white,
                  ),
                  _stat(
                    'Avg. Ticket',
                    formatMoney(summary.averageTicket),
                    Colors.white,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Collected (incl. tips)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _registerCard(
                'Cash',
                formatMoney(summary.cashTotal),
                Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _registerCard(
                'Card',
                formatMoney(summary.cardTotal),
                Icons.credit_card,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _registerCard(
                'Transfer',
                formatMoney(summary.transferTotal),
                Icons.account_balance_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Barber Payouts',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (summary.payoutsByBarber.isEmpty)
          _emptyBox('No payouts for this period.')
        else
          Card(
            child: Column(
              children: summary.payoutsByBarber.map((p) {
                return ListTile(
                  title: Text(
                    p.barberName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${p.clientsServed} client(s) • '
                    'Commission ${formatMoney(p.commission)} • '
                    'Tips ${formatMoney(p.tips)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    formatMoney(p.totalOwed),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 24),
        const Text(
          'Service Ledger',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (summary.tickets.isEmpty)
          _emptyBox(
            'No completed services in this period.\n'
            'Check out clients on the floor plan to record income.',
          )
        else
          ...summary.tickets.map((t) => _TicketTile(ticket: t, range: range)),
      ],
    );
  }

  Widget _stat(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _registerCard(String title, String amount, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket, required this.range});

  final ServiceTicket ticket;
  final FinanceRange range;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat(range.isSingleDay ? 'h:mm a' : 'd MMM, h:mm a')
        .format(ticket.timestamp);
    final (bg, fg, icon) = switch (ticket.paymentMethod) {
      PaymentMethod.cash => (
        const Color(0xFFDCFCE7),
        const Color(0xFF166534),
        Icons.attach_money,
      ),
      PaymentMethod.card => (
        const Color(0xFFDBEAFE),
        const Color(0xFF1E40AF),
        Icons.credit_card,
      ),
      PaymentMethod.transfer => (
        const Color(0xFFF3E8FF),
        const Color(0xFF6B21A8),
        Icons.account_balance_outlined,
      ),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: bg,
          child: Icon(icon, color: fg),
        ),
        title: Text(
          ticket.clientName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${ticket.serviceNames.join(", ")} • Chair #${ticket.chairNumber} • $time',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatMoney(ticket.totalPrice + ticket.tip),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              ticket.tip > 0
                  ? 'Tip ${formatMoney(ticket.tip)}'
                  : 'Shop ${formatMoney(ticket.shopCut)}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF10B981)),
            ),
          ],
        ),
      ),
    );
  }
}
