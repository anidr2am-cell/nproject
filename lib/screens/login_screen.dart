import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/colors.dart';
import '../services/firebase_service.dart';
import 'auth_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return '필수 입력 항목입니다.';
    return null;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();
    final unavailable = firebaseUnavailableMessage();
    if (unavailable != null) {
      _showMessage(unavailable);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      ).timeout(firebaseRequestTimeout);
      if (!mounted) return;
      _showMessage('로그인되었습니다.');
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      _showMessage(firebaseMessage(e));
    } catch (e) {
      debugPrint('[Auth] Email Login Error: $e');
      _showMessage('로그인 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    final unavailable = firebaseUnavailableMessage();
    if (unavailable != null) {
      _showMessage(unavailable);
      return;
    }

    setState(() => _isGoogleSubmitting = true);
    try {
      final credential = await signInWithGoogle();
      if (credential != null && mounted) {
        _showMessage('Google 계정으로 로그인되었습니다.');
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(firebaseMessage(e));
    } catch (e) {
      debugPrint('[Auth] Google Login Error: $e');
      _showMessage('Google 로그인 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인 / 회원가입')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Image.asset(
                      'assets/images/login_bg.png',
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.1),
                            Colors.black.withOpacity(0.4),
                          ],
                        ),
                      ),
                    ),
                    const Center(
                      child: Text(
                        'Nproject',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _emailController,
              validator: _required,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: '아이디(이메일)',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              validator: _required,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: '패스워드',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _isSubmitting || _isGoogleSubmitting ? null : _submitLogin,
                style: FilledButton.styleFrom(
                  backgroundColor: brandOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('로그인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: _isSubmitting || _isGoogleSubmitting ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isGoogleSubmitting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset('assets/images/google.svg', width: 20, height: 20),
                          const SizedBox(width: 12),
                          const Text('Google로 계속하기', style: TextStyle(color: ink, fontSize: 16)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen())),
                child: const Text('아직 계정이 없나요? 회원가입', style: TextStyle(color: muted)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
