import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';
import 'package:image_picker/image_picker.dart';

const _firebaseRequestTimeout = Duration(seconds: 15);
bool _firebaseReady = false;
String? _firebaseInitMessage;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseReady = Firebase.apps.isNotEmpty;
    _firebaseInitMessage = null;
    debugPrint('[Firebase] initializeApp success');
  } on FirebaseException catch (error, stackTrace) {
    _firebaseReady = false;
    _firebaseInitMessage = _firebaseMessage(error);
    debugPrint(
      '[Firebase] initializeApp failed: ${error.code} ${error.message}',
    );
    debugPrintStack(stackTrace: stackTrace);
  } catch (error, stackTrace) {
    _firebaseReady = false;
    _firebaseInitMessage = 'Firebase 초기화에 실패했습니다. 설정 파일과 프로젝트 연결을 확인해주세요.';
    debugPrint('[Firebase] initializeApp unknown error: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const NprojectApp());
}

String? _firebaseUnavailableMessage() {
  if (_firebaseReady && Firebase.apps.isNotEmpty) return null;
  return _firebaseInitMessage ?? 'Firebase가 아직 초기화되지 않았습니다. 잠시 후 다시 시도해주세요.';
}

Stream<User?> _authStateStream() {
  if (_firebaseUnavailableMessage() != null) return Stream<User?>.value(null);
  return FirebaseAuth.instance.authStateChanges();
}

User? _currentUserOrNull() {
  if (_firebaseUnavailableMessage() != null) return null;
  return FirebaseAuth.instance.currentUser;
}

String _firebaseMessage(FirebaseException error) {
  return switch (error.code) {
    'invalid-email' => '이메일 형식이 올바르지 않습니다.',
    'email-already-in-use' => '이미 가입된 이메일입니다.',
    'weak-password' => '비밀번호가 너무 약합니다. 6자리 이상으로 입력해주세요.',
    'user-not-found' => '가입되지 않은 이메일입니다.',
    'wrong-password' => '비밀번호가 올바르지 않습니다.',
    'invalid-credential' => '이메일 또는 비밀번호가 올바르지 않습니다.',
    'operation-not-allowed' => 'Firebase 콘솔에서 이메일/비밀번호 로그인을 활성화해주세요.',
    'configuration-not-found' =>
      'Firebase Auth 설정을 찾을 수 없습니다. Firebase 콘솔 설정을 확인해주세요.',
    'permission-denied' => 'Firestore 권한이 없습니다. 보안 규칙을 확인해주세요.',
    'unavailable' => 'Firebase 서버에 연결할 수 없습니다. 네트워크 상태를 확인해주세요.',
    'failed-precondition' => 'Firebase 설정이 완료되지 않았습니다. 콘솔 설정을 확인해주세요.',
    'not-found' => 'Firebase 프로젝트 또는 문서를 찾을 수 없습니다.',
    'missing-user' => '회원 정보를 생성하지 못했습니다.',
    _ => error.message ?? 'Firebase 오류가 발생했습니다. (${error.code})',
  };
}

const _brandOrange = Color(0xFFFF6F0F);
const _ink = Color(0xFF222222);
const _muted = Color(0xFF767676);
const _surface = Color(0xFFF7F8FA);
const _warning = Color(0xFFFFF3E8);
const _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.nproject.nproject';

class NprojectApp extends StatelessWidget {
  const NprojectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nproject',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _brandOrange,
          primary: _brandOrange,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: _ink,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _brandOrange, width: 1.4),
          ),
        ),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  late final List<Widget> _pages = [
    HomeScreen(onWrite: () => setState(() => _index = 2)),
    const CategoryScreen(),
    const PostListingScreen(),
    const MyPageScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialDeepLink());
  }

  Future<void> _openInitialDeepLink() async {
    try {
      final listingId = await const MethodChannel(
        'nproject/share',
      ).invokeMethod<String>('getInitialListingId');
      if (!mounted || listingId == null || listingId.isEmpty) return;

      MarketListing? listing;
      for (final item in sampleListings) {
        if (item.id == listingId) {
          listing = item;
          break;
        }
      }
      final selectedListing = listing;
      if (selectedListing == null) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ListingDetailScreen(listing: selectedListing),
        ),
      );
    } on PlatformException {
      // Deep links are optional on unsupported platforms.
    } on MissingPluginException {
      // Native share/deep-link channels are not available on Flutter web.
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        if (_index != 0) {
          setState(() => _index = 0);
          return;
        }

        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('앱 종료'),
            content: const Text('앱을 종료하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('아니오'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: _brandOrange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('예'),
              ),
            ],
          ),
        );

        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: _pages[_index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          indicatorColor: _brandOrange.withValues(alpha: 0.12),
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: '카테고리',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: '등록',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '나의 정보',
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.onWrite, super.key});

  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<User?>(
          stream: _authStateStream(),
          builder: (context, snapshot) {
            final user = snapshot.data;
            final name = user?.displayName?.trim().isNotEmpty == true
                ? user!.displayName!.trim()
                : '하늘상점';
            return Text('$name님');
          },
        ),
        actions: [
          IconButton(
            tooltip: '검색',
            onPressed: () {},
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: '알림',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
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
                  _QuickWritePanel(onWrite: onWrite),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return FilterChip(
                          selected: index == 0,
                          showCheckmark: false,
                          label: Text(category),
                          onSelected: (_) {},
                        );
                      },
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemCount: categories.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firebaseUnavailableMessage() == null
                ? FirebaseFirestore.instance
                      .collection('listings')
                      .orderBy('createdAt', descending: true)
                      .snapshots()
                : null,
            builder: (context, snapshot) {
              final firestoreListings = snapshot.hasData
                  ? snapshot.data!.docs.map(_listingFromDoc).toList()
                  : <MarketListing>[];
              final listings = [...firestoreListings, ...sampleListings];

              return SliverMainAxisGroup(
                slivers: [
                  if (snapshot.hasError)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: _NoticeBox(
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
                      color: Color(0xFFEDEDED),
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
        backgroundColor: _brandOrange,
        foregroundColor: Colors.white,
        onPressed: onWrite,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('글쓰기'),
      ),
    );
  }
}

class _QuickWritePanel extends StatelessWidget {
  const _QuickWritePanel({required this.onWrite});

  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _QuickAction(
              icon: Icons.shopping_bag_outlined,
              title: '중고거래',
              subtitle: '물건 팔기',
              onTap: onWrite,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickAction(
              icon: Icons.flight_takeoff,
              title: '해주세요',
              subtitle: '배송 부탁',
              onTap: onWrite,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickAction(
              icon: Icons.currency_exchange,
              title: '화폐 교환',
              subtitle: '소액 교환',
              onTap: onWrite,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Icon(icon, color: _brandOrange, size: 26),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class ListingTile extends StatelessWidget {
  const ListingTile({required this.listing, required this.onTap, super.key});

  final MarketListing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: listing.id,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: listing.color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(listing.icon, color: Colors.white, size: 34),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          listing.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (listing.type != ListingType.used)
                        _TypePill(text: listing.type.label),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${listing.place} · ${listing.postedAgo}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    listing.price,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _showSellerProfile(context, listing),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 15,
                          color: _muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${listing.sellerNickname} · 거래 ${listing.tradeCount}회',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({required this.listing, super.key});

  final MarketListing listing;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  int _imageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 330,
            pinned: true,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
            ),
            actions: [
              IconButton(
                tooltip: '공유',
                onPressed: () => _showShareSheet(context, listing),
                icon: const Icon(Icons.ios_share),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: PageView.builder(
                controller: _pageController,
                physics: const PageScrollPhysics(),
                itemCount: listing.photoCount,
                onPageChanged: (value) => setState(() => _imageIndex = value),
                itemBuilder: (context, index) {
                  return Hero(
                    tag: index == 0 ? listing.id : '${listing.id}-$index',
                    child: Container(
                      color: Color.lerp(
                        listing.color,
                        Colors.black,
                        index * 0.08,
                      ),
                      child: Icon(listing.icon, color: Colors.white, size: 86),
                    ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _showSellerProfile(context, listing),
                        child: CircleAvatar(
                          backgroundColor: _brandOrange.withValues(alpha: 0.14),
                          child: Text(
                            listing.sellerNickname.characters.first,
                            style: const TextStyle(
                              color: _brandOrange,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => _showSellerProfile(context, listing),
                              child: Text(
                                listing.sellerNickname,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              '거래 ${listing.tradeCount}회 · ${listing.place}',
                              style: const TextStyle(color: _muted),
                            ),
                          ],
                        ),
                      ),
                      _TypePill(text: listing.type.label),
                    ],
                  ),
                  const Divider(height: 34),
                  if (listing.photoCount > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: List.generate(
                            listing.photoCount,
                            (index) => GestureDetector(
                              onTap: () => _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 240),
                                curve: Curves.easeOut,
                              ),
                              child: Container(
                                width: index == _imageIndex ? 18 : 7,
                                height: 7,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: index == _imageIndex
                                      ? _brandOrange
                                      : const Color(0xFFD8D8D8),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '${_imageIndex + 1}/${listing.photoCount}',
                          style: const TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  if (listing.photoCount > 1)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        '사진을 좌우로 밀어 넘겨보세요.',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ),
                  if (listing.photoCount > 1) const SizedBox(height: 12),
                  Text(
                    listing.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${listing.category} · ${listing.postedAgo}',
                    style: const TextStyle(color: _muted),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    listing.description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  _TradeLocationText(value: listing.placeNote),
                  if (listing.contactNote != null)
                    _InfoRow(
                      icon: Icons.alternate_email,
                      label: '연락 방법',
                      value: listing.contactNote!,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFEDEDED))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  listing.price,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () => _showContactInfo(context, listing),
                style: FilledButton.styleFrom(
                  backgroundColor: _brandOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                child: const Text('연락처 보기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showShareSheet(
  BuildContext context,
  MarketListing listing,
) async {
  final appLink = 'nproject://listing/${listing.id}';
  final fallbackLink =
      'https://github.com/anidr2am-cell/nproject/releases/latest';
  final shareText = [
    '[Nproject] ${listing.title}',
    listing.price,
    '앱 설치됨: $appLink',
    '앱 미설치: $fallbackLink',
  ].join('\n');

  await Clipboard.setData(ClipboardData(text: shareText));
  if (!context.mounted) return;

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '공유 링크',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            SelectableText(shareText, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: shareText));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('공유 링크를 복사했습니다.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('복사'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _shareViaAndroid(context, shareText),
                    style: FilledButton.styleFrom(
                      backgroundColor: _brandOrange,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('공유'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _shareViaAndroid(BuildContext context, String text) async {
  try {
    await const MethodChannel(
      'nproject/share',
    ).invokeMethod<void>('shareText', {'text': text});
  } on PlatformException {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유 기능을 열 수 없어 링크를 복사했습니다.')),
      );
    }
  }
}

void _showSellerProfile(BuildContext context, MarketListing listing) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _brandOrange.withValues(alpha: 0.14),
                  child: Text(
                    listing.sellerNickname.characters.first,
                    style: const TextStyle(
                      color: _brandOrange,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.sellerNickname,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${listing.place} · 거래 ${listing.tradeCount}회',
                        style: const TextStyle(color: _muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              '이전 거래 내역',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (listing.previousTrades.isEmpty)
              const Text('이전 거래 내역이 없습니다.', style: TextStyle(color: _muted))
            else
              ...listing.previousTrades.map(
                (trade) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(trade),
                ),
              ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _showContactInfo(context, listing),
              style: FilledButton.styleFrom(
                backgroundColor: _brandOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
              ),
              icon: const Icon(Icons.alternate_email),
              label: const Text('연락처 보기'),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showContactInfo(BuildContext context, MarketListing listing) {
  final kakao = listing.kakaoId?.trim().isNotEmpty == true
      ? listing.kakaoId!.trim()
      : '없음';
  final line = listing.lineId?.trim().isNotEmpty == true
      ? listing.lineId!.trim()
      : '없음';

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('연락처'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('카카오톡 ID: $kakao'),
          const SizedBox(height: 8),
          Text('라인 ID: $line'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('카테고리')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Text(
            '중고거래',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: categories
                .map(
                  (category) => ActionChip(
                    label: Text(category),
                    onPressed: () {},
                    avatar: const Icon(Icons.sell_outlined, size: 18),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 30),
          const Text(
            'Nproject 특화 게시판',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          const _FeatureBoardTile(
            icon: Icons.flight,
            title: '해주세요',
            body: '한국과 태국을 오가는 사람이 필요한 물건을 전달하고, 요청자가 수수료를 먼저 제안합니다.',
          ),
          const _FeatureBoardTile(
            icon: Icons.currency_exchange,
            title: '화폐 교환',
            body: '여행 후 남은 소액의 바트와 원화를 사용자끼리 교환하는 게시판입니다.',
          ),
        ],
      ),
    );
  }
}

class PostListingScreen extends StatefulWidget {
  const PostListingScreen({super.key});

  @override
  State<PostListingScreen> createState() => _PostListingScreenState();
}

class _PostListingScreenState extends State<PostListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _placeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();
  final _exchangeRateController = TextEditingController();

  ListingType _type = ListingType.used;
  String _category = categories.first;
  String _currencyDirection = '바트를 원화로';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _placeController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    _exchangeRateController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '필수 입력 항목입니다.';
    }
    return null;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, Object?> _listingPayload() {
    final title = _titleController.text.trim();
    final name = _nameController.text.trim();
    final price = _priceController.text.trim();
    final place = _placeController.text.trim();
    final description = _descriptionController.text.trim();
    final contact = _contactController.text.trim();
    final exchangeRate = _exchangeRateController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    return {
      'type': _type.name,
      'typeLabel': _type.label,
      'title': title,
      'itemName': name,
      'category': _type == ListingType.used ? _category : _type.label,
      'price': price,
      'place': place,
      'description': description,
      'contact': contact,
      'currencyDirection': _type == ListingType.currency
          ? _currencyDirection
          : null,
      'exchangeRate': _type == ListingType.currency ? exchangeRate : null,
      'sellerUid': user?.uid,
      'sellerEmail': user?.email,
      'sellerNickname': user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!.trim()
          : user?.email ?? '익명',
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _submitListing() async {
    debugPrint('[PostListingScreen] submit button tapped: ${_type.name}');
    FocusScope.of(context).unfocus();

    final unavailableMessage = _firebaseUnavailableMessage();
    if (unavailableMessage != null) {
      debugPrint(
        '[PostListingScreen] Firebase unavailable: $unavailableMessage',
      );
      _showMessage(unavailableMessage);
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      debugPrint('[PostListingScreen] validation failed');
      _showMessage('입력 내용을 확인해주세요.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final payload = _listingPayload();
      debugPrint('[PostListingScreen] Firestore add start: listings');
      final doc = await FirebaseFirestore.instance
          .collection('listings')
          .add(payload)
          .timeout(_firebaseRequestTimeout);
      debugPrint('[PostListingScreen] Firestore add success: ${doc.id}');

      if (!mounted) return;
      _formKey.currentState?.reset();
      _titleController.clear();
      _nameController.clear();
      _priceController.clear();
      _placeController.clear();
      _descriptionController.clear();
      _contactController.clear();
      _exchangeRateController.clear();
      setState(() {
        _category = categories.first;
        _currencyDirection = '바트를 원화로';
      });
      _showMessage('${_type.label} 글이 등록되었습니다.');
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        '[PostListingScreen] Firebase error: ${error.code} ${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      _showMessage(_firebaseMessage(error));
    } on TimeoutException catch (error, stackTrace) {
      debugPrint('[PostListingScreen] timeout: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('등록 요청 시간이 초과되었습니다. 네트워크와 Firebase 설정을 확인해주세요.');
    } catch (error, stackTrace) {
      debugPrint('[PostListingScreen] unknown error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('등록 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('글 등록')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const _InputLabel('게시판'),
            SegmentedButton<ListingType>(
              segments: ListingType.values
                  .map(
                    (type) => ButtonSegment(
                      value: type,
                      label: Text(type.label),
                      icon: Icon(type.icon),
                    ),
                  )
                  .toList(),
              selected: {_type},
              onSelectionChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _type = value.first),
            ),
            const SizedBox(height: 18),
            if (_type == ListingType.used)
              _UsedListingForm(
                titleController: _titleController,
                itemController: _nameController,
                priceController: _priceController,
                placeController: _placeController,
                descriptionController: _descriptionController,
                category: _category,
                onCategoryChanged: (value) => setState(() => _category = value),
                validator: _required,
              ),
            if (_type == ListingType.request)
              _DeliveryRequestForm(
                titleController: _titleController,
                itemController: _nameController,
                feeController: _priceController,
                contactController: _contactController,
                descriptionController: _descriptionController,
                validator: _required,
              ),
            if (_type == ListingType.currency)
              _CurrencyExchangeForm(
                titleController: _titleController,
                amountController: _priceController,
                rateController: _exchangeRateController,
                placeController: _placeController,
                methodController: _descriptionController,
                currencyDirection: _currencyDirection,
                onCurrencyChanged: (value) =>
                    setState(() => _currencyDirection = value),
                validator: _required,
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _submitListing,
              style: FilledButton.styleFrom(
                backgroundColor: _brandOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text('${_type.label} 등록하기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsedListingForm extends StatelessWidget {
  const _UsedListingForm({
    required this.titleController,
    required this.itemController,
    required this.priceController,
    required this.placeController,
    required this.descriptionController,
    required this.category,
    required this.onCategoryChanged,
    required this.validator,
  });

  final TextEditingController titleController;
  final TextEditingController itemController;
  final TextEditingController priceController;
  final TextEditingController placeController;
  final TextEditingController descriptionController;
  final String category;
  final ValueChanged<String> onCategoryChanged;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PhotoPickerMock(),
        const SizedBox(height: 22),
        const _InputLabel('제목'),
        TextFormField(
          controller: titleController,
          validator: validator,
          decoration: const InputDecoration(hintText: '예: 아이폰 14 프로 판매합니다'),
        ),
        const SizedBox(height: 18),
        const _InputLabel('제품명'),
        TextFormField(
          controller: itemController,
          validator: validator,
          decoration: const InputDecoration(hintText: '예: 아이폰 14 프로 256GB'),
        ),
        const SizedBox(height: 18),
        const _InputLabel('판매 가격'),
        TextFormField(
          controller: priceController,
          validator: validator,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'THB 또는 KRW 금액 입력'),
        ),
        const SizedBox(height: 18),
        const _InputLabel('카테고리'),
        _CategoryDropdown(value: category, onChanged: onCategoryChanged),
        const SizedBox(height: 18),
        const _InputLabel('거래 희망 장소'),
        TextFormField(
          controller: placeController,
          validator: validator,
          decoration: const InputDecoration(hintText: '예: 파타야 힐튼호텔 앞'),
        ),
        const SizedBox(height: 18),
        const _InputLabel('제품 상세 설명'),
        TextFormField(
          controller: descriptionController,
          validator: validator,
          minLines: 5,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: '상태, 구매 시기, 전달 가능 시간 등을 자세히 적어주세요.',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

class _DeliveryRequestForm extends StatelessWidget {
  const _DeliveryRequestForm({
    required this.titleController,
    required this.itemController,
    required this.feeController,
    required this.contactController,
    required this.descriptionController,
    required this.validator,
  });

  final TextEditingController titleController;
  final TextEditingController itemController;
  final TextEditingController feeController;
  final TextEditingController contactController;
  final TextEditingController descriptionController;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _InputLabel('제목'),
        TextFormField(
          controller: titleController,
          validator: validator,
          decoration: const InputDecoration(hintText: '예: 한국에서 방콕으로 영양제 부탁드려요'),
        ),
        const SizedBox(height: 18),
        const _InputLabel('물품명'),
        TextFormField(
          controller: itemController,
          validator: validator,
          decoration: const InputDecoration(hintText: '배달 원하는 물품을 기재하세요.'),
        ),
        const SizedBox(height: 18),
        const _InputLabel('배달 수수료'),
        TextFormField(
          controller: feeController,
          validator: validator,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '수수료 제시'),
        ),
        const SizedBox(height: 18),
        const _InputLabel('카카오톡 or 라인 ID'),
        TextFormField(
          controller: contactController,
          validator: validator,
          decoration: const InputDecoration(hintText: '연락 가능한 ID 입력'),
        ),
        const SizedBox(height: 18),
        const _InputLabel('상세 설명'),
        TextFormField(
          controller: descriptionController,
          validator: validator,
          minLines: 6,
          maxLines: 9,
          decoration: const InputDecoration(
            hintText:
                '구체적인 제품 명과 색상, 크기, 무게 등을 상세히 설명해주세요. 태국 반입 금지 물품은 등록 불가합니다.',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 14),
        const _NoticeBox(
          icon: Icons.info_outline,
          text: '태국 반입 금지 물품, 고가품, 통관 문제가 생길 수 있는 물품은 등록할 수 없습니다.',
        ),
      ],
    );
  }
}

class _CurrencyExchangeForm extends StatelessWidget {
  const _CurrencyExchangeForm({
    required this.titleController,
    required this.amountController,
    required this.rateController,
    required this.placeController,
    required this.methodController,
    required this.currencyDirection,
    required this.onCurrencyChanged,
    required this.validator,
  });

  final TextEditingController titleController;
  final TextEditingController amountController;
  final TextEditingController rateController;
  final TextEditingController placeController;
  final TextEditingController methodController;
  final String currencyDirection;
  final ValueChanged<String> onCurrencyChanged;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _InputLabel('제목'),
        TextFormField(
          controller: titleController,
          validator: validator,
          decoration: const InputDecoration(hintText: '예: 남은 바트 원화로 교환 원해요'),
        ),
        const SizedBox(height: 18),
        const _InputLabel('원하는 화폐'),
        _CurrencyDropdown(
          value: currencyDirection,
          onChanged: onCurrencyChanged,
        ),
        const SizedBox(height: 18),
        const _InputLabel('금액'),
        TextFormField(
          controller: amountController,
          validator: validator,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '예: 3,200 THB 또는 120,000 KRW',
          ),
        ),
        const SizedBox(height: 18),
        const _InputLabel('적용 환율'),
        TextFormField(
          controller: rateController,
          validator: validator,
          decoration: const InputDecoration(hintText: '예: 네이버 살때'),
        ),
        const SizedBox(height: 18),
        const _InputLabel('거래 희망 장소'),
        TextFormField(
          controller: placeController,
          validator: validator,
          decoration: const InputDecoration(hintText: '예: 방콕 한인 식당, 파타야 카페'),
        ),
        const SizedBox(height: 18),
        const _InputLabel('거래방법'),
        TextFormField(
          controller: methodController,
          validator: validator,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: '예: 한국 계좌에서 송금 후 바트 현금 수령 등',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 14),
        const _NoticeBox(
          icon: Icons.warning_amber_rounded,
          text:
              '최근 화폐 교환 관련 사기가 많으니 주의해서 거래하시기 바랍니다. 가급적 거래 장소를 한인이 운영하는 식당 같은 공개 장소로 정하세요.',
        ),
      ],
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _locationController = TextEditingController();
  final _kakaoController = TextEditingController();
  final _lineController = TextEditingController();
  final _phoneController = TextEditingController();

  String _phoneCountryCode = '+66';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _locationController.dispose();
    _kakaoController.dispose();
    _lineController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '필수 입력 항목입니다.';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final message = _required(value);
    if (message != null) return message;
    final email = value!.trim();
    if (!email.contains('@') || !email.contains('.')) {
      return '이메일 형식을 확인해주세요.';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final message = _required(value);
    if (message != null) return message;
    if (value!.trim().length < 6) {
      return '비밀번호는 6자리 이상이어야 합니다.';
    }
    return null;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitSignUp() async {
    debugPrint('[AuthScreen] signup button tapped');
    FocusScope.of(context).unfocus();

    final unavailableMessage = _firebaseUnavailableMessage();
    if (unavailableMessage != null) {
      debugPrint('[AuthScreen] Firebase unavailable: $unavailableMessage');
      _showMessage(unavailableMessage);
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      debugPrint('[AuthScreen] validation failed');
      _showMessage('회원가입 입력 내용을 확인해주세요.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      debugPrint(
        '[AuthScreen] FirebaseAuth createUserWithEmailAndPassword start',
      );
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(_firebaseRequestTimeout);
      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'missing-user',
          message: '회원 정보를 생성하지 못했습니다.',
        );
      }

      await user.updateDisplayName(_nicknameController.text.trim());
      debugPrint('[AuthScreen] Firestore set start: users/${user.uid}');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'uid': user.uid,
            'name': _nameController.text.trim(),
            'nickname': _nicknameController.text.trim(),
            'email': email,
            'location': _locationController.text.trim(),
            'kakaoId': _kakaoController.text.trim(),
            'lineId': _lineController.text.trim(),
            'phoneCountryCode': _phoneCountryCode,
            'phone': _phoneController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(_firebaseRequestTimeout);
      debugPrint('[AuthScreen] signup success: ${user.uid}');

      if (!mounted) return;
      _showMessage('회원가입이 완료되었습니다.');
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint(
        '[AuthScreen] FirebaseAuth error: ${error.code} ${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      _showMessage(_firebaseMessage(error));
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('[AuthScreen] Firebase error: ${error.code} ${error.message}');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage(_firebaseMessage(error));
    } on TimeoutException catch (error, stackTrace) {
      debugPrint('[AuthScreen] timeout: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('회원가입 요청 시간이 초과되었습니다. 네트워크와 Firebase 설정을 확인해주세요.');
    } catch (error, stackTrace) {
      debugPrint('[AuthScreen] unknown error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('회원가입 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원 가입')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const _InputLabel('이름'),
            TextFormField(
              controller: _nameController,
              validator: _required,
              decoration: const InputDecoration(hintText: '실명 입력'),
            ),
            const SizedBox(height: 18),
            const _InputLabel('닉네임'),
            TextFormField(
              controller: _nicknameController,
              validator: _required,
              decoration: const InputDecoration(hintText: '앱에 표시될 이름'),
            ),
            const SizedBox(height: 18),
            const _InputLabel('이메일 ID'),
            TextFormField(
              controller: _emailController,
              validator: _emailValidator,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'example@email.com'),
            ),
            const SizedBox(height: 18),
            const _InputLabel('비밀번호'),
            TextFormField(
              controller: _passwordController,
              validator: _passwordValidator,
              obscureText: true,
              decoration: const InputDecoration(hintText: '6자리 이상'),
            ),
            const SizedBox(height: 24),
            const _InputLabel('선택 정보'),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                hintText: '거주지 위치 예: 방콕, 파타야, 치앙마이',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _kakaoController,
              decoration: const InputDecoration(hintText: '카카오톡 ID'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lineController,
              decoration: const InputDecoration(hintText: '라인 ID'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 104,
                  child: _PhoneCountryDropdown(
                    value: _phoneCountryCode,
                    onChanged: (value) =>
                        setState(() => _phoneCountryCode = value),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(hintText: '연락처'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _submitSignUp,
              style: FilledButton.styleFrom(
                backgroundColor: _brandOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('회원 가입하기'),
            ),
          ],
        ),
      ),
    );
  }
}

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStateStream(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: const Text('나의 정보'),
            actions: [
              IconButton(
                tooltip: '설정',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              _ProfileHeader(user: user),
              const SizedBox(height: 18),
              if (user == null) ...[
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.login),
                  label: const Text('로그인'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const AuthScreen())),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('회원 가입'),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AccountInfoScreen(),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('계정 정보 관리'),
                ),
              ],
              const SizedBox(height: 22),
              _UserInfoSections(user: user),
            ],
          ),
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return '필수 입력 항목입니다.';
    return null;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitLogin() async {
    debugPrint('[LoginScreen] login button tapped');
    FocusScope.of(context).unfocus();

    final unavailableMessage = _firebaseUnavailableMessage();
    if (unavailableMessage != null) {
      _showMessage(unavailableMessage);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showMessage('로그인 정보를 입력해주세요.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          )
          .timeout(_firebaseRequestTimeout);
      if (!mounted) return;
      _showMessage('로그인되었습니다.');
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint('[LoginScreen] FirebaseAuth error: ${error.code}');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage(_firebaseMessage(error));
    } on TimeoutException catch (error, stackTrace) {
      debugPrint('[LoginScreen] timeout: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('로그인 요청 시간이 초과되었습니다.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const _InputLabel('이메일 ID'),
            TextFormField(
              controller: _emailController,
              validator: _required,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'example@email.com'),
            ),
            const SizedBox(height: 18),
            const _InputLabel('비밀번호'),
            TextFormField(
              controller: _passwordController,
              validator: _required,
              obscureText: true,
              decoration: const InputDecoration(hintText: '비밀번호'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _submitLogin,
              style: FilledButton.styleFrom(
                backgroundColor: _brandOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('로그인'),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('로그아웃되었습니다.')));
    Navigator.of(context).pop();
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final user = _currentUserOrNull();
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text(
          '탈퇴하시면 기존 거래내역이나 정보가 모두 사라지게 됩니다. 그래도 정말로 탈퇴하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('아니오'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _brandOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('예'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete()
          .timeout(_firebaseRequestTimeout);
      await user.delete().timeout(_firebaseRequestTimeout);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')));
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (error) {
      if (!context.mounted) return;
      final message = error.code == 'requires-recent-login'
          ? '보안을 위해 다시 로그인한 뒤 탈퇴를 진행해주세요.'
          : _firebaseMessage(error);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_firebaseMessage(error))));
    }
  }

  Future<void> _openPlayStore(BuildContext context) async {
    final uri = Uri.parse(_playStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('스토어 링크를 열 수 없습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUserOrNull();

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _SettingsTile(
            icon: Icons.manage_accounts_outlined,
            title: '계정 / 정보관리',
            subtitle: '계정 정보 수정 및 확인',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountInfoScreen()),
            ),
          ),
          _SettingsTile(
            icon: Icons.campaign_outlined,
            title: '공지사항',
            subtitle: '운영자가 게시한 공지사항',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const NoticesScreen())),
          ),
          _SettingsTile(
            icon: Icons.language,
            title: '언어설정',
            subtitle: '영어, 태국어 지원 예정',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()),
            ),
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            title: '버전정보',
            subtitle: '현재 버전 1.0.0+1',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VersionInfoScreen(onOpenStore: _openPlayStore),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (user != null)
            _SettingsTile(
              icon: Icons.logout,
              title: '로그아웃',
              subtitle: '현재 계정에서 로그아웃',
              onTap: () => _logout(context),
            ),
          if (user != null)
            _SettingsTile(
              icon: Icons.person_remove_outlined,
              title: '탈퇴하기',
              subtitle: '회원 정보 DB 삭제',
              destructive: true,
              onTap: () => _deleteAccount(context),
            ),
        ],
      ),
    );
  }
}

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final _nicknameController = TextEditingController();
  final _locationController = TextEditingController();
  final _kakaoController = TextEditingController();
  final _lineController = TextEditingController();
  final _phoneController = TextEditingController();
  String _phoneCountryCode = '+66';
  bool _loaded = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _locationController.dispose();
    _kakaoController.dispose();
    _lineController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _load(Map<String, dynamic> data, User user) {
    if (_loaded) return;
    _nicknameController.text = _stringValue(
      data['nickname'],
      user.displayName ?? '',
    );
    _locationController.text = _stringValue(data['location'], '');
    _kakaoController.text = _stringValue(data['kakaoId'], '');
    _lineController.text = _stringValue(data['lineId'], '');
    _phoneController.text = _stringValue(data['phone'], '');
    _phoneCountryCode = _stringValue(data['phoneCountryCode'], '+66');
    _loaded = true;
  }

  Future<void> _save(User user) async {
    setState(() => _isSaving = true);
    try {
      final nickname = _nicknameController.text.trim();
      await user.updateDisplayName(nickname);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'uid': user.uid,
            'nickname': nickname,
            'email': user.email,
            'location': _locationController.text.trim(),
            'kakaoId': _kakaoController.text.trim(),
            'lineId': _lineController.text.trim(),
            'phoneCountryCode': _phoneCountryCode,
            'phone': _phoneController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(_firebaseRequestTimeout);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('계정 정보가 저장되었습니다.')));
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_firebaseMessage(error))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUserOrNull();
    if (user == null) {
      return const _LoginRequiredScreen(title: '계정 / 정보관리');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('계정 / 정보관리')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          _load(snapshot.data?.data() ?? {}, user);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              const _InputLabel('이메일 ID'),
              TextFormField(
                initialValue: user.email ?? '',
                readOnly: true,
                decoration: const InputDecoration(hintText: '이메일'),
              ),
              const SizedBox(height: 18),
              const _InputLabel('닉네임'),
              TextField(
                controller: _nicknameController,
                decoration: const InputDecoration(hintText: '닉네임'),
              ),
              const SizedBox(height: 18),
              const _InputLabel('거주지 위치'),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(hintText: '예: 방콕, 파타야'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _kakaoController,
                decoration: const InputDecoration(hintText: '카카오톡 ID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lineController,
                decoration: const InputDecoration(hintText: '라인 ID'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 104,
                    child: _PhoneCountryDropdown(
                      value: _phoneCountryCode,
                      onChanged: (value) =>
                          setState(() => _phoneCountryCode = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(hintText: '연락처'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : () => _save(user),
                style: FilledButton.styleFrom(
                  backgroundColor: _brandOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('저장'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class NoticesScreen extends StatelessWidget {
  const NoticesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('공지사항')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notices')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('공지사항을 불러올 수 없습니다.'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('등록된 공지사항이 없습니다.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.campaign_outlined),
                title: Text(_stringValue(data['title'], '공지사항')),
                subtitle: Text(_stringValue(data['body'], '')),
              );
            },
          );
        },
      ),
    );
  }
}

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('언어설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: const [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.translate),
            title: Text('한국어'),
            trailing: Icon(Icons.check),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.language),
            title: Text('English'),
            subtitle: Text('추후 업데이트 예정'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.language),
            title: Text('ภาษาไทย'),
            subtitle: Text('추후 업데이트 예정'),
          ),
        ],
      ),
    );
  }
}

class VersionInfoScreen extends StatelessWidget {
  const VersionInfoScreen({required this.onOpenStore, super.key});

  final Future<void> Function(BuildContext context) onOpenStore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('버전정보')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const _ProfileSection(
            title: '앱 정보',
            rows: [('현재 버전', '1.0.0+1'), ('앱 이름', 'T-Trade')],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => onOpenStore(context),
            style: FilledButton.styleFrom(
              backgroundColor: _brandOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.shop_outlined),
            label: const Text('업데이트 확인'),
          ),
        ],
      ),
    );
  }
}

class _LoginRequiredScreen extends StatelessWidget {
  const _LoginRequiredScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
            style: FilledButton.styleFrom(
              backgroundColor: _brandOrange,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.login),
            label: const Text('로그인'),
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.red.shade700 : _ink;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _PhotoPickerMock extends StatefulWidget {
  const _PhotoPickerMock();

  @override
  State<_PhotoPickerMock> createState() => _PhotoPickerMockState();
}

class _PhotoPickerMockState extends State<_PhotoPickerMock> {
  final ImagePicker _picker = ImagePicker();
  final List<Uint8List> _photos = [];

  Future<void> _pickPhotos() async {
    final remaining = 5 - _photos.length;
    if (remaining <= 0) return;

    final picked = await _picker.pickMultiImage(
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (picked.isEmpty) return;

    final nextPhotos = <Uint8List>[];
    for (final file in picked.take(remaining)) {
      nextPhotos.add(await file.readAsBytes());
    }

    if (!mounted) return;
    setState(() => _photos.addAll(nextPhotos));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _pickPhotos,
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFDADADA)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt_outlined),
                    const SizedBox(height: 4),
                    Text('${_photos.length}/5'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '사진은 최대 5장까지 등록 가능하며, 상세 화면에서 슬라이드로 확인합니다.',
                style: TextStyle(color: _muted, height: 1.4),
              ),
            ),
          ],
        ),
        if (_photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _photos[index],
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => setState(() => _photos.removeAt(index)),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: _photos.length,
            ),
          ),
        ],
      ],
    );
  }
}

class _FeatureBoardTile extends StatelessWidget {
  const _FeatureBoardTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: _brandOrange),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(color: _muted, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : user?.email ?? '로그인이 필요합니다';
    final initial = displayName.characters.isEmpty
        ? '?'
        : displayName.characters.first;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: user == null ? _muted : _brandOrange,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user == null ? '로그인 후 계정 정보를 확인하세요.' : user!.email ?? '',
                  style: const TextStyle(color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserInfoSections extends StatelessWidget {
  const _UserInfoSections({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const _ProfileSection(
        title: '계정 상태',
        rows: [('상태', '로그아웃'), ('안내', '로그인 또는 회원 가입을 진행해주세요.')],
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        final nickname = _stringValue(
          data['nickname'],
          user!.displayName ?? '',
        );
        final location = _stringValue(data['location'], '-');
        final kakao = _stringValue(data['kakaoId'], '-');
        final line = _stringValue(data['lineId'], '-');
        final phoneCode = _stringValue(data['phoneCountryCode'], '');
        final phone = _stringValue(data['phone'], '-');

        return Column(
          children: [
            _ProfileSection(
              title: '회원 가입 필수 정보',
              rows: [
                ('닉네임', nickname),
                ('이메일 ID', user!.email ?? '-'),
                ('로그인 상태', '로그인됨'),
              ],
            ),
            const SizedBox(height: 18),
            _ProfileSection(
              title: '선택 정보',
              rows: [
                ('거주지 위치', location),
                ('카카오톡 ID', kakao),
                ('라인 ID', line),
                ('연락처', '$phoneCode $phone'.trim()),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFEDEDED)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              for (final row in rows)
                ListTile(
                  dense: true,
                  title: Text(row.$1),
                  trailing: Text(
                    row.$2,
                    style: const TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InputLabel extends StatelessWidget {
  const _InputLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _warning,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _brandOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(height: 1.4, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: categories
          .map(
            (category) =>
                DropdownMenuItem(value: category, child: Text(category)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: const [
        DropdownMenuItem(value: '바트를 원화로', child: Text('바트를 원화로')),
        DropdownMenuItem(value: '원화를 바트로', child: Text('원화를 바트로')),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _PhoneCountryDropdown extends StatelessWidget {
  const _PhoneCountryDropdown({this.value = '+66', this.onChanged});

  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      ),
      selectedItemBuilder: (context) => const [
        Text('+66', overflow: TextOverflow.ellipsis),
        Text('+82', overflow: TextOverflow.ellipsis),
      ],
      items: const [
        DropdownMenuItem(value: '+66', child: Text('태국 +66')),
        DropdownMenuItem(value: '+82', child: Text('한국 +82')),
      ],
      onChanged: (value) {
        if (value != null) onChanged?.call(value);
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: _muted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: _muted)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeLocationText extends StatelessWidget {
  const _TradeLocationText({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('거래 희망 장소', style: TextStyle(color: _muted)),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _brandOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _brandOrange,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _stringValue(Object? value, String fallback) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

ListingType _listingTypeFromValue(Object? value) {
  final name = value?.toString();
  return ListingType.values.firstWhere(
    (type) => type.name == name,
    orElse: () => ListingType.used,
  );
}

MarketListing _listingFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  final type = _listingTypeFromValue(data['type']);
  final place = _stringValue(data['place'], '위치 미입력');
  final seller = _stringValue(data['sellerNickname'], '익명');

  return MarketListing(
    id: doc.id,
    type: type,
    title: _stringValue(data['title'], '제목 없음'),
    category: _stringValue(data['category'], type.label),
    price: _stringValue(data['price'], '가격 미입력'),
    place: place,
    placeNote: place,
    postedAgo: '방금 전',
    sellerNickname: seller,
    tradeCount: 0,
    description: _stringValue(data['description'], ''),
    icon: type.icon,
    color: switch (type) {
      ListingType.used => const Color(0xFF6750A4),
      ListingType.request => const Color(0xFFE16A54),
      ListingType.currency => const Color(0xFF2F80ED),
    },
    contactNote: _stringValue(data['contact'], '').isEmpty
        ? null
        : _stringValue(data['contact'], ''),
  );
}

enum ListingType {
  used('중고거래', Icons.shopping_bag_outlined),
  request('해주세요', Icons.flight_takeoff),
  currency('화폐 교환', Icons.currency_exchange);

  const ListingType(this.label, this.icon);

  final String label;
  final IconData icon;
}

class MarketListing {
  const MarketListing({
    required this.id,
    required this.type,
    required this.title,
    required this.category,
    required this.price,
    required this.place,
    required this.placeNote,
    required this.postedAgo,
    required this.sellerNickname,
    required this.tradeCount,
    required this.description,
    required this.icon,
    required this.color,
    this.photoCount = 1,
    this.contactNote,
    this.kakaoId,
    this.lineId,
    this.previousTrades = const [],
  });

  final String id;
  final ListingType type;
  final String title;
  final String category;
  final String price;
  final String place;
  final String placeNote;
  final String postedAgo;
  final String sellerNickname;
  final int tradeCount;
  final String description;
  final IconData icon;
  final Color color;
  final int photoCount;
  final String? contactNote;
  final String? kakaoId;
  final String? lineId;
  final List<String> previousTrades;
}

const categories = [
  '디지털기기',
  '생활가전',
  '가구/인테리어',
  '생활/주방',
  '유아동',
  '여성패션/잡화',
  '남성패션/잡화',
  '뷰티/미용',
  '스포츠/레저',
  '취미/게임/음반',
  '도서',
  '반려동물용품',
  '회원권',
  '기타 중고물품',
];

const sampleListings = [
  MarketListing(
    id: 'iphone14',
    type: ListingType.used,
    title: '아이폰 14 프로 256GB 딥퍼플',
    category: '디지털기기',
    price: '24,000 THB',
    place: '파타야',
    placeNote: '파타야 힐튼호텔 앞',
    postedAgo: '방금 전',
    sellerNickname: '하늘상점',
    tradeCount: 12,
    description:
        '한국에서 구매했고 케이스와 필름을 계속 사용했습니다. 배터리 성능 88%, 박스와 케이블 같이 드립니다. 직거래만 희망합니다.',
    icon: Icons.phone_iphone,
    color: Color(0xFF6750A4),
    photoCount: 5,
    contactNote: '카카오톡 ID 공개 가능',
    kakaoId: 'nproject_th',
    lineId: 'nproject.line',
    previousTrades: ['갤럭시 워치 5 판매 완료', '소니 헤드폰 거래 완료', '아이패드 미니 판매 완료'],
  ),
  MarketListing(
    id: 'membership',
    type: ListingType.used,
    title: '파타야 헬스장 회원권 2개월 양도',
    category: '회원권',
    price: '1,200 THB',
    place: '파타야',
    placeNote: '터미널21 근처 헬스장',
    postedAgo: '8분 전',
    sellerNickname: '운동하는곰',
    tradeCount: 4,
    description: '귀국 일정 때문에 남은 회원권을 양도합니다. 양도 가능 여부 확인 완료했습니다.',
    icon: Icons.card_membership,
    color: Color(0xFF455A64),
    photoCount: 2,
    previousTrades: ['요가매트 판매 완료', '러닝화 거래 완료'],
  ),
  MarketListing(
    id: 'delivery-request',
    type: ListingType.request,
    title: '서울에서 방콕 오시는 분, 영양제 부탁드려요',
    category: '해주세요',
    price: '수수료 700 THB 제안',
    place: '방콕',
    placeNote: '프롬퐁 BTS 근처',
    postedAgo: '31분 전',
    sellerNickname: '프롬퐁맘',
    tradeCount: 3,
    description:
        '서울 가족 집에 맡겨둔 작은 영양제 2통입니다. 무게 가볍고 포장 완료되어 있습니다. 방콕 도착 후 프롬퐁에서 받을 수 있어요.',
    icon: Icons.luggage_outlined,
    color: Color(0xFFE16A54),
    photoCount: 2,
    contactNote: '라인 ID로 연락 희망',
    lineId: 'prompong_mom',
    previousTrades: ['아기 옷 전달 요청 완료', '한국 과자 배송 요청 완료'],
  ),
  MarketListing(
    id: 'currency-baht',
    type: ListingType.currency,
    title: '남은 바트 3,200 THB를 원화로 교환 원해요',
    category: '화폐 교환',
    price: '3,200 THB',
    place: '치앙마이',
    placeNote: '님만해민 마야몰 1층',
    postedAgo: '1시간 전',
    sellerNickname: '치앙마이달',
    tradeCount: 5,
    description: '여행 후 남은 소액 바트입니다. 직접 만나서 금액 확인하고 서로 편한 기준으로 교환하고 싶습니다.',
    icon: Icons.payments_outlined,
    color: Color(0xFF2F80ED),
    photoCount: 1,
    kakaoId: 'chiangmai_moon',
    previousTrades: ['소액 바트 교환 완료', '한국 계좌 이체 거래 완료'],
  ),
];
