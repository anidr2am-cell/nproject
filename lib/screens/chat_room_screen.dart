import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';

class ChatRoomScreen extends StatelessWidget {
  const ChatRoomScreen({required this.chatRoomId, super.key});

  final String chatRoomId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅'),
        actions: [
          IconButton(
            tooltip: '나가기',
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await deleteChatNotifications(user.uid, chatRoomId);
              }
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            icon: const Icon(Icons.exit_to_app),
          ),
        ],
      ),
      body: const Center(child: Text('채팅 메시지창')),
    );
  }
}
