import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../widgets/app_brand_mark.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String get _cleanEmail => _email.text.trim();
  String get _cleanPassword => _password.text.trim();

  String _fallbackNameFromEmail(String email) {
    final local = email.split('@').first.trim();
    if (local.isEmpty) return 'SafeRoute User';
    return local
        .split(RegExp(r'[._-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  bool _validate() {
    if (_cleanEmail.isEmpty || _cleanPassword.isEmpty) {
      setState(() {
        _error = 'Please enter email and password';
        _success = null;
      });
      return false;
    }
    if (!_cleanEmail.contains('@')) {
      setState(() {
        _error = 'Please enter a valid email address';
        _success = null;
      });
      return false;
    }
    if (_cleanPassword.length < 6) {
      setState(() {
        _error = 'Password must be at least 6 characters';
        _success = null;
      });
      return false;
    }
    return true;
  }

  Future<void> _signIn() async {
    if (!_validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      await SupabaseService.instance.signIn(
        email: _cleanEmail,
        password: _cleanPassword,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    if (!_validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final response = await SupabaseService.instance.signUp(
        email: _cleanEmail,
        password: _cleanPassword,
        fullName: _fallbackNameFromEmail(_cleanEmail),
      );
      if (!mounted) return;
      if (response.session != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        return;
      }
      setState(() {
        _success = 'Account created successfully. Sign in to continue.';
      });
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFDBEAFE).withValues(alpha: 0.5),
                ),
              ),
            ),
            Positioned(
              bottom: -90,
              left: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD1FAE5).withValues(alpha: 0.5),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 40),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 430),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [AppBrandMark(size: 58, iconSize: 30)],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'SAFEROUTE',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                          letterSpacing: 4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Navigate with confidence.',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Sign in to save trips, sync guardian tracking, and keep SOS alerts backed up to Supabase.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              color: Color(0xFF93C5FD),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Live tracking, safer route scoring, and guardian visibility work best when your account is connected.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (_error != null) ...[
                        _FeedbackBanner(message: _error!, isError: true),
                        const SizedBox(height: 14),
                      ],
                      if (_success != null) ...[
                        _FeedbackBanner(message: _success!, isError: false),
                        const SizedBox(height: 14),
                      ],
                      _Label('Email'),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration('you@example.com'),
                      ),
                      const SizedBox(height: 16),
                      _Label('Password'),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        onSubmitted: (_) => _signIn(),
                        decoration: _inputDecoration('••••••••').copyWith(
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _PrimaryButton(
                        label: 'Sign In',
                        loading: _loading,
                        onTap: _signIn,
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Expanded(child: Divider(color: Color(0xFFD1D5DB))),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'or',
                              style: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Color(0xFFD1D5DB))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SecondaryButton(
                        label: 'Create Account',
                        loading: _loading,
                        onTap: _signUp,
                      ),
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HomeScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Continue as Guest',
                          style: TextStyle(
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
    ),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF374151),
        ),
      ),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
    ),
  );
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: OutlinedButton(
      onPressed: loading ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1E293B),
        side: const BorderSide(color: Color(0xFF1E293B), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _FeedbackBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const _FeedbackBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isError ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isError ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
      ),
    ),
    child: Text(
      message,
      style: TextStyle(
        color: isError ? const Color(0xFFB91C1C) : const Color(0xFF047857),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
