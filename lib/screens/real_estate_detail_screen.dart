import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/firebase_service.dart';
import 'chat_room_screen.dart';
import 'login_screen.dart';

class RealEstateDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;

  const RealEstateDetailScreen({
    required this.data,
    required this.docId,
    super.key,
  });

  @override
  State<RealEstateDetailScreen> createState() => _RealEstateDetailScreenState();
}

class _RealEstateDetailScreenState extends State<RealEstateDetailScreen> {
  int _imageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _getTimeAgo(dynamic createdAt) {
    if (createdAt == null) return '방금 전';
    DateTime? dateTime;
    if (createdAt is Timestamp) {
      dateTime = createdAt.toDate();
    } else if (createdAt is DateTime) {
      dateTime = createdAt;
    }
    if (dateTime == null) return '방금 전';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inHours < 1) return '방금 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  Future<void> _startChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    final sellerUid = widget.data['sellerUid'] as String?;
    if (sellerUid == null || sellerUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('판매자 정보가 없어 채팅을 시작할 수 없습니다.')),
      );
      return;
    }

    if (sellerUid == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('본인이 등록한 매물에는 메시지를 보낼 수 없습니다.')),
      );
      return;
    }

    try {
      final buyerNickname = await fetchNicknameForUid(user.uid, fallback: user.displayName ?? '익명');
      final sellerNickname = widget.data['sellerNickname'] ?? '익명';
      
      // Generate a unique roomId for this real estate item between this buyer and seller
      final roomId = 're_${widget.docId}_${user.uid}_$sellerUid';
      final photoUrls = widget.data['photoUrls'] as List?;
      final photoUrl = (photoUrls != null && photoUrls.isNotEmpty) ? photoUrls.first : '';

      await FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
        'listingId': widget.docId,
        'listingTitle': widget.data['title'],
        'listingPrice': widget.data['dealType'] == '월세' 
            ? '${widget.data['deposit']}/${widget.data['monthlyRent']}' 
            : widget.data['price'],
        'listingPhotoUrl': photoUrl,
        'listingType': 'realEstate', // 구분 필드 추가
        'buyerUid': user.uid,
        'buyerNickname': buyerNickname,
        'sellerUid': sellerUid,
        'sellerNickname': sellerNickname,
        'participantIds': [user.uid, sellerUid],
        'participantNames': {
          user.uid: buyerNickname,
          sellerUid: sellerNickname,
        },
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            chatRoomId: roomId,
            // Note: If ChatRoomScreen in main.dart is being used, 
            // the parameters might differ. Adjust as needed.
          ),
        ),
      );
    } catch (e) {
      debugPrint('[RealEstateDetail] Chat Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('채팅방을 열 수 없습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final photoUrls = data['photoUrls'] as List?;
    final hasPhotos = photoUrls != null && photoUrls.isNotEmpty;
    final photoCount = photoUrls?.length ?? 0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  if (hasPhotos)
                    PageView.builder(
                      controller: _pageController,
                      itemCount: photoCount,
                      onPageChanged: (v) => setState(() => _imageIndex = v),
                      itemBuilder: (context, index) {
                        return Image.network(photoUrls[index], fit: BoxFit.cover);
                      },
                    )
                  else
                    Container(
                      color: const Color(0xFFF5F5F5),
                      child: const Icon(Icons.home_work, size: 80, color: Colors.grey),
                    ),
                  if (photoCount > 1)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_imageIndex + 1} / $photoCount',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          data['propertyType'] ?? '',
                          style: const TextStyle(color: Color(0xFF1976D2), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getTimeAgo(data['createdAt']),
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data['title'] ?? '제목 없음',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data['dealType'] == '월세'
                        ? '월세 ${data['deposit'] ?? ''} / ${data['monthlyRent'] ?? ''} THB'
                        : '매매 ${data['price'] ?? ''} THB',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: brandOrange),
                  ),
                  const Divider(height: 40),
                  // 매물 정보 그리드
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 4,
                    children: [
                      _buildInfoItem(Icons.straighten, '면적', '${data['area'] ?? '-'} ㎡'),
                      _buildInfoItem(Icons.layers, '층수', '${data['floor'] ?? '-'} 층'),
                      _buildInfoItem(Icons.bed, '방', '${data['rooms'] ?? '-'} 개'),
                      _buildInfoItem(Icons.bathtub_outlined, '욕실', '${data['bathrooms'] ?? '-'} 개'),
                    ],
                  ),
                  const Divider(height: 40),
                  const Text('위치', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(data['address'] ?? '주소 정보 없음', style: const TextStyle(fontSize: 15)),
                  const Divider(height: 40),
                  const Text('상세 설명', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Text(
                    data['description'] ?? '',
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFEEEEEE),
                        child: Icon(Icons.person, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['sellerNickname'] ?? '익명', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const Text('등록자', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _startChat,
                  style: FilledButton.styleFrom(
                    backgroundColor: brandOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('채팅하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
