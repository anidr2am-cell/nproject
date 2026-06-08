import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import '../models/market_listing.dart';
import '../models/listing_type.dart';
import '../services/firebase_service.dart';
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
  late String _saleStatus;

  @override
  void initState() {
    super.initState();
    _listing = widget.listing;
    _saleStatus = widget.listing.status;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageCount = _listing.photoUrls.isNotEmpty ? _listing.photoUrls.length : _listing.photoCount;
    final isOwner = currentUserOrNull()?.uid == _listing.sellerUid;

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
                    return Image.network(_listing.photoUrls[index], fit: BoxFit.cover);
                  }
                  return Container(color: _listing.color, child: Icon(_listing.icon, size: 80, color: Colors.white));
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
                  Text(_listing.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${_listing.category} · ${_listing.postedAgo}', style: const TextStyle(color: muted)),
                  const Divider(height: 32),
                  Text(_listing.description, style: const TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(height: 20),
                  TradeLocationText(value: _listing.price, label: '가격'),
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
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEDEDED)))),
          child: Row(
            children: [
              const Spacer(),
              FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(backgroundColor: brandOrange),
                child: const Text('채팅하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
