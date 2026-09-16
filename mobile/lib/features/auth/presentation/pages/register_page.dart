import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../data/auth_service.dart';
import '../../../home/presentation/pages/home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.authService});
  final AuthService? authService;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  AuthService get _service => widget.authService ?? AuthService();

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final session = await _service.register(
        firstName: _firstName.text,
        lastName: _lastName.text,
        email: _email.text,
        password: _password.text,
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
    String? requiredField(String? value) =>
        value == null || value.trim().isEmpty ? 'Campo obligatorio.' : null;
    return Scaffold(
      key: const ValueKey('register-page'),
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Regístrate',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        key: const ValueKey('register-error'),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  TextFormField(
                    key: const ValueKey('first-name-field'),
                    controller: _firstName,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: requiredField,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('last-name-field'),
                    controller: _lastName,
                    decoration: const InputDecoration(labelText: 'Apellido'),
                    validator: requiredField,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('register-email-field'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                    ),
                    validator: (value) => value == null || !value.contains('@')
                        ? 'Ingresa un correo válido.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('register-password-field'),
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    validator: (value) => value == null || value.length < 8
                        ? 'Usa al menos 8 caracteres.'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const ValueKey('register-submit'),
                    onPressed: _submitting ? null : _submit,
                    child: Text(_submitting ? 'Creando…' : 'Crear cuenta'),
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
