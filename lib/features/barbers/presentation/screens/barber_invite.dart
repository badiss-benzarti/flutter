import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/cloud/cloud_invites.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers/cloud_providers.dart';
import '../../../../core/ui/ui_helpers.dart';
import '../../../auth_onboarding/presentation/auth_providers.dart';
import '../../domain/barber.dart';

/// On a roster card: "Linked to the app", or a button to invite the barber.
class BarberAppLink extends ConsumerWidget {
  const BarberAppLink({super.key, required this.barber});

  final Barber barber;

  static const _green = Color(0xFF166534);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (barber.isLinkedToApp) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.phone_iphone, size: 14, color: _green),
          SizedBox(width: 4),
          Text(
            'Linked to the app',
            style: TextStyle(
              color: _green,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    // Invitations need the salon on the server.
    final isCloud = ref.watch(
      authProvider.select((s) => s.owner?.isCloudAccount ?? false),
    );
    if (!isCloud) return const SizedBox.shrink();

    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: Colors.black,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      onPressed: () => _invite(context, ref),
      icon: const Icon(Icons.send_to_mobile_outlined, size: 16),
      label: const Text(
        'Invite to the app',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    BarberInvite? invite;
    final ok = await runAction(context, () async {
      try {
        invite = await ref
            .read(cloudInvitesProvider)
            .createBarberInvite(barber.id);
      } on AppException catch (e) {
        // A barber added offline has not reached the server yet.
        if (e.message == 'Barber not found.') {
          throw const AppException(
            'This barber is not on the server yet. Check your connection '
            'and try again in a moment.',
          );
        }
        rethrow;
      }
    });
    if (!ok || invite == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _InviteDialog(barberName: barber.name, invite: invite!),
    );
  }
}

class _InviteDialog extends StatelessWidget {
  const _InviteDialog({required this.barberName, required this.invite});

  final String barberName;
  final BarberInvite invite;

  @override
  Widget build(BuildContext context) {
    final code = invite.code;
    final readable = '${code.substring(0, 4)} ${code.substring(4)}';
    return AlertDialog(
      title: Text('Invite $barberName'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Give this code to $barberName. In the app: Who are you? → '
            'Barber → create an account → enter the code.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              readable,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Works once, until '
            '${DateFormat('d MMM, HH:mm').format(invite.expiresAt)}. '
            'A new code replaces this one.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) showSnack(context, 'Code copied.');
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
