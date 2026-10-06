import 'package:barber_shop_owner/app.dart';
import 'package:barber_shop_owner/features/auth_onboarding/presentation/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
        overrides: [authProvider.overrideWith(_SignedOut.new)],
        child: const BarberShopOwnerApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Who are you?'), findsOneWidget);
    expect(find.text('PREVIEW'), findsNWidgets(2));

    // Owners go to sign-in, and can come back.
    await tester.tap(find.text('Salon owner'));
    await tester.pump();
    expect(find.text('Barber Shop Owner Portal'), findsOneWidget);
    await tester.tap(find.text('Who are you?'));
    await tester.pump();
    expect(find.text('Salon owner'), findsOneWidget);

    // Barbers open their preview space, and come back to the welcome.
    await tester.tap(find.text('Barber'));
    // The salon sign and scissors animate forever: wait for the route.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('PREVIEW · SAMPLE DATA'), findsOneWidget);
    Navigator.of(tester.element(find.text('Agenda'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Salon owner'), findsOneWidget);
  });
}
