import 'package:flutter/material.dart';
import '../services/auth_service.dart';

enum _AccountType { climber, facility }

class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key});
  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  // Shared
  final _emailCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  // Climber-specific
  final _nameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _birthdateCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isRegisterMode = false;
  _AccountType _accountType = _AccountType.climber;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    _birthdateCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    final usernameOrEmail = _userCtrl.text.trim();
    final password = _passCtrl.text;

    if (usernameOrEmail.isEmpty || password.isEmpty) {
      _snack('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final ok = await AuthService().login(usernameOrEmail, password);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (ok) {
        Navigator.pop(context, true);
      } else {
        _snack('Invalid credentials');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack('Login error: $e');
    }
  }

  Future<void> _submitRegisterClimber() async {
    final email = _emailCtrl.text.trim();
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;
    final name = _nameCtrl.text.trim();
    final surname = _surnameCtrl.text.trim();
    final birthdate = _birthdateCtrl.text.trim();

    if (email.isEmpty || username.isEmpty || password.isEmpty ||
        name.isEmpty || surname.isEmpty || birthdate.isEmpty) {
      _snack('Please fill in all fields');
      return;
    }
    if (password != _confirmPassCtrl.text) {
      _snack('Passwords do not match');
      return;
    }
    if (password.length < 6) {
      _snack('Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final ok = await AuthService().register(
        email, username, password,
        name: name, surname: surname, birthdate: birthdate,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (ok) {
        _snack('Registration successful! Please log in.');
        _resetToLogin();
      } else {
        _snack('Registration failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack('Registration error: $e');
    }
  }

  Future<void> _submitRegisterFacility() async {
    final email = _emailCtrl.text.trim();
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty || username.isEmpty || password.isEmpty) {
      _snack('Please fill in all fields');
      return;
    }
    if (password != _confirmPassCtrl.text) {
      _snack('Passwords do not match');
      return;
    }
    if (password.length < 6) {
      _snack('Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final ok = await AuthService().registerFacilityOwner(email, username, password);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (ok) {
        _snack('Account created! Log in to claim your facility.');
        _resetToLogin();
      } else {
        _snack('Registration failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack('Registration error: $e');
    }
  }

  void _resetToLogin() {
    setState(() {
      _isRegisterMode = false;
      _accountType = _AccountType.climber;
      for (final c in [
        _emailCtrl, _userCtrl, _passCtrl, _confirmPassCtrl,
        _nameCtrl, _surnameCtrl, _birthdateCtrl,
      ]) {
        c.clear();
      }
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(_isRegisterMode ? 'Create Account' : 'Login'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isRegisterMode) ..._buildRegisterFields(theme),
            if (!_isRegisterMode) ...[
              _field(_userCtrl, 'Username or Email'),
              const SizedBox(height: 12),
              _passwordField(_passCtrl, 'Password', _obscurePassword,
                  () => setState(() => _obscurePassword = !_obscurePassword)),
              const SizedBox(height: 16),
              _googleButton(),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() => _isRegisterMode = !_isRegisterMode),
                  child: Text(_isRegisterMode
                      ? 'Have an account? Login'
                      : 'Create account'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ElevatedButton(
                onPressed: _isRegisterMode
                    ? (_accountType == _AccountType.facility
                        ? _submitRegisterFacility
                        : _submitRegisterClimber)
                    : _submitLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                ),
                child: Text(_isRegisterMode ? 'Register' : 'Login'),
              ),
      ],
    );
  }

  List<Widget> _buildRegisterFields(ThemeData theme) {
    return [
      SegmentedButton<_AccountType>(
        segments: const [
          ButtonSegment(
            value: _AccountType.climber,
            label: Text('Climber'),
            icon: Icon(Icons.person),
          ),
          ButtonSegment(
            value: _AccountType.facility,
            label: Text('Gym / Facility'),
            icon: Icon(Icons.domain),
          ),
        ],
        selected: {_accountType},
        onSelectionChanged: (s) => setState(() => _accountType = s.first),
      ),
      const SizedBox(height: 16),

      _field(_emailCtrl, 'Email', type: TextInputType.emailAddress),
      const SizedBox(height: 12),
      _field(_userCtrl, 'Username'),
      const SizedBox(height: 12),

      if (_accountType == _AccountType.climber) ...[
        _field(_nameCtrl, 'First Name'),
        const SizedBox(height: 12),
        _field(_surnameCtrl, 'Surname'),
        const SizedBox(height: 12),
        _field(_birthdateCtrl, 'Birthdate (YYYY-MM-DD)',
            type: TextInputType.datetime),
        const SizedBox(height: 12),
      ],

      _passwordField(_passCtrl, 'Password', _obscurePassword,
          () => setState(() => _obscurePassword = !_obscurePassword)),
      const SizedBox(height: 12),
      _passwordField(_confirmPassCtrl, 'Confirm Password',
          _obscureConfirmPassword,
          () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)),

      if (_accountType == _AccountType.facility) ...[
        const SizedBox(height: 12),
        Text(
          'After registration, log in and claim your facility from your profile.',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ];
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      enabled: !_isLoading,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _passwordField(
    TextEditingController ctrl,
    String label,
    bool obscure,
    VoidCallback toggle,
  ) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      enabled: !_isLoading,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: obscure ? 'Show password' : 'Hide password',
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: toggle,
        ),
      ),
    );
  }

  Widget _googleButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.login),
        label: const Text('Sign in with Google'),
        onPressed: _isLoading
            ? null
            : () async {
                setState(() => _isLoading = true);
                try {
                  final ok = await AuthService().loginWithGoogle();
                  if (!mounted) return;
                  setState(() => _isLoading = false);
                  if (ok) {
                    Navigator.pop(context, true);
                  } else {
                    _snack('Google login failed');
                  }
                } catch (e) {
                  if (!mounted) return;
                  setState(() => _isLoading = false);
                  _snack('Google login error: $e');
                }
              },
      ),
    );
  }
}

Future<bool?> showLoginDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const LoginDialog(),
  );
}
