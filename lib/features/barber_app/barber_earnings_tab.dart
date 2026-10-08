import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/errors/app_exception.dart';
import '../../core/ui/dashboard_widgets.dart';
import '../../core/ui/ui_helpers.dart';
import '../finance/presentation/screens/finance_screen.dart' show paymentStyle;
import 'barber_earnings.dart';

/// The barber's own earnings, laid out like the owner's Finance screen.
class BarberEarningsTab extends ConsumerWidget {
  const BarberEarningsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(barberEarningLinesProvider);
    final period = ref.watch(barberEarningsPeriodProvider);

    Future<void> reload() =>
        ref.refresh(barberEarningLinesProvider.future).then((_) {});

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Earnings'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: reload,
          ),
        ],
      ),
      body: Column(
        children: [
          PeriodChips<EarningsPeriod>(
            options: const [
              ('Today', EarningsPeriod.today),
              ('Last 7 days', EarningsPeriod.last7Days),
              ('Last 30 days', EarningsPeriod.last30Days),
            ],
            selected: period,
            onSelected: ref.read(barberEarningsPeriodProvider.notifier).select,
          ),
          Expanded(
            child: switch (lines) {
              AsyncData(:final value) => RefreshIndicator(
                onRefresh: reload,
                child: _EarningsBody(
                  summary: EarningsSummary.of(value, period, DateTime.now()),
                  period: period,
                ),
              ),
              AsyncError(:final error) => Center(
                child: TextButton(
                  onPressed: reload,
                  child: Text('${describeError(error)}\nTap to retry.'),
                ),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}

class _EarningsBody extends StatelessWidget {
  const _EarningsBody({required this.summary, required this.period});

  final EarningsSummary summary;
  final EarningsPeriod period;

  @override
  Widget build(BuildContext context) {
    final label = switch (period) {
      EarningsPeriod.today => 'Today · you earned',
      EarningsPeriod.last7Days => 'Last 7 days · you earned',
      EarningsPeriod.last30Days => 'Last 30 days · you earned',
    };
    final timeFormat = DateFormat(
      period == EarningsPeriod.today ? 'h:mm a' : 'd MMM, h:mm a',
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        MoneyHeroCard(
          label: label,
          amount: formatMoney(summary.earned),
          stats: [
            HeroStat(
              'Commission',
              formatMoney(summary.commission),
              MoneyHeroCard.blue,
            ),
            HeroStat('Tips', formatMoney(summary.tips), MoneyHeroCard.green),
            HeroStat('Clients Served', '${summary.clientsServed}'),
            HeroStat('Per Client', formatMoney(summary.averagePerClient)),
          ],
        ),
        const SectionHeading('Breakdown'),
        Row(
          children: [
            Expanded(
              child: AmountCard(
                title: 'Commission',
                amount: formatMoney(summary.commission),
                icon: Icons.content_cut,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AmountCard(
                title: 'Tips',
                amount: formatMoney(summary.tips),
                icon: Icons.volunteer_activism_outlined,
              ),
            ),
          ],
        ),
        const SectionHeading('Last 7 days'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
            child: WeekBarChart(summary.lastSevenDays),
          ),
        ),
        const SectionHeading('My Clients'),
        if (summary.lines.isEmpty)
          const EmptyBox('No clients in this period yet.')
        else
          for (final line in summary.lines)
            Builder(
              builder: (_) {
                final (bg, fg, icon) = paymentStyle(line.paymentMethod);
                return LedgerTile(
                  icon: icon,
                  iconBackground: bg,
                  iconColor: fg,
                  title: line.clientName,
                  subtitle:
                      '${line.services} • Chair #${line.chairNumber} • '
                      '${timeFormat.format(line.time)}',
                  amount: formatMoney(line.earned),
                  note: line.tip > 0
                      ? 'Tip ${formatMoney(line.tip)}'
                      : 'Commission',
                );
              },
            ),
      ],
    );
  }
}
