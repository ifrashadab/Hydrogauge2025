import 'package:flutter/material.dart';
import 'package:hydrogauge/services/api_client.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController name = TextEditingController();
  final TextEditingController id = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController password = TextEditingController();
  String role = 'Employee';
  final ApiClient _api = ApiClient();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: id,
                  decoration: const InputDecoration(
                    labelText: 'Email / Employee ID',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  items: const [
                    DropdownMenuItem(
                      value: 'Employee',
                      child: Text('Employee'),
                    ),
                    DropdownMenuItem(
                      value: 'Supervisor',
                      child: Text('Supervisor'),
                    ),
                    DropdownMenuItem(value: 'Analyst', child: Text('Analyst')),
                  ],
                  onChanged: (v) => setState(() => role = v ?? role),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          final username = id.text.trim();
                          final pass = password.text;
                          if (username.isEmpty || pass.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Enter username and password'),
                              ),
                            );
                            return;
                          }
                          setState(() => _loading = true);
                          try {
                            final resp = await _api.register(
                              username: username,
                              password: pass,
                              fullName: name.text.trim(),
                              phone: phone.text.trim(),
                              role: role,
                            );
                            if (resp['ok'] == true) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Registered successfully. Please login.',
                                  ),
                                ),
                              );
                              Navigator.pop(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Registration failed: ${resp['error'] ?? 'Unknown'}',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Registration error: $e')),
                            );
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
                  child: Text(_loading ? 'Please wait…' : 'Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
