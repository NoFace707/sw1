import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../data/auth_service.dart';
import '../../../home/presentation/pages/home_page.dart';
import 'login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.authService});
  final AuthService? authService;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final session = await AuthSessionManager.restoreClientSession(
      authService: widget.authService,
    );
    if (!mounted) return;
    final page = session == null
        ? LoginPage(authService: widget.authService)
        : HomePage(user: session.user, authService: widget.authService);
    Navigator.of(
      context,
    ).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => page), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: ValueKey('splash-page'),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 64,
              color: Color(0xFF0F766E),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Comprobando sesión…'),
          ],
        ),
      ),
    );
  }
}
