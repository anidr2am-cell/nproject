import 'dart:async';
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao_sdk;
import 'auth_screen.dart';

const _brandOrange = Color(0xFFFF6F0F);
const _ink = Color(0xFF222222);
const _muted = Color(0xFF767676);
const _surface = Color(0xFFF7F8FA);
const _firebaseRequestTimeout = Duration(seconds: 15);

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
  bool _isKakaoSubmitting = false;

  Future<void> _signInWithKakao() async {
    print('[KAKAO] login start');
    final unavailableMessage = _firebaseUnavailableMessage();
    if (unavailableMessage != null) {
      _showMessage(unavailableMessage);
      return;
    }

    setState(() => _isKakaoSubmitting = true);
    try {
      if (kIsWeb) {
        print('[KAKAO] initiating redirect login (web)');
        try {
          await kakao_sdk.UserApi.instance.loginWithKakaoAccount();
          print('[KAKAO] authorization request sent');
          return; // 리다이렉트 시 페이지가 이동하므로 이후 코드는 실행되지 않음
        } catch (error) {
          print('[KAKAO] exception=$error');
          debugPrint('웹 카카오 로그인 리다이렉트 요청 실패: $error');
          _showMessage('카카오 리다이렉트 로그인 실패');
          return;
        }
      }

      kakao_sdk.OAuthToken token;
      if (!kIsWeb && await kakao_sdk.isKakaoTalkInstalled()) {
        try {
          token = await kakao_sdk.UserApi.instance.loginWithKakaoTalk();
        } catch (error) {
          debugPrint('카카오톡 로그인 실패, 계정 로그인 시도: $error');
          token = await kakao_sdk.UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        token = await kakao_sdk.UserApi.instance.loginWithKakaoAccount();
      }

      print('[KAKAO] token received');
      final user = await kakao_sdk.UserApi.instance.me();
      print('[KAKAO] authorization success');
      final kakaoId = user.id.toString();
      final nickname = user.kakaoAccount?.profile?.nickname ?? '카카오 사용자';
      
      final email = '$kakaoId@kakao.com';
      final password = 'kakao_$kakaoId';

      print('[KAKAO] firebase credential created');
      print('[KAKAO] starting firebase login');
      UserCredential userCredential;
      try {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        ).timeout(_firebaseRequestTimeout);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          ).timeout(_firebaseRequestTimeout);
          await userCredential.user?.updateDisplayName(nickname);
        } else {
          rethrow;
        }
      }

      print('[KAKAO] firebase login success');
      if (!mounted) return;
      _showMessage('카카오 로그인되었습니다.');
      Navigator.of(context).pop();
    } catch (e) {
      print('[KAKAO] exception=$e');
      debugPrint('[LoginScreen] Kakao Login Error: $e');
      _showMessage('카카오 로그인에 실패했습니다. ($e)');
    } finally {
      if (mounted) setState(() => _isKakaoSubmitting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      FirebaseAuth.instance.getRedirectResult().then((result) {
        if (result.user != null && mounted) {
          _showMessage('구글 로그인되었습니다.');
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      }).catchError((e) {
        debugPrint('[LoginScreen] Redirect result error: $e');
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    final unavailableMessage = _firebaseUnavailableMessage();
    if (unavailableMessage != null) {
      _showMessage(unavailableMessage);
      return;
    }
    setState(() => _isGoogleSubmitting = true);
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithRedirect(GoogleAuthProvider());
        return;
      }

      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isGoogleSubmitting = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      _showMessage('구글 로그인되었습니다.');
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      _showMessage(_firebaseMessage(e));
    } catch (e) {
      debugPrint('[LoginScreen] Google Sign-In Error: $e');
      _showMessage('구글 로그인에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _firebaseUnavailableMessage() {
    if (Firebase.apps.isNotEmpty) return null;
    return 'Firebase가 아직 초기화되지 않았습니다. 잠시 후 다시 시도해주세요.';
  }

  String _firebaseMessage(FirebaseException error) {
    return switch (error.code) {
      'invalid-email' => '이메일 형식이 올바르지 않습니다.',
      'email-already-in-use' => '이미 가입된 이메일입니다.',
      'weak-password' => '비밀번호가 너무 약합니다. 6자리 이상으로 입력해주세요.',
      'user-not-found' => '가입되지 않은 이메일입니다.',
      'wrong-password' => '비밀번호가 올바르지 않습니다.',
      'invalid-credential' => '이메일 또는 비밀번호가 올바르지 않습니다.',
      'operation-not-allowed' => 'Firebase 콘솔에서 이메일/비밀번호 로그인을 활성화해주세요.',
      'configuration-not-found' =>
        'Firebase Auth 설정을 찾을 수 없습니다. Firebase 콘솔 설정을 확인해주세요.',
      'permission-denied' => 'Firestore 권한이 없습니다. 보안 규칙을 확인해주세요.',
      'unavailable' => 'Firebase 서버에 연결할 수 없습니다. 네트워크 상태를 확인해주세요.',
      'failed-precondition' => 'Firebase 설정이 완료되지 않았습니다. 콘솔 설정을 확인해주세요.',
      'not-found' => 'Firebase 프로젝트 또는 문서를 찾을 수 없습니다.',
      'missing-user' => '회원 정보를 생성하지 못했습니다.',
      _ => error.message ?? 'Firebase 오류가 발생했습니다. (${error.code})',
    };
  }

  Future<void> _submitLogin() async {
    debugPrint('[LoginScreen] login button tapped');
    FocusScope.of(context).unfocus();

    final unavailableMessage = _firebaseUnavailableMessage();
    if (unavailableMessage != null) {
      _showMessage(unavailableMessage);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showMessage('로그인 정보를 입력해주세요.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          )
          .timeout(_firebaseRequestTimeout);
      if (!mounted) return;
      _showMessage('로그인되었습니다.');
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint('[LoginScreen] FirebaseAuth error: ${error.code}');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage(_firebaseMessage(error));
    } on TimeoutException catch (error, stackTrace) {
      debugPrint('[LoginScreen] timeout: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('로그인 요청 시간이 초과되었습니다.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  'assets/images/login.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              validator: _required,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: '이메일'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              validator: _required,
              obscureText: true,
              decoration: const InputDecoration(hintText: '비밀번호'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _isSubmitting ? null : _submitLogin,
              style: FilledButton.styleFrom(
                backgroundColor: _brandOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('로그인'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AuthScreen())),
                style: TextButton.styleFrom(
                  foregroundColor: _ink,
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: const Text('아직 계정이 없나요? 회원가입'),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('또는', style: TextStyle(color: _muted, fontSize: 13)),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isGoogleSubmitting ? null : _signInWithGoogle,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFFDDDDDD)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              icon: _isGoogleSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : SvgPicture.asset(
                      'assets/images/google.svg',
                      width: 20,
                      height: 20,
                    ),
              label: const Text('Google로 계속하기', style: TextStyle(color: _ink)),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isKakaoSubmitting ? null : _signInWithKakao,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFEE500),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                side: BorderSide.none,
              ),
              icon: _isKakaoSubmitting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.chat, size: 20),
              label: const Text('카카오로 시작하기', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
