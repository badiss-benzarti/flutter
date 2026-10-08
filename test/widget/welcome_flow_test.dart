import 'package:barber_shop_owner/app.dart';
import 'package:barber_shop_owner/core/providers/cloud_providers.dart';
import 'package:barber_shop_owner/features/auth_onboarding/presentation/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_cloud_auth.dart';

class _SignedOut extends AuthNotifier {
  @override
  AuthState build() => const AuthState();
}

void main() {
  testWidgets('the app opens on "Who are you?" and routes each role', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_SignedOut.new),
          cloudAuthProvider.overrideWithValue(FakeCloudAuth()),
        ],
        child: const BarberShopOwnerApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Who are you?'), findsOneWidget);
    // Only the client side is still a preview.
    expect(find.text('PREVIEW'), findsOneWidget);

    // Owners go to their sign-in, and can come back.
    await tester.tap(find.text('Salon owner'));
    await tester.pump();
    expect(find.text('Barber Shop Owner Portal'), findsOneWidget);
    expect(find.text('Explore the demo shop'), findsOneWidget);
    await tester.tap(find.text('Who are you?'));
    await tester.pump();

    // Barbers start with their salon code (no owner demo), and can come back.
    await tester.tap(find.text('Barber'));
    await tester.pump();
    expect(find.text('Enter your salon code'), findsOneWidget);
    expect(find.text('Already have an account? Sign in'), findsOneWidget);
    expect(find.text('Explore the demo shop'), findsNothing);
    expect(find.text('See a preview of the barber space'), findsOneWidget);
    await tester.tap(find.text('Who are you?'));
    await tester.pump();

    // Clients open their preview space, and come back to the welcome.
    await tester.tap(find.text('Client'));
    // The salon sign animates forever: wait for the route instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('PREVIEW · SAMPLE DATA'), findsOneWidget);
    Navigator.of(tester.element(find.text('PREVIEW · SAMPLE DATA'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Salon owner'), findsOneWidget);
  });
}
