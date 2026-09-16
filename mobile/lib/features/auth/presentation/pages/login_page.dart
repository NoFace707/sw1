import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../data/auth_service.dart';
import '../../../home/presentation/pages/home_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.authService});
  final AuthService? authService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  AuthService get _service => widget.authService ?? AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final session = await _service.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      await AuthSessionManager.saveSession(session);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              HomePage(user: session.user, authService: widget.authService),
        ),
        (_) => false,
      );
    } on AuthServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('login-page'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.account_tree_outlined,
                      size: 60,
                      color: Color(0xFF0F766E),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Iniciar sesión',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          key: const ValueKey('auth-error'),
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    TextFormField(
                      key: const ValueKey('email-field'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                      ),
                      validator: (value) =>
                          value == null || !value.contains('@')
                          ? 'Ingresa un correo válido.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('password-field'),
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                      ),
                      validator: (value) => value == null || value.length < 8
                          ? 'La contraseña debe tener al menos 8 caracteres.'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const ValueKey('login-submit'),
                      onPressed: _submitting ? null : _submit,
                      child: Text(
                        _submitting ? 'Ingresando…' : 'Iniciar sesión',
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('go-register'),
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RegisterPage(
                                  authService: widget.authService,
                                ),
                              ),
                            ),
                      child: const Text('Crear una cuenta'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
