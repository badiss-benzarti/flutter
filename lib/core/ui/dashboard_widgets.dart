import 'package:flutter/material.dart';

/// Building blocks of the money screens (owner finance, barber earnings), so
/// every role reads its numbers the same way.

/// A figure under the headline amount of [MoneyHeroCard].
class HeroStat {
  const HeroStat(this.label, this.value, [this.color = Colors.white]);

  final String label;
  final String value;
  final Color color;
}

/// Black card with the headline amount and the figures behind it.
class MoneyHeroCard extends StatelessWidget {
  const MoneyHeroCard({
    super.key,
    required this.label,
    required this.amount,
    this.stats = const [],
  });

  final String label;
  final String amount;
  final List<HeroStat> stats;

  static const green = Color(0xFF10B981);
  static const blue = Color(0xFF60A5FA);
  static const gold = Color(0xFFC9A227);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [for (final s in stats) _stat(s)],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(HeroStat stat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          stat.label,
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          stat.value,
          style: TextStyle(
            color: stat.color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

/// Horizontal row of period chips (Today, Last 7 days...).
class PeriodChips<T> extends StatelessWidget {
  const PeriodChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.trailing,
  });

  final List<(String, T)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  /// An extra chip after the presets, e.g. a custom date range.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          for (final (label, value) in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: selected == value,
                onSelected: (_) => onSelected(value),
              ),
            ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Bold section title used between dashboard blocks.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small outlined tile with an icon, a caption and an amount.
class AmountCard extends StatelessWidget {
  const AmountCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    this.accent,
  });

  final String title;
  final String amount;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
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
          Icon(icon, size: 20, color: accent),
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
}

/// Outlined box with a centered message, for empty lists.
class EmptyBox extends StatelessWidget {
  const EmptyBox(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
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

/// One line of a ledger: who, what, how much.
class LedgerTile extends StatelessWidget {
  const LedgerTile({
    super.key,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.note,
    this.noteColor = const Color(0xFF10B981),
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String amount;
  final String? note;
  final Color noteColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconBackground,
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            if (note != null)
              Text(note!, style: TextStyle(fontSize: 10, color: noteColor)),
          ],
        ),
      ),
    );
  }
}
