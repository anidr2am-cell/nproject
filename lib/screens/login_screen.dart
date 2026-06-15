import 'dart:async';
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
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
    final unavailableMessage = _firebaseUnavailableMessage();
    if (unavailableMessage != null) {
      _showMessage(unavailableMessage);
      return;
    }

    setState(() => _isKakaoSubmitting = true);
    try {
      final kakao = js_util.getProperty(js_util.globalThis, 'Kakao');
      final auth = js_util.getProperty(kakao, 'Auth');

      final completer = Completer<String>();
      js_util.callMethod(auth, 'login', [
        js_util.jsify({
          'success': js.allowInterop((authObj) {
            final accessToken = js_util.getProperty(authObj, 'access_token');
            completer.complete(accessToken);
          }),
          'fail': js.allowInterop((err) {
            completer.completeError(err);
          }),
        })
      ]);

      final accessToken = await completer.future;
      final api = js_util.getProperty(kakao, 'API');
      final userCompleter = Completer<Map<String, dynamic>>();

      js_util.callMethod(api, 'request', [
        js_util.jsify({
          'url': '/v2/user/me',
          'success': js.allowInterop((response) {
            final id = js_util.getProperty(response, 'id');
            final properties = js_util.getProperty(response, 'properties');
            final nickname = js_util.getProperty(properties, 'nickname');
            userCompleter.complete({'id': id, 'nickname': nickname});
          }),
          'fail': js.allowInterop((err) {
            userCompleter.completeError(err);
          }),
        })
      ]);

      final userInfo = await userCompleter.future;
      final kakaoId = userInfo['id'].toString();
      final nickname = userInfo['nickname'] as String;
      final email = '$kakaoId@kakao.com';
      final password = 'kakao_$kakaoId';

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

      if (!mounted) return;
      _showMessage('카카오 로그인되었습니다.');
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('[LoginScreen] Kakao Login Error: $e');
      _showMessage('카카오 로그인에 실패했습니다.');
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
          _showMessage('援ш? 濡쒓렇?몃릺?덉뒿?덈떎.');
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
      _showMessage('援ш? 濡쒓렇?몃릺?덉뒿?덈떎.');
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      _showMessage(_firebaseMessage(e));
    } catch (e) {
      debugPrint('[LoginScreen] Google Sign-In Error: $e');
      _showMessage('援ш? 濡쒓렇?몄뿉 ?ㅽ뙣?덉뒿?덈떎.');
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
    if (value == null || value.trim().isEmpty) return '?꾩닔 ?낅젰 ??ぉ?낅땲??';
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
    return 'Firebase媛 ?꾩쭅 珥덇린?붾릺吏 ?딆븯?듬땲?? ?좎떆 ???ㅼ떆 ?쒕룄?댁＜?몄슂.';
  }

  String _firebaseMessage(FirebaseException error) {
    return switch (error.code) {
      'invalid-email' => '?대찓???뺤떇???щ컮瑜댁? ?딆뒿?덈떎.',
      'email-already-in-use' => '?대? 媛?낅맂 ?대찓?쇱엯?덈떎.',
      'weak-password' => '鍮꾨?踰덊샇媛 ?덈Т ?쏀빀?덈떎. 6?먮━ ?댁긽?쇰줈 ?낅젰?댁＜?몄슂.',
      'user-not-found' => '媛?낅릺吏 ?딆? ?대찓?쇱엯?덈떎.',
      'wrong-password' => '鍮꾨?踰덊샇媛 ?щ컮瑜댁? ?딆뒿?덈떎.',
      'invalid-credential' => '?대찓???먮뒗 鍮꾨?踰덊샇媛 ?щ컮瑜댁? ?딆뒿?덈떎.',
      'operation-not-allowed' => 'Firebase 肄섏넄?먯꽌 ?대찓??鍮꾨?踰덊샇 濡쒓렇?몄쓣 ?쒖꽦?뷀빐二쇱꽭??',
      'configuration-not-found' =>
        'Firebase Auth ?ㅼ젙??李얠쓣 ???놁뒿?덈떎. Firebase 肄섏넄 ?ㅼ젙???뺤씤?댁＜?몄슂.',
      'permission-denied' => 'Firestore 沅뚰븳???놁뒿?덈떎. 蹂댁븞 洹쒖튃???뺤씤?댁＜?몄슂.',
      'unavailable' => 'Firebase ?쒕쾭???곌껐?????놁뒿?덈떎. ?ㅽ듃?뚰겕 ?곹깭瑜??뺤씤?댁＜?몄슂.',
      'failed-precondition' => 'Firebase ?ㅼ젙???꾨즺?섏? ?딆븯?듬땲?? 肄섏넄 ?ㅼ젙???뺤씤?댁＜?몄슂.',
      'not-found' => 'Firebase ?꾨줈?앺듃 ?먮뒗 臾몄꽌瑜?李얠쓣 ???놁뒿?덈떎.',
      'missing-user' => '?뚯썝 ?뺣낫瑜??앹꽦?섏? 紐삵뻽?듬땲??',
      _ => error.message ?? 'Firebase ?ㅻ쪟媛 諛쒖깮?덉뒿?덈떎. (${error.code})',
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
      _showMessage('濡쒓렇???뺣낫瑜??낅젰?댁＜?몄슂.');
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
      _showMessage('濡쒓렇?몃릺?덉뒿?덈떎.');
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint('[LoginScreen] FirebaseAuth error: ${error.code}');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage(_firebaseMessage(error));
    } on TimeoutException catch (error, stackTrace) {
      debugPrint('[LoginScreen] timeout: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('濡쒓렇???붿껌 ?쒓컙??珥덇낵?섏뿀?듬땲??');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('濡쒓렇??/ ?뚯썝媛??)),
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
              decoration: const InputDecoration(hintText: '?꾩씠??),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              validator: _required,
              obscureText: true,
              decoration: const InputDecoration(hintText: '?⑥뒪?뚮뱶'),
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
                  : const Text('濡쒓렇??),
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
                child: const Text('?꾩쭅 怨꾩젙???녿굹?? ?뚯썝媛??),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('?먮뒗', style: TextStyle(color: _muted, fontSize: 13)),
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
              label: const Text('Google濡?怨꾩냽?섍린', style: TextStyle(color: _ink)),
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
