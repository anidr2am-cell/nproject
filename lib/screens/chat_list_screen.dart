import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/colors.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({required this.onOpenRoom, super.key});

  final void Function(BuildContext context, ChatRoomListItem room) onOpenRoom;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('채팅')),
      body: user == null
          ? const _ChatEmptyState(text: '로그인 후 채팅을 확인할 수 있습니다.')
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chatRooms')
                  .where('participantIds', arrayContains: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  debugPrint('[ChatListScreen] ${snapshot.error}');
                  return const _ChatEmptyState(text: '채팅 목록을 불러오지 못했습니다.');
                }

                final rooms = snapshot.data?.docs.toList() ?? [];
                rooms.sort((a, b) {
                  final aTime = _timestampMillis(
                    a.data()['lastMessageAt'] ?? a.data()['updatedAt'],
                  );
                  final bTime = _timestampMillis(
                    b.data()['lastMessageAt'] ?? b.data()['updatedAt'],
                  );
                  return bTime.compareTo(aTime);
                });

                if (rooms.isEmpty) {
                  return const _ChatEmptyState(text: '진행 중인 채팅이 없습니다');
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: rooms.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final room = ChatRoomListItem.fromDoc(
                      rooms[index],
                      currentUid: user.uid,
                    );
                    return _ChatRoomListTile(
                      room: room,
                      currentUid: user.uid,
                      onTap: () => onOpenRoom(context, room),
                    );
                  },
                );
              },
            ),
    );
  }
}

class ChatRoomListItem {
  const ChatRoomListItem({
    required this.id,
    required this.otherUserName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.listingTitle,
    required this.photoUrl,
  });

  final String id;
  final String otherUserName;
  final String lastMessage;
  final Object? lastMessageTime;
  final String listingTitle;
  final String photoUrl;

  factory ChatRoomListItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required String currentUid,
  }) {
    final data = doc.data();
    final sellerUid = _stringValue(data['sellerUid'], '');
    final sellerName = _stringValue(data['sellerNickname'], '판매자');
    final buyerName = _stringValue(data['buyerNickname'], '구매자');
    return ChatRoomListItem(
      id: doc.id,
      otherUserName: currentUid == sellerUid ? buyerName : sellerName,
      lastMessage: _stringValue(data['lastMessage'], '아직 메시지가 없습니다.'),
      lastMessageTime: data['lastMessageAt'] ?? data['updatedAt'],
      listingTitle: _stringValue(data['listingTitle'], ''),
      photoUrl: _stringValue(data['listingPhotoUrl'], ''),
    );
  }
}

class _ChatRoomListTile extends StatelessWidget {
  const _ChatRoomListTile({
    required this.room,
    required this.currentUid,
    required this.onTap,
  });

  final ChatRoomListItem room;
  final String currentUid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: brandBorder),
          ),
          child: Row(
            children: [
              _RoomThumb(photoUrl: room.photoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            room.otherUserName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: brandPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeAgo(room.lastMessageTime),
                          style: const TextStyle(
                            color: brandMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (room.listingTitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        room.listingTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: brandSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      room.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: brandMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _UnreadBadge(roomId: room.id, currentUid: currentUid),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomThumb extends StatelessWidget {
  const _RoomThumb({required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: brandBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: photoUrl.isEmpty
          ? const Icon(Icons.chat_bubble_outline, color: brandMuted)
          : ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.chat_bubble_outline, color: brandMuted),
              ),
            ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.roomId, required this.currentUid});

  final String roomId;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(roomId)
          .collection('messages')
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data();
          final senderUid = _stringValue(data['senderUid'], '');
          final readBy = _stringListValue(data['readBy']);
          return senderUid.isNotEmpty &&
              senderUid != currentUid &&
              !readBy.contains(currentUid);
        }).length;

        if (unreadCount == 0) {
          return const Icon(Icons.chevron_right, color: brandMuted, size: 20);
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: const BoxDecoration(
                color: brandSecondary,
                shape: BoxShape.circle,
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: brandMuted, size: 20),
          ],
        );
      },
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: brandMuted, fontSize: 15),
        ),
      ),
    );
  }
}

String _stringValue(Object? value, String fallback) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

List<String> _stringListValue(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

int _timestampMillis(Object? value) {
  if (value is Timestamp) return value.millisecondsSinceEpoch;
  if (value is DateTime) return value.millisecondsSinceEpoch;
  return 0;
}

String _timeAgo(Object? value) {
  final millis = _timestampMillis(value);
  if (millis == 0) return '';

  final diff = DateTime.now().difference(
    DateTime.fromMillisecondsSinceEpoch(millis),
  );
  if (diff.inMinutes < 1) return '방금전';
  if (diff.inHours < 1) return '${diff.inMinutes}분전';
  if (diff.inDays < 1) return '${diff.inHours}시간전';
  return '${diff.inDays}일전';
}
