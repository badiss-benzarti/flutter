import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/ui_helpers.dart';
import 'barber_session.dart';
import 'barber_space.dart';

/// What a signed-in barber sees: the code screen until they join a salon,
/// then their space.
class BarberGate extends ConsumerWidget {
  const BarberGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(barberSessionProvider);
    if (session.link != null) return const BarberSpace();
    if (session.isLoading && session.errorMessage == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }
    return const JoinSalonScreen();
  }
}

class JoinSalonScreen extends ConsumerStatefulWidget {
  const JoinSalonScreen({super.key});

  @override
  ConsumerState<JoinSalonScreen> createState() => _JoinSalonScreenState();
}

class _JoinSalonScreenState extends ConsumerState<JoinSalonScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (ref.read(barberSessionProvider).isLoading) return;
    await ref.read(barberSessionProvider.notifier).join(_code.text);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(barberSessionProvider);
    final notifier = ref.read(barberSessionProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Join your salon',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ask your salon owner for your code. They find it in '
                    'Team → your name → Invite to the app.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  if (session.errorMessage != null)
                    _MessageBox(session.errorMessage!, error: true),
                  TextField(
                    controller: _code,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 8,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                      TextInputFormatter.withFunction(
                        (_, value) =>
                            value.copyWith(text: value.text.toUpperCase()),
                      ),
                    ],
                    onSubmitted: (_) => _join(),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'ABCD2345',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: session.isLoading ? null : _join,
                    child: session.isLoading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Join the salon'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Signed in as ${session.user?.email ?? ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: session.isLoading ? null : notifier.refresh,
                        child: const Text('Already joined? Refresh'),
                      ),
                      TextButton(
                        onPressed: notifier.logout,
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The barber's profile tab: who they are in the salon, name requests,
/// leaving the salon and signing out.
class BarberProfileTab extends ConsumerWidget {
  const BarberProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(barberSessionProvider);
    final notifier = ref.read(barberSessionProvider.notifier);
    final link = session.link!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: notifier.logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (session.errorMessage != null)
              _MessageBox(session.errorMessage!, error: true),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.black,
                  child: Text(
                    link.barberName.isEmpty
                        ? '?'
                        : link.barberName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
                title: Text(
                  link.barberName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                subtitle: Text('Barber at ${link.shopName}'),
              ),
            ),
            if (link.requestedName != null)
              _MessageBox(
                'You asked to be called "${link.requestedName}". Your salon '
                'owner will accept or decline it.',
              ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.chair_outlined),
                    title: const Text('My chair'),
                    trailing: Text(
                      link.assignedChair == null
                          ? 'Not assigned'
                          : '#${link.assignedChair}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.percent),
                    title: const Text('My commission'),
                    trailing: Text(
                      '${(link.commissionRate * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      link.isOnDuty
                          ? Icons.check_circle
                          : Icons.pause_circle_outline,
                      color: link.isOnDuty
                          ? const Color(0xFF10B981)
                          : Colors.grey,
                    ),
                    title: const Text('Today'),
                    trailing: Text(
                      link.isOnDuty ? 'On duty' : 'Off duty',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Ask to change my name'),
                    subtitle: const Text('Your salon owner approves it'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _askNewName(context, ref, link.barberName),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Leave the salon',
                      style: TextStyle(color: Colors.red),
                    ),
                    subtitle: const Text('You keep your account'),
                    onTap: () => _leave(context, ref, link.shopName),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _askNewName(
  BuildContext context,
  WidgetRef ref,
  String current,
) async {
  final controller = TextEditingController(text: current);
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Ask to change my name'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Name clients will see'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.black),
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: const Text('Send to my owner'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || name.trim().isEmpty || !context.mounted) return;
  await runAction(
    context,
    () => ref.read(barberSessionProvider.notifier).requestNameChange(name),
    successMessage: 'Sent. Your owner will answer.',
  );
}

Future<void> _leave(BuildContext context, WidgetRef ref, String shop) async {
  final confirmed = await confirmAction(
    context,
    title: 'Leave $shop?',
    message:
        'You keep your account, but you will no longer see this salon, '
        'its floor or your earnings there. The salon keeps your history. '
        'You can join again with a new code.',
    confirmLabel: 'Leave',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;
  await runAction(
    context,
    () => ref.read(barberSessionProvider.notifier).leave(),
  );
}

class _MessageBox extends StatelessWidget {
  const _MessageBox(this.message, {this.error = false});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: error ? const Color(0xFFF87171) : const Color(0xFF34D399),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: error ? const Color(0xFFB91C1C) : const Color(0xFF065F46),
          fontSize: 13,
        ),
      ),
    );
  }
}
