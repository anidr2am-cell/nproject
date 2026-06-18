import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'chat_room_screen.dart';
import 'real_estate_write_screen.dart';

class RealEstateDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const RealEstateDetailScreen({required this.docId, required this.data, super.key});

  @override
  State<RealEstateDetailScreen> createState() => _RealEstateDetailScreenState();
}

class _RealEstateDetailScreenState extends State<RealEstateDetailScreen> {
  int _imageIndex = 0;
  final PageController _pageController = PageController();

  bool get _isOwner {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && user.uid == widget.data['sellerUid'];
  }

  Future<void> _deleteListing() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('매물 삭제'),
        content: const Text('정말로 이 매물을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 1. Storage에서 사진 삭제
      final photoUrls = widget.data['photoUrls'] as List?;
      if (photoUrls != null && photoUrls.isNotEmpty) {
        for (var url in photoUrls) {
          try {
            await FirebaseStorage.instance.refFromURL(url).delete();
          } catch (e) {
            debugPrint('Error deleting photo from storage: $e');
          }
        }
      }

      // 2. Firestore에서 문서 삭제
      await FirebaseFirestore.instance.collection('realEstate').doc(widget.docId).delete();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('매물이 삭제되었습니다.')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting listing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _editListing() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RealEstateWriteScreen(
          docId: widget.docId,
          initialData: widget.data,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photoUrls = widget.data['photoUrls'] as List?;
    final imageCount = photoUrls?.length ?? 0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: imageCount > 0
                  ? Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: imageCount,
                          onPageChanged: (v) => setState(() => _imageIndex = v),
                          itemBuilder: (context, index) {
                            return Image.network(photoUrls![index], fit: BoxFit.cover);
                          },
                        ),
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_imageIndex + 1} / $imageCount',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: const Color(0xFFF5F5F5),
                      child: const Icon(Icons.home_work, size: 80, color: Colors.grey),
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
                          color: brandOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.data['propertyType'] ?? '',
                          style: const TextStyle(color: brandOrange, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.data['dealType'] ?? '',
                        style: const TextStyle(color: muted, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.data['title'] ?? '제목 없음',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.data['dealType'] == '월세'
                        ? '보증금 ${widget.data['deposit'] ?? ''} / 월세 ${widget.data['monthlyRent'] ?? ''}'
                        : '매매가 ${widget.data['price'] ?? ''}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: brandOrange),
                  ),
                  const Divider(height: 40),
                  _buildDetailRow('주소', widget.data['address'] ?? ''),
                  _buildDetailRow('면적', '${widget.data['area'] ?? '-'} ㎡'),
                  _buildDetailRow('층수', '${widget.data['floor'] ?? '-'} 층'),
                  _buildDetailRow('방/욕실', '${widget.data['rooms'] ?? '-'}개 / ${widget.data['bathrooms'] ?? '-'}개'),
                  const Divider(height: 40),
                  const Text('상세 설명', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    widget.data['description'] ?? '',
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFEDEDED))),
          ),
          child: _isOwner
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _editListing,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ink,
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('수정'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _deleteListing,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('삭제'),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.data['sellerNickname'] ?? '익명',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Text('중개인/등록자', style: TextStyle(color: muted, fontSize: 12)),
                      ],
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatRoomScreen(chatRoomId: widget.docId),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: brandOrange,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: const Text('채팅하기'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: muted, fontSize: 15)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
