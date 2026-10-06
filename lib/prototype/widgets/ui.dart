import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../mock_data.dart';

/// Visual language of the prototype: white cards with black outlines,
/// matching the line-art room.
const ink = Color(0xFF111111);
const muted = Color(0xFF6B7280);
const gold = Color(0xFFC9A227);

Color statusColor(SalonStatus s) => switch (s) {
  SalonStatus.available => const Color(0xFF10B981),
  SalonStatus.busy => const Color(0xFFF59E0B),
  SalonStatus.closed => const Color(0xFF9CA3AF),
};

String statusLabel(MockSalon s) => switch (s.status) {
  SalonStatus.available =>
    s.waitMinutes == 0 ? 'No wait' : '~${s.waitMinutes} min',
  SalonStatus.busy => 'Busy · ~${s.waitMinutes} min',
  SalonStatus.closed => 'Closed',
};

class InkCard extends StatelessWidget {
  const InkCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  /// Outline color; defaults to the theme card border.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    // Same card as the owner app (AppTheme.cardTheme).
    return Material(
      color: color ?? Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: borderColor == null
            ? const BorderSide(color: AppTheme.surfaceBorder, width: 1.5)
            : BorderSide(color: borderColor!, width: 2.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(14),
          child: child,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
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

class Stars extends StatelessWidget {
  const Stars(this.rating, {super.key, this.reviews, this.size = 14});

  final double rating;
  final int? reviews;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: size + 2, color: gold),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: size),
        ),
        if (reviews != null)
          Text(
            ' ($reviews)',
            style: TextStyle(color: muted, fontSize: size - 1),
          ),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.salon, {super.key});

  final MockSalon salon;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(salon.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            statusLabel(salon),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.radius = 20, this.dimmed = false});

  final String name;
  final double radius;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: dimmed ? const Color(0xFFD1D5DB) : ink,
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}

/// Thin banner reminding testers that this is sample data.
class PrototypeBanner extends StatelessWidget {
  const PrototypeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: gold,
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: const Text(
        'PROTOTYPE · SAMPLE DATA',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: ink,
        ),
      ),
    );
  }
}

/// Full-width main action, styled by the shared theme like the owner app.
Widget primaryButton(String label, VoidCallback? onPressed, {IconData? icon}) {
  return ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(double.infinity, 50),
    ),
    onPressed: onPressed,
    icon: Icon(icon ?? Icons.check_rounded),
    label: Text(label),
  );
}

void showDone(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
      ),
    );
}
