import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/bookings/presentation/book_slot_screen.dart';
import '../features/bookings/presentation/business_appointments_screen.dart';
import '../features/bookings/presentation/business_detail_screen.dart';
import '../features/businesses/presentation/create_business_screen.dart';
import '../features/dashboard/presentation/business_dashboard_screen.dart';
import '../features/home/presentation/home_shell.dart';
import '../features/services/presentation/services_screen.dart';

abstract class AppRoutes {
  static const home = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const newBusiness = '/business/new';
  static String services(String businessId) => '/business/$businessId/services';
  static String appointments(String businessId) => '/business/$businessId/appointments';
  static String dashboard(String businessId) => '/business/$businessId/dashboard';
  static String businessDetail(String businessId) => '/browse/$businessId';
  static String book(String businessId, String serviceId) =>
      '/browse/$businessId/book/$serviceId';
}

/// Makes GoRouter re-run `redirect` whenever the auth stream emits.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = _AuthRefresh(auth.authStateChanges);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      // The reset screen handles both signed-out (verifying link) and
      // signed-in (recovery session) states itself.
      if (loc == AppRoutes.resetPassword) return null;

      final loggedIn = auth.currentUser != null;
      final onAuthPage = loc == AppRoutes.login ||
          loc == AppRoutes.register ||
          loc == AppRoutes.forgotPassword;

      if (!loggedIn && !onAuthPage) return AppRoutes.login;
      if (loggedIn && onAuthPage) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeShell()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (_, __) => const ResetPasswordScreen(),
      ),
      // Safety net: if the OS hands the auth deep link to the router as a path.
      GoRoute(path: '/auth-callback', redirect: (_, __) => AppRoutes.home),
      GoRoute(
        path: AppRoutes.newBusiness,
        builder: (_, __) => const CreateBusinessScreen(),
      ),
      GoRoute(
        path: '/business/:id/services',
        builder: (_, s) => ServicesScreen(businessId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/business/:id/appointments',
        builder: (_, s) =>
            BusinessAppointmentsScreen(businessId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/business/:id/dashboard',
        builder: (_, s) =>
            BusinessDashboardScreen(businessId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/browse/:businessId',
        builder: (_, s) =>
            BusinessDetailScreen(businessId: s.pathParameters['businessId']!),
      ),
      GoRoute(
        path: '/browse/:businessId/book/:serviceId',
        builder: (_, s) => BookSlotScreen(
          businessId: s.pathParameters['businessId']!,
          serviceId: s.pathParameters['serviceId']!,
        ),
      ),
    ],
  );

  // Opening the reset-password email link emits a passwordRecovery event.
  final recoverySub = auth.authStateChanges.listen((state) {
    if (state.event == AuthChangeEvent.passwordRecovery) {
      router.go(AppRoutes.resetPassword);
    }
  });
  ref.onDispose(recoverySub.cancel);

  return router;
});
