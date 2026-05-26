import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPass = TextEditingController();
  final _regName = TextEditingController();
  bool _loading = false;
  bool _obscureLogin = true;
  bool _obscureReg = true;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _loginEmail.dispose();
    _loginPass.dispose();
    _regEmail.dispose();
    _regPass.dispose();
    _regName.dispose();
    super.dispose();
  }

  void _showError(String msg) => setState(() { _error = msg; _success = null; });
  void _showSuccess(String msg) => setState(() { _success = msg; _error = null; });

  Future<void> _login() async {
    if (_loginEmail.text.isEmpty || _loginPass.text.isEmpty) {
      _showError('Please enter email and password');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _loginEmail.text.trim(),
        password: _loginPass.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (_regEmail.text.isEmpty || _regPass.text.isEmpty || _regName.text.isEmpty) {
      _showError('Please fill all fields');
      return;
    }
    if (_regPass.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signUp(
        email: _regEmail.text.trim(),
        password: _regPass.text.trim(),
        data: {'full_name': _regName.text.trim()},
      );
      _showSuccess('Account created! Sign in to continue.');
      _tab.animateTo(0);
    } on AuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 32),
              // Header logo matching your HTML header style
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF334155), Color(0xFF0F172A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('SAFEROUTE', style: TextStyle(fontSize: 9, color: Color(0xFF6B7280), letterSpacing: 3, fontWeight: FontWeight.w700)),
                      Text('Your Safety Partner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Feedback messages
              if (_error != null)
                _FeedbackBanner(message: _error!, isError: true),
              if (_success != null)
                _FeedbackBanner(message: _success!, isError: false),

              // Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    // Tab bar matching slate-800 active style
                    Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tab,
                        indicator: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: Colors.white,
                        unselectedLabelColor: const Color(0xFF6B7280),
                        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        dividerColor: Colors.transparent,
                        tabs: const [Tab(text: 'Sign In'), Tab(text: 'Create Account')],
                      ),
                    ),

                    SizedBox(
                      height: 320,
                      child: TabBarView(
                        controller: _tab,
                        children: [
                          // Login Tab
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Label('Email'),
                                TextField(
                                  controller: _loginEmail,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: _inputDec('you@example.com', Icons.email_outlined),
                                ),
                                const SizedBox(height: 14),
                                _Label('Password'),
                                TextField(
                                  controller: _loginPass,
                                  obscureText: _obscureLogin,
                                  onSubmitted: (_) => _login(),
                                  decoration: _inputDec('••••••••', Icons.lock_outline).copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscureLogin ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF9CA3AF), size: 20),
                                      onPressed: () => setState(() => _obscureLogin = !_obscureLogin),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                _ActionButton(label: 'Sign In', loading: _loading, onTap: _login),
                              ],
                            ),
                          ),
                          // Register Tab
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Label('Full Name'),
                                TextField(
                                  controller: _regName,
                                  decoration: _inputDec('Your name', Icons.person_outline),
                                ),
                                const SizedBox(height: 12),
                                _Label('Email'),
                                TextField(
                                  controller: _regEmail,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: _inputDec('you@example.com', Icons.email_outlined),
                                ),
                                const SizedBox(height: 12),
                                _Label('Password'),
                                TextField(
                                  controller: _regPass,
                                  obscureText: _obscureReg,
                                  decoration: _inputDec('Min. 6 characters', Icons.lock_outline).copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscureReg ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF9CA3AF), size: 20),
                                      onPressed: () => setState(() => _obscureReg = !_obscureReg),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                _ActionButton(label: 'Create Account', loading: _loading, onTap: _register),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 2)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 2)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E293B), width: 2)),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5)),
  );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 48,
    child: ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
          : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    ),
  );
}

class _FeedbackBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const _FeedbackBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isError ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: isError ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7)),
    ),
    child: Row(children: [
      Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
          color: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981), size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: TextStyle(color: isError ? const Color(0xFFB91C1C) : const Color(0xFF065F46), fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );
}
