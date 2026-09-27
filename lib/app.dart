import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth_onboarding/presentation/auth_providers.dart';
import 'features/auth_onboarding/presentation/screens/auth_screen.dart';
import 'features/auth_onboarding/presentation/screens/onboarding_wizard_screen.dart';
import 'features/dashboard/presentation/screens/main_navigation_screen.dart';

class BarberShopOwnerApp extends ConsumerWidget {
  const BarberShopOwnerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    Widget homeScreen;
    if (authState.isLoading) {
      homeScreen = const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    } else if (!authState.isAuthenticated) {
      homeScreen = const AuthScreen();
    } else if (!authState.hasCompletedOnboarding) {
      homeScreen = const OnboardingWizardScreen();
    } else {
      homeScreen = const MainNavigationScreen();
    }

    return MaterialApp(
      title: 'Barber Shop Owner Console',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: homeScreen,
    );
  }
}
