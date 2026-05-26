import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/navigation/app_route_observer.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Wraps login/welcome/register so signed-in users never see credential forms.
class LoggedOutOnlyGate extends StatefulWidget {
  const LoggedOutOnlyGate({super.key, required this.child});

  final Widget child;

  @override
  State<LoggedOutOnlyGate> createState() => _LoggedOutOnlyGateState();
}

class _LoggedOutOnlyGateState extends State<LoggedOutOnlyGate> with RouteAware {
  bool _redirecting = false;

  bool _shouldSkipAuthRedirect(AuthProvider auth) {
    if (auth.justDeletedAccount) return true;
    final args = ModalRoute.of(context)?.settings.arguments;
    return args is Map && args['showAccountDeletedNotification'] == true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSessionAndRedirect());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      authRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    authRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _syncSessionAndRedirect();
  }

  Future<void> _syncSessionAndRedirect() async {
    final auth = context.read<AuthProvider>();
    if (_redirecting || !mounted || _shouldSkipAuthRedirect(auth)) return;
    await auth.bootstrap();
    if (!mounted || _shouldSkipAuthRedirect(context.read<AuthProvider>())) return;
    if (context.read<AuthProvider>().isLoggedIn) {
      _redirectToDashboard();
    }
  }

  void _redirectToDashboard() {
    if (_redirecting || !mounted) return;
    _redirecting = true;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.dashboard, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (_shouldSkipAuthRedirect(auth)) {
      return widget.child;
    }

    if (!auth.hasBootstrapped || auth.isLoading) {
      return const _AuthGateLoading();
    }

    if (auth.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_shouldSkipAuthRedirect(context.read<AuthProvider>())) {
          _redirectToDashboard();
        }
      });
      return const _AuthGateLoading();
    }

    return widget.child;
  }
}

class _AuthGateLoading extends StatelessWidget {
  const _AuthGateLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
