import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../constants/ui_constants.dart';

enum _AccountType { climber, facility }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Shared
  final _emailCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _initialFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isRegisterMode = false;
  _AccountType _accountType = _AccountType.climber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestInitialFocus();
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _initialFocusNode.dispose();
    super.dispose();
  }

  void _requestInitialFocus() {
    if (!mounted || defaultTargetPlatform != TargetPlatform.android) return;
    _initialFocusNode.requestFocus();
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

    if (email.isEmpty || username.isEmpty || password.isEmpty) {
      _snack('Please fill in email, username, and password');
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
      final ok = await AuthService().register(email, username, password);
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
      for (final c in [_emailCtrl, _userCtrl, _passCtrl, _confirmPassCtrl]) {
        c.clear();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestInitialFocus();
    });
  }

  void _toggleAuthMode() {
    _requestInitialFocus();
    setState(() => _isRegisterMode = !_isRegisterMode);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  VoidCallback get _submitAction => _isRegisterMode
      ? (_accountType == _AccountType.facility
          ? _submitRegisterFacility
          : _submitRegisterClimber)
      : _submitLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegisterMode ? 'Create Account' : 'Login'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isRegisterMode) ..._buildRegisterFields(theme),
              if (!_isRegisterMode) ...[
                _field(_userCtrl, 'Username or Email', focusNode: _initialFocusNode),
                const SizedBox(height: AppSpacing.md),
                _passwordField(
                  _passCtrl, 'Password', _obscurePassword,
                  () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                const SizedBox(height: AppSpacing.lg),
                _googleButton(),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _isLoading ? null : _toggleAuthMode,
                child: Text(_isRegisterMode
                    ? 'Already have an account? Login'
                    : 'Create account'),
              ),
              const SizedBox(height: AppSpacing.lg),
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : FilledButton(
                      onPressed: _submitAction,
                      child: Text(_isRegisterMode ? 'Register' : 'Login'),
                    ),
            ],
          ),
        ),
      ),
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
      const SizedBox(height: AppSpacing.lg),
      _field(
        _emailCtrl,
        'Email',
        type: TextInputType.emailAddress,
        focusNode: _initialFocusNode,
      ),
      const SizedBox(height: AppSpacing.sm),
      _field(_userCtrl, 'Username'),
      const SizedBox(height: AppSpacing.sm),
      _passwordField(
        _passCtrl, 'Password', _obscurePassword,
        () => setState(() => _obscurePassword = !_obscurePassword),
      ),
      const SizedBox(height: AppSpacing.sm),
      _passwordField(
        _confirmPassCtrl, 'Confirm Password', _obscureConfirmPassword,
        () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
      ),
      if (_accountType == _AccountType.facility) ...[
        const SizedBox(height: AppSpacing.md),
        Text(
          'After registration, log in and claim your facility from your profile.',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
      const SizedBox(height: AppSpacing.sm),
    ];
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType type = TextInputType.text,
    FocusNode? focusNode,
  }) {
    return TextField(
      controller: ctrl,
      enabled: !_isLoading,
      keyboardType: type,
      focusNode: focusNode,
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
    return OutlinedButton.icon(
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
    );
  }
}

Future<bool?> showLoginDialog(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const LoginPage()),
  );
}
