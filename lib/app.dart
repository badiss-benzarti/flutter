import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth_onboarding/presentation/auth_providers.dart';
import 'features/auth_onboarding/presentation/screens/auth_screen.dart';
import 'features/auth_onboarding/presentation/screens/onboarding_wizard_screen.dart';
import 'features/dashboard/presentation/screens/main_navigation_screen.dart';
import 'features/welcome/entry_role.dart';
import 'features/welcome/welcome_screen.dart';

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
      // "Who are you?" first; owners then sign in.
      final role = ref.watch(entryRoleProvider);
      homeScreen = role == EntryRole.owner
          ? const AuthScreen()
          : const WelcomeScreen();
    } else if (!authState.hasCompletedOnboarding) {
      homeScreen = const OnboardingWizardScreen();
    } else {
      homeScreen = const MainNavigationScreen();
    }

    return MaterialApp(
      title: WelcomeScreen.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: homeScreen,
    );
  }
}
