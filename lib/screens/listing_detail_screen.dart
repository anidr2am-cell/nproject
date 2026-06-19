import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import '../models/market_listing.dart';
import '../models/listing_type.dart';
import '../services/firebase_service.dart';
import '../utils/price_formatter.dart';
import '../widgets/common_widgets.dart';
import 'chat_room_screen.dart';
import 'login_screen.dart';

class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({required this.listing, super.key});

  final MarketListing listing;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  int _imageIndex = 0;
  final PageController _pageController = PageController();
  late MarketListing _listing;

  @override
  void initState() {
    super.initState();
    _listing = widget.listing;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isOwner {
    final user = currentUserOrNull();
    return user != null && _listing.sellerUid == user.uid;
  }

  Future<void> _deleteListing() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('물품 삭제'),
        content: const Text('정말로 이 게시글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
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
      if (_listing.photoUrls.isNotEmpty) {
        for (var url in _listing.photoUrls) {
          try {
            await FirebaseStorage.instance.refFromURL(url).delete();
          } catch (e) {
            debugPrint('Error deleting photo: $e');
          }
        }
      }

      // 2. Firestore에서 삭제
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(_listing.id)
          .delete();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('게시글이 삭제되었습니다.')));
      }
    } catch (e) {
      debugPrint('Error deleting listing: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e')));
      }
    }
  }

  void _editListing() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostListingScreen(
          editingListingId: _listing.id,
          initialListing: _listing,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageCount = _listing.photoUrls.isNotEmpty
        ? _listing.photoUrls.length
        : _listing.photoCount;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 330,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: PageView.builder(
                controller: _pageController,
                itemCount: imageCount,
                onPageChanged: (v) => setState(() => _imageIndex = v),
                itemBuilder: (context, index) {
                  if (_listing.photoUrls.isNotEmpty) {
                    return Image.network(
                      _listing.photoUrls[index],
                      fit: BoxFit.cover,
                    );
                  }
                  return Container(
                    color: _listing.color,
                    child: Icon(_listing.icon, size: 80, color: Colors.white),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _listing.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: brandPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_listing.category} · ${_listing.postedAgo}',
                    style: const TextStyle(color: brandMuted),
                  ),
                  const Divider(height: 32),
                  Text(
                    _listing.description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  TradeLocationText(
                    value: formatPrice(_listing.price),
                    label: '가격',
                  ),
                  const SizedBox(height: 12),
                  TradeLocationText(value: _listing.place, label: '거래 장소'),
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
            border: Border(top: BorderSide(color: brandBorder)),
          ),
          child: _isOwner
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _editListing,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ink,
                        side: const BorderSide(color: brandBorder),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('수정'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _deleteListing,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
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
                          _listing.sellerNickname,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Text(
                          '판매자',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ChatRoomScreen(chatRoomId: _listing.id),
                        ),
                      ),
                      child: const Text('채팅하기'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
