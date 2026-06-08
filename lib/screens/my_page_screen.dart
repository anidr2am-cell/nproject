import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/colors.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authStateStream(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('나의 정보')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_outline, size: 80, color: muted),
                  const SizedBox(height: 16),
                  const Text('로그인이 필요합니다.', style: TextStyle(fontSize: 16, color: muted)),
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
            title: const Text('나의 정보'),
            actions: [
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: ListView(
            children: [
              _buildProfileHeader(user),
              const Divider(height: 1, color: surface),
              _buildActionList(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(User user) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: surface,
            backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
            child: user.photoURL == null ? const Icon(Icons.person, size: 40, color: muted) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName ?? '사용자',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  user.email ?? '',
                  style: const TextStyle(color: muted, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionList(BuildContext context) {
    return Column(
      children: [
        _buildListTile(Icons.favorite_border, '관심목록', () {}),
        _buildListTile(Icons.receipt_long_outlined, '판매내역', () {}),
        _buildListTile(Icons.shopping_bag_outlined, '구매내역', () {}),
        const Divider(height: 1, color: surface),
        _buildListTile(Icons.logout, '로그아웃', () async {
          await signOut();
        }, textColor: Colors.red),
      ],
    );
  }

  Widget _buildListTile(IconData icon, String title, VoidCallback onTap, {Color? textColor}) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? ink),
      title: Text(title, style: TextStyle(color: textColor ?? ink, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, color: muted),
      onTap: onTap,
    );
  }
}
