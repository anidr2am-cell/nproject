import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/colors.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';

class PostListingScreen extends StatefulWidget {
  const PostListingScreen({super.key});

  @override
  State<PostListingScreen> createState() => _PostListingScreenState();
}

class _PostListingScreenState extends State<PostListingScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authStateStream(),
      builder: (context, snapshot) {
        if (snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('중고거래 글쓰기')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.edit_note, size: 80, color: muted),
                  const SizedBox(height: 16),
                  const Text('로그인 후 이용 가능합니다.', style: TextStyle(fontSize: 16, color: muted)),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    style: FilledButton.styleFrom(backgroundColor: brandOrange),
                    child: const Text('로그인하러 가기'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('중고거래 글쓰기'),
            actions: [
              TextButton(
                onPressed: () {
                  // TODO: 게시물 등록 로직
                },
                child: const Text('완료', style: TextStyle(color: brandOrange, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          body: const Center(
            child: Text('여기에 게시글 작성 폼이 들어갈 예정입니다.'),
          ),
        );
      },
    );
  }
}
