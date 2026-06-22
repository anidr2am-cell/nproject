import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/categories.dart';
import '../models/listing_type.dart';
import '../models/market_listing.dart';
import '../constants/sample_data.dart';
import '../services/firebase_service.dart';
import '../widgets/listing_tile.dart';
import '../widgets/common_widgets.dart';
import 'listing_detail_screen.dart';
import 'settings_screen.dart';
import 'notifications_screen.dart';
import 'login_screen.dart';
import 'real_estate_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.onWrite, super.key});

  final VoidCallback onWrite;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showOnlyActive = false;
  String? _selectedCategory;
  ListingType? _selectedType;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '물품명을 입력하세요',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : StreamBuilder<User?>(
                stream: authStateStream(),
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  if (user == null) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: ink,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          textStyle: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('로그인'),
                      ),
                    );
                  }

                  final name = user.displayName?.trim().isNotEmpty == true
                      ? user.displayName!.trim()
                      : '하늘상점';
                  return Text('$name님');
                },
              ),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                });
              },
            )
          else
            IconButton(
              tooltip: '검색',
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
              icon: const Icon(Icons.search),
            ),
          const NotificationIconButton(),
          IconButton(
            tooltip: '설정',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  QuickActionPanel(
                    selectedType: _selectedType,
                    onTypeSelected: (type) => setState(() {
                      _selectedType = _selectedType == type ? null : type;
                    }),
                    onWrite: widget.onWrite,
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(categories.length, (index) {
                      final category = categories[index];
                      final isAll = index == 0;
                      final isSelected = isAll
                          ? _selectedCategory == null
                          : _selectedCategory == category;
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: FilterChip(
                          selected: isSelected,
                          showCheckmark: false,
                          selectedColor: brandPrimary,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          labelPadding: EdgeInsets.zero,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (isAll) ...[
                                Icon(
                                  Icons.grid_view,
                                  size: 18,
                                  color: isSelected ? Colors.white : brandInk,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  category,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : null,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = isAll ? null : category;
                            });
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: _showOnlyActive,
                        activeColor: brandOrange,
                        onChanged: (value) =>
                            setState(() => _showOnlyActive = value ?? false),
                      ),
                      const Text('판매중인 물품만 보기'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: firebaseUnavailableMessage() == null
                ? FirebaseFirestore.instance
                      .collection('listings')
                      .orderBy('createdAt', descending: true)
                      .snapshots()
                : null,
            builder: (context, snapshot) {
              final firestoreListings = snapshot.hasData
                  ? snapshot.data!.docs
                        .map((doc) => listingFromDoc(doc))
                        .toList()
                  : <MarketListing>[];
              final allListings = firestoreListings;
              var listings = _showOnlyActive
                  ? allListings.where((l) => l.status == 'active').toList()
                  : allListings;
              if (_selectedCategory != null) {
                listings = listings
                    .where((l) => l.category == _selectedCategory)
                    .toList();
              }
              if (_selectedType != null) {
                listings = listings
                    .where((l) => l.type == _selectedType)
                    .toList();
              }
              if (_searchQuery.trim().isNotEmpty) {
                listings = listings
                    .where(
                      (l) => l.title.toLowerCase().contains(
                        _searchQuery.trim().toLowerCase(),
                      ),
                    )
                    .toList();
              }

              return SliverMainAxisGroup(
                slivers: [
                  if (snapshot.hasError)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: NoticeBox(
                          icon: Icons.info_outline,
                          text: '등록된 글을 불러오지 못했습니다. Firestore 읽기 권한을 확인해주세요.',
                        ),
                      ),
                    ),
                  SliverList.separated(
                    itemCount: listings.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 112,
                      endIndent: 20,
                      color: brandBorder,
                    ),
                    itemBuilder: (context, index) {
                      final listing = listings[index];
                      return ListingTile(
                        listing: listing,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ListingDetailScreen(listing: listing),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: brandOrange,
        foregroundColor: Colors.white,
        onPressed: widget.onWrite,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('글쓰기'),
      ),
    );
  }
}

class QuickActionPanel extends StatelessWidget {
  const QuickActionPanel({
    required this.onWrite,
    required this.selectedType,
    required this.onTypeSelected,
    super.key,
  });

  final VoidCallback onWrite;
  final ListingType? selectedType;
  final ValueChanged<ListingType> onTypeSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: QuickAction(
              icon: Icons.shopping_bag_outlined,
              title: '중고거래',
              subtitle: '물건 팔기',
              isSelected: selectedType == ListingType.used,
              onTap: () => onTypeSelected(ListingType.used),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: QuickAction(
              icon: Icons.flight_takeoff,
              title: '해주세요',
              subtitle: '배송 부탁',
              isSelected: selectedType == ListingType.request,
              onTap: () => onTypeSelected(ListingType.request),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: QuickAction(
              icon: Icons.currency_exchange,
              title: '화폐 교환',
              subtitle: '소액 교환',
              isSelected: selectedType == ListingType.currency,
              onTap: () => onTypeSelected(ListingType.currency),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: QuickAction(
              icon: Icons.home_work,
              title: '부동산',
              subtitle: '매매/월세',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RealEstateScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QuickAction extends StatelessWidget {
  const QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isSelected = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? brandOrange : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : brandOrange,
                size: 26,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white70 : muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationIconButton extends StatelessWidget {
  const NotificationIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authStateStream(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null || firebaseUnavailableMessage() != null) {
          return IconButton(
            tooltip: '알림',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
            icon: const Icon(Icons.notifications_none),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('notifications')
              .where('isRead', isEqualTo: false)
              .snapshots(),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data?.docs.length ?? 0;
            return IconButton(
              tooltip: unreadCount > 0 ? '알림 $unreadCount개' : '알림',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
              icon: NotificationBadge(count: unreadCount),
            );
          },
        );
      },
    );
  }
}

class NotificationBadge extends StatelessWidget {
  const NotificationBadge({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none),
        if (count > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
