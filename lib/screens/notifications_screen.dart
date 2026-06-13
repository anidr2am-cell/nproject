import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../constants/colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('알림')),
        body: const Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('알림이 없습니다.', style: TextStyle(color: muted)),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: surface),
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data();
              final notificationId = doc.id;

              return ListTile(
                title: Text(data['title'] ?? '알림', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(data['body'] ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 20, color: muted),
                  onPressed: () async {
                    await deleteNotification(user.uid, notificationId);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
