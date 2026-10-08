import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/ui/dashboard_widgets.dart';
import '../../core/ui/room_navigation_bar.dart';
import '../../prototype/client/client_shell.dart';
import '../welcome/entry_role.dart';
import 'client_directory.dart';
import 'client_map_screen.dart';
import 'client_salon_page.dart';
import 'client_session.dart';

/// The client app: the map of salons in the middle, the latest cuts in
/// Social, and the account in Profile. Works without an account.
class ClientSpace extends StatefulWidget {
  const ClientSpace({super.key});

  @override
  State<ClientSpace> createState() => _ClientSpaceState();
}

class _ClientSpaceState extends State<ClientSpace> {
  static const _mapTab = 1;

  int _tab = _mapTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          const _ProfileTab(),
          ClientMapScreen(active: _tab == _mapTab),
          const _SocialTab(),
        ],
      ),
      bottomNavigationBar: RoomNavigationBar(
        items: const [
          RoomNavItem(Icons.person_outline, Icons.person, 'Profile'),
          RoomNavItem(Icons.map_outlined, Icons.map, 'Map'),
          RoomNavItem(
            Icons.photo_library_outlined,
            Icons.photo_library,
            'Social',
          ),
        ],
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Social: the latest cuts from listed salons
// -----------------------------------------------------------------------------

class _SocialTab extends ConsumerWidget {
  const _SocialTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(latestPostsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fresh Cuts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(latestPostsProvider),
          ),
        ],
      ),
      body: switch (posts) {
        AsyncData(:final value) when value.isEmpty => const Padding(
          padding: EdgeInsets.all(16),
          child: EmptyBox('No photos yet. Barbers post their cuts here.'),
        ),
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(latestPostsProvider.future),
          child: PostGrid(posts: value, columns: 2, showSalon: true),
        ),
        AsyncError(:final error) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(latestPostsProvider),
            child: Text('${describeError(error)}\nTap to retry.'),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Profile: the account, or signing in / up
// -----------------------------------------------------------------------------

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(clientSessionProvider);
    final user = session.user;

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user == null)
            const _AccountForm()
          else ...[
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
                    user.fullName.isEmpty
                        ? '?'
                        : user.fullName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
                title: Text(
                  user.fullName.isEmpty ? 'Client' : user.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                subtitle: Text(user.email),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.schedule),
                title: Text('Queue, bookings and ratings'),
                subtitle: Text(
                  'Coming in the next updates: join a line from the app, '
                  'book a barber, rate your cut.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Sign out',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => ref.read(clientSessionProvider.notifier).logout(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.visibility_outlined),
                  title: const Text('See upcoming features'),
                  subtitle: const Text('Bookings, VIP, favorites (preview)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ClientShell(),
                    ),
                  ),
                ),
                if (user == null) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: const Text('Change space'),
                    subtitle: const Text('Owner or barber? Go back.'),
                    onTap: () => ref.read(entryRoleProvider.notifier).reset(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountForm extends ConsumerStatefulWidget {
  const _AccountForm();

  @override
  ConsumerState<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<_AccountForm> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(clientSessionProvider).isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    final session = ref.read(clientSessionProvider.notifier);
    if (_registering) {
      await session.register(
        fullName: _name.text,
        email: _email.text,
        password: _password.text,
      );
    } else {
      await session.login(email: _email.text, password: _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(clientSessionProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _registering ? 'Create your account' : 'Sign in',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Browse salons freely. An account lets you join a line, book '
                'and rate your cuts.',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (session.errorMessage != null)
                _Notice(session.errorMessage!, error: true),
              if (session.infoMessage != null) _Notice(session.infoMessage!),
              if (_registering) ...[
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? 'Please enter your name'
                      : null,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Please enter an email';
                  return _emailPattern.hasMatch(value)
                      ? null
                      : 'Enter a valid email address';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (_registering && v.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: session.isLoading ? null : _submit,
                child: session.isLoading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(_registering ? 'Create account' : 'Sign in'),
              ),
              TextButton(
                onPressed: () {
                  ref.read(clientSessionProvider.notifier).clearMessages();
                  setState(() => _registering = !_registering);
                },
                child: Text(
                  _registering
                      ? 'Already have an account? Sign in'
                      : 'New here? Create an account',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, {this.error = false});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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

/// Opens a salon's page from anywhere in the client app.
void openSalon(BuildContext context, String shopId) => Navigator.of(context)
    .push(
      MaterialPageRoute<void>(builder: (_) => ClientSalonPage(shopId: shopId)),
    );
