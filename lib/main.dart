import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

    if (_firebaseReady) {
      // FCM 초기화 (UI 준비 후 AppShell에서 호출)
      _initFcm(); 
    }
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

Future<void> _openLoginScreen(BuildContext context) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
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
  String? _selectedHomeCategory;
  ListingType? _selectedHomeType;

  void _moveToHomeTab() {
    if (!mounted) return;
    setState(() {
      _index = 0;
      _selectedHomeCategory = null;
      _selectedHomeType = null;
    });
  }

  void _handleCategorySelected(String category) {
    setState(() {
      _selectedHomeCategory = category;
      _selectedHomeType = ListingType.used; // 카테고리 선택 시 '중고거래' 타입으로 고정
      _index = 0;
    });
  }

  void _handleTypeSelected(ListingType type) {
    setState(() {
      _selectedHomeType = type;
      _selectedHomeCategory = null; // 타입 변경 시 카테고리 초기화
      _index = 0;
    });
  }

  Future<void> _handleWriteTap() async {
    if (_currentUserOrNull() == null) {
      await _promptLoginThenOpen();
      return;
    }
    if (!mounted) return;
    setState(() => _index = 2);
  }

  Future<void> _handleDestinationTap(int value) async {
    if (value == 2 && _currentUserOrNull() == null) {
      await _promptLoginThenOpen();
      return;
    }
    if (!mounted) return;
    setState(() => _index = value);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openInitialDeepLink();
      _initFcm();
    });
  }

  Future<void> _promptLoginThenOpen() async {
    final shouldMoveToLogin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그인 필요'),
        content: const Text('로그인 후 이용이 가능합니다. 로그인 페이지로 이동할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _brandOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('로그인'),
          ),
        ],
      ),
    );
    if (!mounted || shouldMoveToLogin != true) return;
    await _openLoginScreen(context);
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
    final pages = [
      HomeScreen(
        onWrite: _handleWriteTap,
        initialCategory: _selectedHomeCategory,
        initialType: _selectedHomeType,
      ),
      CategoryScreen(
        onCategorySelected: _handleCategorySelected,
        onTypeSelected: _handleTypeSelected,
      ),
      PostListingScreen(onSubmitSuccess: _moveToHomeTab),
      const MyPageScreen(),
    ];

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
        body: pages[_index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          indicatorColor: _brandOrange.withValues(alpha: 0.12),
          onDestinationSelected: (value) => _handleDestinationTap(value),
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.onWrite,
    this.initialCategory,
    this.initialType,
    super.key,
  });

  final VoidCallback onWrite;
  final String? initialCategory;
  final ListingType? initialType;

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
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _selectedType = widget.initialType;
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory != oldWidget.initialCategory ||
        widget.initialType != oldWidget.initialType) {
      setState(() {
        _selectedCategory = widget.initialCategory;
        _selectedType = widget.initialType;
      });
    }
  }

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
                stream: _authStateStream(),
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  if (user == null) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _openLoginScreen(context),
                        style: TextButton.styleFrom(
                          foregroundColor: _ink,
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
          const _NotificationIconButton(),
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
                  _QuickActionPanel(
                    selectedType: _selectedType,
                    onTypeSelected: (type) => setState(() {
                      _selectedType = _selectedType == type ? null : type;
                    }),
                    onWrite: widget.onWrite,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isAll = index == 0;
                        return FilterChip(
                          avatar: isAll ? const Icon(Icons.grid_view, size: 18) : null,
                          selected:
                              isAll ? _selectedCategory == null : _selectedCategory == category,
                          showCheckmark: false,
                          label: Text(category),
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = isAll ? null : category;
                            });
                          },
                        );
                      },
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemCount: categories.length,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: _showOnlyActive,
                        activeColor: _brandOrange,
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
                    .where((l) => l.title
                        .toLowerCase()
                        .contains(_searchQuery.trim().toLowerCase()))
                    .toList();
              }

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
        onPressed: widget.onWrite,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('글쓰기'),
      ),
    );
  }
}

class _NotificationIconButton extends StatelessWidget {
  const _NotificationIconButton();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStateStream(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null || _firebaseUnavailableMessage() != null) {
          return IconButton(
            tooltip: '알림',
            onPressed: () => _openLoginScreen(context),
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
              icon: _NotificationBadge(count: unreadCount),
            );
          },
        );
      },
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  const _NotificationBadge({required this.count});

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

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAllAsRead(BuildContext context, String uid) async {
    try {
      final unread = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get()
          .timeout(_firebaseRequestTimeout);

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit().timeout(_firebaseRequestTimeout);
    } catch (error, stackTrace) {
      debugPrint('[Notification] mark all failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('알림 읽음 처리에 실패했습니다.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUserOrNull();
    if (user == null || _firebaseUnavailableMessage() != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('알림')),
        body: Center(
          child: FilledButton(
            onPressed: () => _openLoginScreen(context),
            style: FilledButton.styleFrom(
              backgroundColor: _brandOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('로그인하기'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          TextButton(
            onPressed: () => _markAllAsRead(context, user.uid),
            child: const Text('모두 읽음'),
          ),
        ],
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
          if (snapshot.hasError) {
            debugPrint('[Notification] list failed: ${snapshot.error}');
            return const Center(child: Text('알림을 불러오지 못했습니다.'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('아직 도착한 알림이 없습니다.', style: TextStyle(color: _muted)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: Color(0xFFEDEDED)),
            itemBuilder: (context, index) {
              return _NotificationTile(notification: docs[index]);
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final QueryDocumentSnapshot<Map<String, dynamic>> notification;

  Future<void> _markAsRead() async {
    final data = notification.data();
    if (data['isRead'] == true) return;
    await notification.reference
        .update({'isRead': true, 'readAt': FieldValue.serverTimestamp()})
        .timeout(_firebaseRequestTimeout);
  }

  Future<void> _openTarget(BuildContext context) async {
    try {
      await _markAsRead();
    } catch (error, stackTrace) {
      debugPrint('[Notification] mark one failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    if (!context.mounted) return;

    final data = notification.data();
    final type = _stringValue(data['type'], '');
    final chatRoomId = _stringValue(data['chatRoomId'], '');
    final listingId = _stringValue(data['listingId'], '');

    if (type == 'chat' && chatRoomId.isNotEmpty) {
      await _openChatRoomFromNotification(context, chatRoomId, listingId);
      return;
    }

    if (listingId.isNotEmpty) {
      final listing = await _findListingById(listingId);
      if (!context.mounted || listing == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ListingDetailScreen(listing: listing),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = notification.data();
    final isRead = data['isRead'] == true;
    final type = _stringValue(data['type'], '');
    final icon = switch (type) {
      'chat' => Icons.chat_bubble_outline,
      'favorite' => Icons.favorite_border,
      'listingStatus' => Icons.sell_outlined,
      _ => Icons.notifications_none,
    };

    return ListTile(
      tileColor: isRead ? Colors.white : const Color(0xFFFFF8F3),
      leading: CircleAvatar(
        backgroundColor: isRead ? _surface : _warning,
        foregroundColor: isRead ? _muted : _brandOrange,
        child: Icon(icon, size: 20),
      ),
      title: Text(
        _stringValue(data['title'], '알림'),
        style: TextStyle(
          fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
        ),
      ),
      subtitle: Text(
        _stringValue(data['body'], ''),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isRead)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _brandOrange,
                shape: BoxShape.circle,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: _muted),
            onPressed: () => _deleteNotification(
              _currentUserOrNull()!.uid,
              notification.id,
            ),
          ),
        ],
      ),
      onTap: () => _openTarget(context),
    );
  }
}

Future<void> _openChatRoomFromNotification(
  BuildContext context,
  String chatRoomId,
  String listingId,
) async {
  try {
    final room = await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(chatRoomId)
        .get()
        .timeout(_firebaseRequestTimeout);
    final data = room.data();
    if (data == null || !context.mounted) return;

    final currentUid = _currentUserOrNull()?.uid;
    final sellerUid = _stringValue(data['sellerUid'], '');
    final sellerName = _stringValue(data['sellerNickname'], '판매자');
    final buyerName = _stringValue(data['buyerNickname'], '구매자');
    final otherName = currentUid == sellerUid ? buyerName : sellerName;
    final listing = listingId.isEmpty
        ? null
        : await _findListingById(listingId);
    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          roomId: chatRoomId,
          listing: listing,
          otherUserName: otherName,
        ),
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('[Notification] open chat failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('채팅방을 열 수 없습니다.')));
    }
  }
}

class _QuickActionPanel extends StatelessWidget {
  const _QuickActionPanel({
    required this.onWrite,
    required this.selectedType,
    required this.onTypeSelected,
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
              isSelected: selectedType == ListingType.used,
              onTap: () => onTypeSelected(ListingType.used),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickAction(
              icon: Icons.flight_takeoff,
              title: '해주세요',
              subtitle: '배송 부탁',
              isSelected: selectedType == ListingType.request,
              onTap: () => onTypeSelected(ListingType.request),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickAction(
              icon: Icons.currency_exchange,
              title: '화폐 교환',
              subtitle: '소액 교환',
              isSelected: selectedType == ListingType.currency,
              onTap: () => onTypeSelected(ListingType.currency),
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
    this.isSelected = false,
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
        color: isSelected ? _brandOrange : Colors.transparent,
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
                color: isSelected ? Colors.white : _brandOrange,
                size: 26,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : _ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white70 : _muted,
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

class ListingTile extends StatelessWidget {
  const ListingTile({required this.listing, required this.onTap, super.key});

  final MarketListing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = listing.photoUrls.isNotEmpty
        ? listing.photoUrls.first
        : null;

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
                child: imageUrl == null
                    ? Icon(listing.icon, color: Colors.white, size: 34)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                          errorBuilder: (_, _, _) =>
                              Icon(listing.icon, color: Colors.white, size: 34),
                        ),
                      ),
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

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _TypePill(text: listing.type.label),
                          const SizedBox(height: 4),
                          Text(
                            listing.status == 'sold'
                                ? '판매완료'
                                : listing.status == 'reserved'
                                ? '거래 예약중'
                                : '판매중',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: listing.status == 'sold'
                                  ? _muted
                                  : listing.status == 'reserved'
                                  ? Colors.blue
                                  : _brandOrange,
                            ),
                          ),
                        ],
                      ),
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
                        _SellerTradeLine(listing: listing),
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

bool _isSampleListing(MarketListing listing) {
  return _findSampleListingById(listing.id) != null;
}

bool _isMyListing(MarketListing listing) {
  final uid = _currentUserOrNull()?.uid;
  return uid != null && listing.sellerUid != null && listing.sellerUid == uid;
}

bool _canManageFirestoreListing(MarketListing listing) {
  return _isMyListing(listing) && !_isSampleListing(listing);
}

String _saleStatusLabel(String status) {
  return switch (status) {
    'sold' => '판매완료',
    'reserved' => '거래 예약중',
    _ => '판매중',
  };
}

Future<void> _updateListingSaleStatus(
  BuildContext context,
  MarketListing listing,
  String status,
) async {
  final unavailableMessage = _firebaseUnavailableMessage();
  if (unavailableMessage != null) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(unavailableMessage)));
    }
    return;
  }

  try {
    await FirebaseFirestore.instance
        .collection('listings')
        .doc(listing.id)
        .update({'status': status, 'updatedAt': FieldValue.serverTimestamp()})
        .timeout(_firebaseRequestTimeout);
    if (status == 'sold' || status == 'reserved') {
      await _notifyFavoriteUsersOfStatusChange(listing, status);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상태가 ${_saleStatusLabel(status)}(으)로 변경되었습니다.')),
      );
    }
  } catch (error, stackTrace) {
    debugPrint('[ListingStatus] update failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('판매 상태 변경에 실패했습니다.')));
    }
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

  Future<void> _openEditScreen() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PostListingScreen(
          editingListingId: _listing.id,
          initialListing: _listing,
        ),
      ),
    );
    if (!mounted || updated != true) return;

    final refreshed = await _findListingById(_listing.id);
    if (refreshed != null) {
      setState(() {
        _listing = refreshed;
        _saleStatus = refreshed.status;
      });
    }
  }

  Future<void> _deleteListing() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('물품 삭제'),
        content: const Text('정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _brandOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (!mounted || shouldDelete != true) return;

    final unavailableMessage = _firebaseUnavailableMessage();
    if (unavailableMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(unavailableMessage)));
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(_listing.id)
          .delete()
          .timeout(_firebaseRequestTimeout);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('물품이 삭제되었습니다.')));
      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrint('[ListingDelete] failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('물품 삭제에 실패했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = _listing;
    final isOwner = _canManageFirestoreListing(listing);
    final imageCount = listing.photoUrls.isNotEmpty
        ? listing.photoUrls.length
        : listing.photoCount;

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
                itemCount: imageCount,
                onPageChanged: (value) => setState(() => _imageIndex = value),
                itemBuilder: (context, index) {
                  if (listing.photoUrls.isNotEmpty) {
                    return Hero(
                      tag: index == 0 ? listing.id : '${listing.id}-$index',
                      child: Image.network(
                        listing.photoUrls[index],
                        fit: BoxFit.cover,
                        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                        errorBuilder: (_, _, _) => Container(
                          color: Color.lerp(
                            listing.color,
                            Colors.black,
                            index * 0.08,
                          ),
                          child: Icon(
                            listing.icon,
                            color: Colors.white,
                            size: 86,
                          ),
                        ),
                      ),
                    );
                  }
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
                  if (imageCount > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: List.generate(
                            imageCount,
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
                          '${_imageIndex + 1}/$imageCount',
                          style: const TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  if (imageCount > 1)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        '사진을 좌우로 밀어 넘겨보세요.',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ),
                  if (imageCount > 1) const SizedBox(height: 12),
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
                  _TradeLocationText(value: listing.price, label: '가격'),
                  const SizedBox(height: 12),
                  _TradeLocationText(
                    value: listing.placeNote,
                    label: '거래 희망 장소',
                  ),
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
          child: isOwner
              ? Row(
                  children: [
                    const Spacer(),
                    OutlinedButton(
                      onPressed: _openEditScreen,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _ink,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                      child: const Text('물품 수정'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _deleteListing,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                      child: const Text('물품 삭제'),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFEDEDED)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _saleStatus == 'sold'
                              ? 'sold'
                              : _saleStatus == 'reserved'
                              ? 'reserved'
                              : 'active',
                          items: const [
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('판매중'),
                            ),
                            DropdownMenuItem(
                              value: 'reserved',
                              child: Text('거래 예약중'),
                            ),
                            DropdownMenuItem(
                              value: 'sold',
                              child: Text('판매완료'),
                            ),
                          ],
                          onChanged: (value) async {
                            if (value == null || value == _saleStatus) return;
                            await _updateListingSaleStatus(
                              context,
                              listing,
                              value,
                            );
                            if (!mounted) return;
                            setState(() => _saleStatus = value);
                          },
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    const Spacer(),
                    _FavoriteBottomButton(listingId: listing.id),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _openChatForListing(context, listing),
                      style: FilledButton.styleFrom(
                        backgroundColor: _brandOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 18),
                          SizedBox(width: 8),
                          Text('메시지 보내기'),
                        ],
                      ),
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
              onPressed: () => _openChatForListing(context, listing),
              style: FilledButton.styleFrom(
                backgroundColor: _brandOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
              ),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('메시지 보내기'),
            ),
          ],
        ),
      ),
    ),
  );
}

String _chatRoomIdForListing({
  required String listingId,
  required String buyerUid,
  required String sellerUid,
}) {
  return '${listingId}_${buyerUid}_$sellerUid';
}

Future<void> _openChatForListing(
  BuildContext context,
  MarketListing listing,
) async {
  final unavailableMessage = _firebaseUnavailableMessage();
  if (unavailableMessage != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(unavailableMessage)));
    return;
  }

  final user = _currentUserOrNull();
  if (user == null) {
    await _openLoginScreen(context);
    return;
  }

  final sellerUid = listing.sellerUid?.trim();
  if (sellerUid == null || sellerUid.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('판매자 정보가 없어 채팅을 시작할 수 없습니다.')));
    return;
  }

  if (sellerUid == user.uid) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('본인이 등록한 물품에는 메시지를 보낼 수 없습니다.')),
    );
    return;
  }

  try {
    final buyerNickname = await _fetchNicknameForUid(
      user.uid,
      displayName: user.displayName,
      email: user.email,
    );
    final sellerNickname = await _resolveSellerNickname(listing);
    final roomId = _chatRoomIdForListing(
      listingId: listing.id,
      buyerUid: user.uid,
      sellerUid: sellerUid,
    );
    final photoUrl = listing.photoUrls.isNotEmpty
        ? listing.photoUrls.first
        : '';

    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId)
        .set({
          'listingId': listing.id,
          'listingTitle': listing.title,
          'listingPrice': listing.price,
          'listingPhotoUrl': photoUrl,
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
        }, SetOptions(merge: true))
        .timeout(_firebaseRequestTimeout);

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          roomId: roomId,
          listing: listing,
          otherUserName: sellerNickname,
        ),
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('[Chat] open failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('채팅방을 열 수 없습니다.')));
    }
  }
}

Future<void> _createUserNotification({
  required String recipientUid,
  required String type,
  required String title,
  required String body,
  String? actorUid,
  String? listingId,
  String? chatRoomId,
}) async {
  if (recipientUid.trim().isEmpty || _firebaseUnavailableMessage() != null) {
    return;
  }

  try {
    // 인앱 알림 생성
    await FirebaseFirestore.instance
        .collection('users')
        .doc(recipientUid)
        .collection('notifications')
        .add({
          'type': type,
          'title': title,
          'body': body,
          'actorUid': actorUid,
          'listingId': listingId,
          'chatRoomId': chatRoomId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        })
        .timeout(_firebaseRequestTimeout);

    // FCM 푸시 큐에 추가
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(recipientUid)
        .get()
        .timeout(_firebaseRequestTimeout);
    final fcmToken = _stringValue(userDoc.data()?['fcmToken'], '');

    if (fcmToken.isNotEmpty) {
      await FirebaseFirestore.instance.collection('fcmQueue').add({
        'token': fcmToken,
        'title': title,
        'body': body,
        'data': {
          'type': type,
          'listingId': listingId ?? '',
          'chatRoomId': chatRoomId ?? '',
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  } catch (error, stackTrace) {
    debugPrint('[Notification] create failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

Future<void> _deleteNotification(String userId, String notificationId) async {
  if (_firebaseUnavailableMessage() != null) return;
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .delete()
        .timeout(_firebaseRequestTimeout);
  } catch (e) {
    debugPrint('[Notification] delete failed: $e');
  }
}

Future<void> _deleteChatNotifications(String userId, String chatRoomId) async {
  if (_firebaseUnavailableMessage() != null) return;
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('type', isEqualTo: 'chat')
        .where('chatRoomId', isEqualTo: chatRoomId)
        .get()
        .timeout(_firebaseRequestTimeout);

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  } catch (e) {
    debugPrint('[Notification] _deleteChatNotifications failed: $e');
  }
}

Future<void> _deleteChatRoom(String roomId) async {
  if (_firebaseUnavailableMessage() != null) return;
  try {
    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId)
        .delete()
        .timeout(_firebaseRequestTimeout);
  } catch (e) {
    debugPrint('[ChatRoom] delete failed: $e');
  }
}

Future<void> _initFcm() async {
  try {
    print('[FCM] 1. _initFcm 시작');

    if (kIsWeb) {
      // 1. 브라우저 기본 Notification API 사용
      print('[FCM] 1-1. 웹 브라우저 권한 요청');
      final result = await html.Notification.requestPermission();
      print('[FCM] 1-2. 브라우저 권한 결과: $result');

      if (result == 'granted') {
        // 2. 권한 허용된 경우 토큰 발급
        final token = await FirebaseMessaging.instance.getToken(
          vapidKey:
              'BGo24wJvy1RQvtccNfsP1Zwu5LqStL3-XYxlkgcVQFc_jSth8lIR-cK3HfkILD4eWW3Xt8fO3mfIxD7LdgJHL2A',
        );
        print('[FCM] 1-3. 웹 토큰: $token');

        if (token != null) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await _saveFcmToken(user.uid, token);
            print('[FCM] 1-4. 웹 토큰 저장 완료');
          }
        }
      }
      return; // 웹은 여기서 종료
    }

    // 권한 요청
    print('[FCM] 2. 권한 요청 시작');
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('[FCM] 3. 권한 상태: ${settings.authorizationStatus}');

    // 토큰 발급
    print('[FCM] 4. 토큰 발급 시작');
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey:
          'BGo24wJvy1RQvtccNfsP1Zwu5LqStL3-XYxlkgcVQFc_jSth8lIR-cK3HfkILD4eWW3Xt8fO3mfIxD7LdgJHL2A',
    );
    print('[FCM] 5. 토큰: $token');

    if (token != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('[FCM] 6. 토큰 저장 시작 (UID: ${user.uid})');
        await _saveFcmToken(user.uid, token);
        print('[FCM] 7. 토큰 저장 완료');
      } else {
        print('[FCM] 6. 토큰 저장 건너뜀: 로그인된 사용자가 없음');
      }
    }
  } catch (e) {
    print('[FCM] 오류 발생: $e');
  }
}

Future<void> _saveFcmToken(String uid, String token) async {
  try {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }).timeout(_firebaseRequestTimeout);
    debugPrint('[FCM] Token saved to Firestore');
  } catch (e) {
    debugPrint('[FCM] Failed to save token: $e');
  }
}

Future<void> _notifyChatRecipients({
  required DocumentReference<Map<String, dynamic>> roomRef,
  required String senderUid,
  required String senderName,
  required String message,
}) async {
  try {
    final room = await roomRef.get().timeout(_firebaseRequestTimeout);
    final data = room.data();
    if (data == null) return;

    final participants = _stringListValue(data['participantIds']);
    final listingTitle = _stringValue(data['listingTitle'], '물품');
    final listingId = _stringValue(data['listingId'], '');
    final preview = message.length > 40
        ? '${message.substring(0, 40)}...'
        : message;

    for (final uid in participants) {
      if (uid == senderUid) continue;
      await _createUserNotification(
        recipientUid: uid,
        type: 'chat',
        title: '새 채팅 메시지',
        body: '$listingTitle · $senderName: $preview',
        actorUid: senderUid,
        listingId: listingId.isEmpty ? null : listingId,
        chatRoomId: roomRef.id,
      );
    }
  } catch (error, stackTrace) {
    debugPrint('[Notification] chat lookup failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

Future<void> _notifyFavoriteUsersOfStatusChange(
  MarketListing listing,
  String status,
) async {
  final label = _saleStatusLabel(status);
  try {
    final favorites = await FirebaseFirestore.instance
        .collectionGroup('favorites')
        .where('listingId', isEqualTo: listing.id)
        .get()
        .timeout(_firebaseRequestTimeout);

    final notifiedUserIds = <String>{};
    for (final favorite in favorites.docs) {
      final userRef = favorite.reference.parent.parent;
      final recipientUid = userRef?.id;
      if (recipientUid == null ||
          recipientUid == listing.sellerUid ||
          !notifiedUserIds.add(recipientUid)) {
        continue;
      }
      await _createUserNotification(
        recipientUid: recipientUid,
        type: 'listingStatus',
        title: '찜한 물품 상태 변경',
        body: '${listing.title}이 $label 상태로 변경되었습니다.',
        actorUid: listing.sellerUid,
        listingId: listing.id,
      );
    }
  } catch (error, stackTrace) {
    debugPrint('[Notification] status fanout failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    required this.roomId,
    this.listing,
    this.otherUserName,
    super.key,
  });

  final String roomId;
  final MarketListing? listing;
  final String? otherUserName;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _messageController = TextEditingController();
  final _messageScrollController = ScrollController();
  bool _isSending = false;
  bool _isMarkingMessagesRead = false;

  @override
  void dispose() {
    _messageController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  void _scrollMessagesToBottom({bool animated = true}) {
    if (!_messageScrollController.hasClients) return;

    final bottom = _messageScrollController.position.maxScrollExtent;
    if (animated) {
      _messageScrollController.animateTo(
        bottom,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    _messageScrollController.jumpTo(bottom);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final user = _currentUserOrNull();
    if (user == null) {
      await _openLoginScreen(context);
      return;
    }

    setState(() => _isSending = true);
    try {
      final senderName = await _fetchNicknameForUid(
        user.uid,
        displayName: user.displayName,
        email: user.email,
      );
      final roomRef = FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(widget.roomId);

      await roomRef
          .collection('messages')
          .add({
            'senderUid': user.uid,
            'senderName': senderName,
            'text': text,
            'readBy': [user.uid],
            'createdAt': FieldValue.serverTimestamp(),
          })
          .timeout(_firebaseRequestTimeout);

      await roomRef
          .update({
            'lastMessage': text,
            'lastMessageSenderUid': user.uid,
            'lastMessageAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(_firebaseRequestTimeout);

      await _notifyChatRecipients(
        roomRef: roomRef,
        senderUid: user.uid,
        senderName: senderName,
        message: text,
      );
      _messageController.clear();
    } catch (error, stackTrace) {
      debugPrint('[Chat] send failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('메시지 전송에 실패했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _markIncomingMessagesAsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String uid,
  ) async {
    if (_isMarkingMessagesRead || _firebaseUnavailableMessage() != null) {
      return;
    }

    final unreadIncomingDocs = docs.where((doc) {
      final data = doc.data();
      final senderUid = _stringValue(data['senderUid'], '');
      final readBy = _stringListValue(data['readBy']);
      return senderUid.isNotEmpty && senderUid != uid && !readBy.contains(uid);
    }).toList();
    if (unreadIncomingDocs.isEmpty) return;

    _isMarkingMessagesRead = true;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unreadIncomingDocs) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([uid]),
        });
      }
      await batch.commit().timeout(_firebaseRequestTimeout);
    } catch (error, stackTrace) {
      debugPrint('[Chat] mark read failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isMarkingMessagesRead = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUserOrNull();
    final listing = widget.listing;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName ?? '채팅'),
        actions: [
          IconButton(
            tooltip: '나가기',
            onPressed: () async {
              final user = _currentUserOrNull();
              if (user != null) {
                await _deleteChatNotifications(user.uid, widget.roomId);
              }
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            icon: const Icon(Icons.exit_to_app),
          ),
        ],
      ),
      body: Column(
        children: [
          if (listing != null) _ChatListingHeader(listing: listing),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chatRooms')
                  .doc(widget.roomId)
                  .collection('messages')
                  .orderBy('createdAt')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('메시지를 불러올 수 없습니다.'));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _scrollMessagesToBottom();
                    if (user != null) {
                      _markIncomingMessagesAsRead(docs, user.uid);
                    }
                  });
                }
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      '아직 메시지가 없습니다.',
                      style: TextStyle(color: _muted),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _messageScrollController,
                  reverse: false,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final senderUid = _stringValue(data['senderUid'], '');
                    final isMine = senderUid == user?.uid;
                    final readBy = _stringListValue(data['readBy']);
                    final isReadByOther =
                        isMine && readBy.any((uid) => uid != user?.uid);
                    return _MessageBubble(
                      text: _stringValue(data['text'], ''),
                      senderName: _stringValue(data['senderName'], ''),
                      isMine: isMine,
                      isReadByOther: isReadByOther,
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFEDEDED))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(hintText: '메시지를 입력하세요'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _sendMessage,
                    style: IconButton.styleFrom(
                      backgroundColor: _brandOrange,
                      foregroundColor: Colors.white,
                    ),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatListingHeader extends StatelessWidget {
  const _ChatListingHeader({required this.listing});

  final MarketListing listing;

  @override
  Widget build(BuildContext context) {
    final imageUrl = listing.photoUrls.isNotEmpty
        ? listing.photoUrls.first
        : null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEDEDED))),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: listing.color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: imageUrl == null
                ? Icon(listing.icon, color: Colors.white)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                      errorBuilder: (_, _, _) =>
                          Icon(listing.icon, color: Colors.white),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  listing.price,
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.senderName,
    required this.isMine,
    required this.isReadByOther,
  });

  final String text;
  final String senderName;
  final bool isMine;
  final bool isReadByOther;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isMine ? _brandOrange : _surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isMine && senderName.isNotEmpty) ...[
            Text(
              senderName,
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
          ],
          Text(text, style: TextStyle(color: isMine ? Colors.white : _ink)),
        ],
      ),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: isMine
            ? Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 5, bottom: 2),
                    child: Text(
                      isReadByOther ? '읽음' : '1',
                      style: TextStyle(
                        color: isReadByOther ? _muted : _brandOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  bubble,
                ],
              )
            : bubble,
      ),
    );
  }
}

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({
    required this.onCategorySelected,
    required this.onTypeSelected,
    super.key,
  });

  final ValueChanged<String> onCategorySelected;
  final ValueChanged<ListingType> onTypeSelected;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('카테고리')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Text(
            '중고거래',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: categories.map((category) {
              final isSelected = _selectedCategory == category;
              return ActionChip(
                label: Text(category),
                avatar: const Icon(Icons.sell_outlined, size: 18),
                backgroundColor:
                    isSelected ? _brandOrange.withValues(alpha: 0.12) : null,
                labelStyle: TextStyle(
                  color: isSelected ? _brandOrange : null,
                  fontWeight: isSelected ? FontWeight.w900 : null,
                ),
                onPressed: () {
                  widget.onCategorySelected(category);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nproject 특화 게시판',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ActionChip(
                label: Text(ListingType.request.label),
                avatar: Icon(ListingType.request.icon, size: 18),
                onPressed: () => widget.onTypeSelected(ListingType.request),
              ),
              ActionChip(
                label: Text(ListingType.currency.label),
                avatar: Icon(ListingType.currency.icon, size: 18),
                onPressed: () => widget.onTypeSelected(ListingType.currency),
              ),
            ],
          ),
          if (_selectedCategory != null) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  _selectedCategory!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _selectedCategory = null),
                  child: const Text('전체보기'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firebaseUnavailableMessage() == null
                  ? FirebaseFirestore.instance
                        .collection('listings')
                        .where('category', isEqualTo: _selectedCategory)
                        .orderBy('createdAt', descending: true)
                        .snapshots()
                  : null,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final listings = snapshot.hasData
                    ? snapshot.data!.docs.map(_listingFromDoc).toList()
                    : <MarketListing>[];
                if (listings.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        '해당 카테고리에 등록된 물품이 없습니다.',
                        style: TextStyle(color: _muted),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: listings.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: 92,
                    color: Color(0xFFEDEDED),
                  ),
                  itemBuilder: (context, index) {
                    final listing = listings[index];
                    return ListingTile(
                      listing: listing,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ListingDetailScreen(listing: listing),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class PostListingScreen extends StatefulWidget {
  const PostListingScreen({
    super.key,
    this.onSubmitSuccess,
    this.editingListingId,
    this.initialListing,
  });

  final VoidCallback? onSubmitSuccess;
  final String? editingListingId;
  final MarketListing? initialListing;

  bool get isEditing => editingListingId != null;

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
  String _tradeType = 'sell';
  String _requestType = 'need';
  String _currencyTradeType = 'sell';
  String _currencyDirection = '바트를 원화로';
  bool _isSubmitting = false;
  final List<XFile> _pickedPhotos = [];
  List<String> _existingPhotoUrls = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialListing;
    if (initial != null) {
      _prefillFromListing(initial);
      _loadEditingExtraFields();
    }
  }

  void _prefillFromListing(MarketListing listing) {
    _type = listing.type;
    _tradeType = listing.tradeType;
    _titleController.text = listing.title;
    _nameController.text = listing.itemName ?? '';
    _priceController.text = listing.price;
    _placeController.text = listing.place;
    _descriptionController.text = listing.description;
    _contactController.text = listing.contactNote ?? '';
    if (listing.type == ListingType.used &&
        categories.contains(listing.category)) {
      _category = listing.category;
    }
    if (listing.currencyDirection != null &&
        listing.currencyDirection!.isNotEmpty) {
      _currencyDirection = listing.currencyDirection!;
    }
    if (listing.exchangeRate != null && listing.exchangeRate!.isNotEmpty) {
      _exchangeRateController.text = listing.exchangeRate!;
    }
    _existingPhotoUrls = [...listing.photoUrls];
  }

  Future<void> _loadEditingExtraFields() async {
    final listingId = widget.editingListingId;
    if (listingId == null || _firebaseUnavailableMessage() != null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('listings')
          .doc(listingId)
          .get()
          .timeout(_firebaseRequestTimeout);
      if (!doc.exists || !mounted) return;

      final data = doc.data() ?? {};
      setState(() {
        _nameController.text = _stringValue(
          data['itemName'],
          _nameController.text,
        );
        final direction = data['currencyDirection']?.toString().trim();
        if (direction != null && direction.isNotEmpty) {
          _currencyDirection = direction;
        }
        final rate = data['exchangeRate']?.toString().trim();
        if (rate != null && rate.isNotEmpty) {
          _exchangeRateController.text = rate;
        }
        final contact = data['contact']?.toString().trim();
        if (contact != null && contact.isNotEmpty) {
          _contactController.text = contact;
        }
        _existingPhotoUrls = _stringListValue(data['photoUrls']);
      });
    } catch (error, stackTrace) {
      debugPrint('[PostListingScreen] load edit fields failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

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

  Map<String, Object?> _listingPayload({
    required String sellerNickname,
    required bool isUpdate,
    required User user,
    required List<String> photoUrls,
  }) {
    final title = _titleController.text.trim();
    final name = _nameController.text.trim();
    final price = _priceController.text.trim();
    final place = _placeController.text.trim();
    final description = _descriptionController.text.trim();
    final contact = _contactController.text.trim();
    final exchangeRate = _exchangeRateController.text.trim();
    final payload = <String, Object?>{
      'type': _type.name,
      'typeLabel': _type.label,
      'tradeType': _tradeType,
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
      'sellerUid': user.uid,
      'sellerEmail': user.email,
      'sellerNickname': sellerNickname,
      'status': widget.initialListing?.status ?? 'active',
      'photoUrls': photoUrls,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!isUpdate) {
      payload['createdAt'] = FieldValue.serverTimestamp();
      payload['status'] = 'active';
    }

    return payload;
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
    if (_currentUserOrNull() == null) {
      _showMessage('로그인 후 이용이 가능합니다.');
      await _openLoginScreen(context);
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
      final user = _currentUserOrNull()!;
      final uploadedPhotoUrls = await _uploadListingPhotos(
        userId: user.uid,
        listingId: widget.editingListingId,
      );
      final photoUrls = [..._existingPhotoUrls, ...uploadedPhotoUrls];
      final sellerNickname = await _fetchNicknameForUid(
        user.uid,
        displayName: user.displayName,
        email: user.email,
      );
      final isUpdate = widget.isEditing;
      final payload = _listingPayload(
        sellerNickname: sellerNickname,
        isUpdate: isUpdate,
        user: user,
        photoUrls: photoUrls,
      );

      if (isUpdate) {
        debugPrint(
          '[PostListingScreen] Firestore update start: listings/${widget.editingListingId}',
        );
        await FirebaseFirestore.instance
            .collection('listings')
            .doc(widget.editingListingId)
            .update(payload)
            .timeout(_firebaseRequestTimeout);
        debugPrint('[PostListingScreen] Firestore update success');

        if (!mounted) return;
        _showMessage('${_type.label} 글이 수정되었습니다.');
        Navigator.of(context).pop(true);
        return;
      }

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
      _pickedPhotos.clear();
      _existingPhotoUrls = const [];
      setState(() {
        _category = categories.first;
        _currencyDirection = '바트를 원화로';
      });
      _showMessage('${_type.label} 글이 등록되었습니다.');
      widget.onSubmitSuccess?.call();
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

  Future<List<String>> _uploadListingPhotos({
    required String userId,
    String? listingId,
  }) async {
    if (_pickedPhotos.isEmpty) return const [];

    final resolvedListingId =
        listingId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final uploadedUrls = <String>[];
    for (var i = 0; i < _pickedPhotos.length; i++) {
      final file = _pickedPhotos[i];
      final bytes = await file.readAsBytes();
      final ref = FirebaseStorage.instance.ref().child(
        'listings/$userId/$resolvedListingId/${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
      );
      await ref
          .putData(bytes, SettableMetadata(contentType: 'image/jpeg'))
          .timeout(_firebaseRequestTimeout);
      uploadedUrls.add(
        await ref.getDownloadURL().timeout(_firebaseRequestTimeout),
      );
    }
    return uploadedUrls;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEditing;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? '글 수정' : '글 등록')),
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
              onSelectionChanged: _isSubmitting || isEditing
                  ? null
                  : (value) => setState(() => _type = value.first),
            ),
            const SizedBox(height: 18),

            if (_type == ListingType.used) ...[
              const _InputLabel('거래유형'),

              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'sell',
                    label: Text('팝니다'),
                    icon: Icon(Icons.sell_outlined),
                  ),
                  ButtonSegment(
                    value: 'buy',
                    label: Text('삽니다'),
                    icon: Icon(Icons.shopping_cart_outlined),
                  ),
                ],
                selected: {_tradeType},
                onSelectionChanged: (value) {
                  setState(() {
                    _tradeType = value.first;
                  });
                },
              ),

              const SizedBox(height: 18),

              _UsedListingForm(
                tradeType: _tradeType,
                titleController: _titleController,
                itemController: _nameController,
                priceController: _priceController,
                placeController: _placeController,
                descriptionController: _descriptionController,
                category: _category,
                onCategoryChanged: (value) => setState(() => _category = value),
                onPhotosChanged: (files) {
                  _pickedPhotos
                    ..clear()
                    ..addAll(files);
                },
                initialPhotoUrls: _existingPhotoUrls,
                validator: _required,
              ),
            ],
            if (_type == ListingType.request) ...[
              const _InputLabel('서비스 유형'),

              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'need',
                    label: Text('해주세요'),
                    icon: Icon(Icons.help_outline),
                  ),
                  ButtonSegment(
                    value: 'offer',
                    label: Text('해드려요'),
                    icon: Icon(Icons.volunteer_activism_outlined),
                  ),
                ],
                selected: {_requestType},
                onSelectionChanged: (value) {
                  setState(() {
                    _requestType = value.first;
                  });
                },
              ),

              const SizedBox(height: 18),

              _DeliveryRequestForm(
                requestType: _requestType,
                titleController: _titleController,
                itemController: _nameController,
                feeController: _priceController,
                contactController: _contactController,
                descriptionController: _descriptionController,
                validator: _required,
              ),
            ],
            if (_type == ListingType.currency) ...[
              const _InputLabel('거래 방향'),

              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'sell',
                    label: Text('바트 판매'),
                    icon: Icon(Icons.trending_up),
                  ),
                  ButtonSegment(
                    value: 'buy',
                    label: Text('바트 구매'),
                    icon: Icon(Icons.trending_down),
                  ),
                ],
                selected: {_currencyTradeType},
                onSelectionChanged: (value) {
                  setState(() {
                    _currencyTradeType = value.first;
                  });
                },
              ),

              const SizedBox(height: 18),

              _CurrencyExchangeForm(
                tradeType: _currencyTradeType,
                titleController: _titleController,
                amountController: _priceController,
                rateController: _exchangeRateController,
                placeController: _placeController,
                methodController: _descriptionController,
                validator: _required,
              ),
            ],
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
                  : Text(
                      isEditing ? '${_type.label} 수정하기' : '${_type.label} 등록하기',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsedListingForm extends StatelessWidget {
  const _UsedListingForm({
    required this.tradeType,
    required this.titleController,
    required this.itemController,
    required this.priceController,
    required this.placeController,
    required this.descriptionController,
    required this.category,
    required this.onCategoryChanged,
    required this.onPhotosChanged,
    this.initialPhotoUrls = const [],
    required this.validator,
  });
  final String tradeType;
  final TextEditingController titleController;
  final TextEditingController itemController;
  final TextEditingController priceController;
  final TextEditingController placeController;
  final TextEditingController descriptionController;
  final String category;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<List<XFile>> onPhotosChanged;
  final List<String> initialPhotoUrls;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PhotoPickerMock(
          onChanged: onPhotosChanged,
          initialPhotoUrls: initialPhotoUrls,
        ),
        const SizedBox(height: 22),
        const _InputLabel('제목'),
        TextFormField(
          controller: titleController,
          validator: validator,
          decoration: InputDecoration(
            hintText: tradeType == 'buy'
                ? '예: 아이폰 15 Pro 삽니다'
                : '예: 아이폰 14 프로 판매합니다',
          ),
        ),
        const SizedBox(height: 18),
        const _InputLabel('제품명'),
        TextFormField(
          controller: itemController,
          validator: validator,
          decoration: InputDecoration(
            hintText: tradeType == 'buy'
                ? '예: 원하는 모델명 입력'
                : '예: 아이폰 14 프로 256GB',
          ),
        ),
        const SizedBox(height: 18),
        _InputLabel(tradeType == 'buy' ? '희망 구매 가격' : '판매 가격'),
        TextFormField(
          controller: priceController,
          validator: validator,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: tradeType == 'buy' ? '희망 구매 금액 입력' : 'THB 또는 KRW 금액 입력',
          ),
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
          decoration: InputDecoration(
            hintText: tradeType == 'buy'
                ? '원하는 상태, 색상, 용량 등을 적어주세요.'
                : '상태, 구매 시기, 전달 가능 시간 등을 자세히 적어주세요.',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

class _DeliveryRequestForm extends StatelessWidget {
  const _DeliveryRequestForm({
    required this.requestType,
    required this.titleController,
    required this.itemController,
    required this.feeController,
    required this.contactController,
    required this.descriptionController,
    required this.validator,
  });

  final String requestType;

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
          decoration: InputDecoration(
            hintText: requestType == 'offer'
                ? '예: 한국 물품 전달 가능합니다'
                : '예: 영양제 전달 부탁드립니다',
          ),
        ),
        const SizedBox(height: 18),
        const _InputLabel('물품명'),
        TextFormField(
          controller: itemController,
          validator: validator,
          decoration: const InputDecoration(hintText: '배달 원하는 물품을 기재하세요.'),
        ),
        const SizedBox(height: 18),
        _InputLabel(requestType == 'offer' ? '희망 수수료' : '수수료 제안'),
        TextFormField(
          controller: feeController,
          validator: validator,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: requestType == 'offer' ? '예: 500 THB' : '예: 700 THB',
          ),
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
          decoration: InputDecoration(
            hintText: requestType == 'offer'
                ? '가능한 날짜, 출발지/도착지, 수하물 여유 공간 등을 적어주세요.'
                : '부탁할 물건의 종류, 수량, 전달 희망 장소 등을 적어주세요.',
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
    required this.tradeType,
    required this.titleController,
    required this.amountController,
    required this.rateController,
    required this.placeController,
    required this.methodController,
    required this.validator,
  });

  final String tradeType;
  final TextEditingController titleController;
  final TextEditingController amountController;
  final TextEditingController rateController;
  final TextEditingController placeController;
  final TextEditingController methodController;
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
          decoration: InputDecoration(
            hintText: tradeType == 'buy'
                ? '예: 바트 10,000 THB 구매 원합니다'
                : '예: 바트 5,000 THB 판매합니다',
          ),
        ),
        const SizedBox(height: 18),
        const _InputLabel('원하는 화폐'),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(tradeType == 'buy' ? '원화를 바트로' : '바트를 원화로'),
        ),

        const SizedBox(height: 18),
        _InputLabel(tradeType == 'buy' ? '구매 희망 금액' : '판매 금액'),
        TextFormField(
          controller: amountController,
          validator: validator,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: tradeType == 'buy' ? '예: 10,000 THB' : '예: 5,000 THB',
          ),
        ),
        const SizedBox(height: 18),
        const _InputLabel('적용 환율'),
        TextFormField(
          controller: rateController,
          validator: validator,
          decoration: InputDecoration(
            hintText: tradeType == 'buy' ? '예: 네이버 살때 기준' : '예: 네이버 팔때 기준',
          ),
        ),
        const SizedBox(height: 18),
        const _InputLabel('거래 희망 장소'),
        TextFormField(
          controller: placeController,
          validator: validator,
          decoration: InputDecoration(
            hintText: tradeType == 'buy' ? '예: 방콕 BTS 역 근처' : '예: 파타야 터미널21 근처',
          ),
        ),
        const SizedBox(height: 18),
        const _InputLabel('거래방법'),
        TextFormField(
          controller: methodController,
          validator: validator,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: tradeType == 'buy'
                ? '예: 한국 계좌 이체 후 바트 현금 수령 희망'
                : '예: 바트 현금 전달 후 한국 계좌 입금 희망',
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

  // 약관 동의 상태
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _agreeNotice = false;
  bool _agreeMarketing = false;

  bool get _allRequiredAgreed => _agreeTerms && _agreePrivacy && _agreeNotice;
  bool get _isAllAgreed => _allRequiredAgreed && _agreeMarketing;

  void _toggleAll(bool? value) {
    setState(() {
      _agreeTerms = value ?? false;
      _agreePrivacy = value ?? false;
      _agreeNotice = value ?? false;
      _agreeMarketing = value ?? false;
    });
  }

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

    if (!_allRequiredAgreed) {
      _showMessage('필수 약관에 모두 동의해주세요.');
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
            'termsAccepted': true,
            'privacyAccepted': true,
            'noticeAccepted': true,
            'marketingAccepted': _agreeMarketing,
            'acceptedAt': FieldValue.serverTimestamp(),
            'termsVersion': '1.0',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(_firebaseRequestTimeout);
      debugPrint('[AuthScreen] signup success: ${user.uid}');

      if (!mounted) return;
      final signedIn = _currentUserOrNull() != null;
      if (signedIn) {
        _showMessage('회원가입이 완료되었습니다. 로그인되었습니다.');
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        _showMessage('회원가입이 완료되었습니다. 로그인해주세요.');
        await _openLoginScreen(context);
      }
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
            const _InputLabel('닉네임', isRequired: true),
            TextFormField(
              controller: _nicknameController,
              validator: _required,
              decoration: const InputDecoration(hintText: '앱에 표시될 이름'),
            ),
            const SizedBox(height: 18),
            const _InputLabel('이메일 ID', isRequired: true),
            TextFormField(
              controller: _emailController,
              validator: _emailValidator,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'example@email.com'),
            ),
            const SizedBox(height: 18),
            const _InputLabel('비밀번호', isRequired: true),
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
            const SizedBox(height: 32),
            const Text(
              '약관 동의',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFEDEDED)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  CheckboxListTile(
                    title: const Text('전체 동의', style: TextStyle(fontWeight: FontWeight.bold)),
                    value: _isAllAgreed,
                    onChanged: _toggleAll,
                    activeColor: _brandOrange,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const Divider(height: 1),
                  _TermsAccordion(
                    title: '[필수] 서비스 이용약관 동의',
                    content: _serviceTermsText,
                    value: _agreeTerms,
                    onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                  ),
                  _TermsAccordion(
                    title: '[필수] 개인정보 처리방침 동의',
                    content: _privacyPolicyText,
                    value: _agreePrivacy,
                    onChanged: (v) => setState(() => _agreePrivacy = v ?? false),
                  ),
                  _TermsAccordion(
                    title: '[필수] 거래 주의사항 동의',
                    content: _transactionNoticeText,
                    value: _agreeNotice,
                    onChanged: (v) => setState(() => _agreeNotice = v ?? false),
                  ),
                  _TermsAccordion(
                    title: '[선택] 마케팅 정보 수신 동의',
                    content: _marketingConsentText,
                    value: _agreeMarketing,
                    onChanged: (v) => setState(() => _agreeMarketing = v ?? false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed:
                  _isSubmitting || !_allRequiredAgreed ? null : _submitSignUp,
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

class _RecentNotificationsSection extends StatelessWidget {
  const _RecentNotificationsSection({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '최근 알림',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFEDEDED)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('notifications')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('최근 알림이 없습니다.', style: TextStyle(color: _muted)),
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < docs.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: Color(0xFFEDEDED)),
                    _NotificationTile(notification: docs[i]),
                  ],
                ],
              );
            },
          ),
        ),
      ],
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
              if (user != null) ...[
                _RecentNotificationsSection(user: user),
                const SizedBox(height: 18),
              ],
              if (user == null) ...[
                FilledButton.icon(
                  onPressed: () => _openLoginScreen(context),
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

  bool _isGoogleSubmitting = false;

Future<void> _signInWithGoogle() async {
  final unavailableMessage = _firebaseUnavailableMessage();
  if (unavailableMessage != null) {
    _showMessage(unavailableMessage);
    return;
  }
  setState(() => _isGoogleSubmitting = true);
  try {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return; // 사용자가 취소
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    final user = userCredential.user;

    if (user != null && mounted) {
      // Firestore에서 약관 동의 여부 확인
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(_firebaseRequestTimeout);

      if (!mounted) return;

      final data = userDoc.data();
      if (data == null || data['termsAccepted'] != true) {
        // 약관 미동의 시 동의 화면으로 이동
        final agreed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => TermsAgreementScreen(user: user)),
        );
        if (agreed != true && mounted) {
          // 동의 안 하고 이탈 시 로그아웃 처리
          await FirebaseAuth.instance.signOut();
          _showMessage('약관에 동의해야 서비스 이용이 가능합니다.');
          return;
        }
      }
    }

    if (!mounted) return;
    _showMessage('구글 로그인되었습니다.');
    Navigator.of(context).pop();
  } on FirebaseAuthException catch (e) {
    _showMessage(_firebaseMessage(e));
  } catch (e) {
    _showMessage('구글 로그인에 실패했습니다.');
  } finally {
    if (mounted) setState(() => _isGoogleSubmitting = false);
  }
}

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
      appBar: AppBar(title: const Text('로그인 / 회원가입')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  'assets/images/login.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              validator: _required,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: '아이디'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              validator: _required,
              obscureText: true,
              decoration: const InputDecoration(hintText: '패스워드'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _isSubmitting ? null : _submitLogin,
              style: FilledButton.styleFrom(
                backgroundColor: _brandOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AuthScreen())),
                style: TextButton.styleFrom(
                  foregroundColor: _ink,
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: const Text('아직 계정이 없나요? 회원가입'),
              ),
            ),
            const SizedBox(height: 16),
const Row(
  children: [
    Expanded(child: Divider()),
    Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Text('또는', style: TextStyle(color: _muted, fontSize: 13)),
    ),
    Expanded(child: Divider()),
  ],
),
const SizedBox(height: 16),
OutlinedButton.icon(
  onPressed: _isGoogleSubmitting ? null : _signInWithGoogle,
  style: OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 14),
    side: const BorderSide(color: Color(0xFFDDDDDD)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  ),
  icon: _isGoogleSubmitting
      ? const SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : SvgPicture.asset(
          'assets/images/google.svg',
          width: 20, height: 20,
        ),
  label: const Text('Google로 계속하기', style: TextStyle(color: _ink)),
),
          ],
        ),
      ),
    );
  }
}

void _showContactSupport(BuildContext context) {
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
              '고객센터',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text('아래 채널로 문의해주세요.', style: TextStyle(color: _muted)),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.chat_bubble_outline,
                color: _brandOrange,
              ),
              title: const Text('카카오톡 문의'),
              subtitle: const Text('오픈채팅으로 문의하기'),
              onTap: () async {
                final uri = Uri.parse(
                  'https://open.kakao.com/o/sftQLozi',
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.chat_outlined, color: _brandOrange),
              title: const Text('라인 문의'),
              subtitle: const Text('라인으로 문의하기'),
              onTap: () async {
                final uri = Uri.parse('https://line.me/ti/g2/-CCiaKCx87hclDxnFulTVvqLKshaAOdn0NtXnQ?utm_source=invitation&utm_medium=link_copy&utm_campaign=default');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
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
            icon: Icons.headset_mic_outlined,
            title: '고객센터',
            subtitle: '카카오톡 또는 라인으로 문의',
            onTap: () => _showContactSupport(context),
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
            onPressed: () => _openLoginScreen(context),
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
  const _PhotoPickerMock({
    required this.onChanged,
    this.initialPhotoUrls = const [],
  });

  final ValueChanged<List<XFile>> onChanged;
  final List<String> initialPhotoUrls;

  @override
  State<_PhotoPickerMock> createState() => _PhotoPickerMockState();
}

class _PhotoPickerMockState extends State<_PhotoPickerMock> {
  final ImagePicker _picker = ImagePicker();
  final List<Uint8List> _photos = [];
  final List<XFile> _pickedFiles = [];

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
    _pickedFiles.addAll(picked.take(remaining));
    widget.onChanged(_pickedFiles);
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
                    Text(
                      '${widget.initialPhotoUrls.length + _photos.length}/5',
                    ),
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
        if (widget.initialPhotoUrls.isNotEmpty || _photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                if (index < widget.initialPhotoUrls.length) {
                  final imageUrl = widget.initialPhotoUrls[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 76,
                        height: 76,
                        color: const Color(0xFFEDEDED),
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  );
                }

                final localIndex = index - widget.initialPhotoUrls.length;
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _photos[localIndex],
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () {
                          setState(() => _photos.removeAt(localIndex));
                          _pickedFiles.removeAt(localIndex);
                          widget.onChanged(_pickedFiles);
                        },
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
                );
              },
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: widget.initialPhotoUrls.length + _photos.length,
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
                  user == null ? displayName : '$displayName 님',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MyChatRoomsSection(userId: user!.uid),
        const SizedBox(height: 18),
        _MySellingListingsSection(userId: user!.uid),
        const SizedBox(height: 18),
        _MyFavoritesListSection(userId: user!.uid),
      ],
    );
  }
}

MarketListing? _findSampleListingById(String id) {
  for (final listing in sampleListings) {
    if (listing.id == id) return listing;
  }
  return null;
}

Future<MarketListing?> _findListingById(String id) async {
  final sample = _findSampleListingById(id);
  if (sample != null) return sample;

  if (_firebaseUnavailableMessage() != null) return null;

  try {
    final doc = await FirebaseFirestore.instance
        .collection('listings')
        .doc(id)
        .get()
        .timeout(_firebaseRequestTimeout);
    if (!doc.exists || doc.data() == null) return null;
    return _listingFromFirestoreData(doc.id, doc.data()!);
  } catch (error, stackTrace) {
    debugPrint('[ListingLookup] failed for $id: $error');
    debugPrintStack(stackTrace: stackTrace);
    return null;
  }
}

Future<List<MarketListing>> _loadListingsByIds(List<String> ids) async {
  final listings = <MarketListing>[];
  for (final id in ids) {
    final listing = await _findListingById(id);
    if (listing != null) listings.add(listing);
  }
  return listings;
}

Future<void> _toggleFavorite(BuildContext context, String listingId) async {
  final user = _currentUserOrNull();
  if (user == null) {
    await _openLoginScreen(context);
    return;
  }

  final unavailableMessage = _firebaseUnavailableMessage();
  if (unavailableMessage != null) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(unavailableMessage)));
    }
    return;
  }

  final ref = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('favorites')
      .doc(listingId);

  try {
    final doc = await ref.get().timeout(_firebaseRequestTimeout);
    if (doc.exists) {
      await ref.delete().timeout(_firebaseRequestTimeout);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('찜 목록에서 제거했습니다.')));
      }
    } else {
      await ref
          .set({
            'listingId': listingId,
            'createdAt': FieldValue.serverTimestamp(),
          })
          .timeout(_firebaseRequestTimeout);
      final listing = await _findListingById(listingId);
      final sellerUid = listing?.sellerUid?.trim();
      if (listing != null &&
          sellerUid != null &&
          sellerUid.isNotEmpty &&
          sellerUid != user.uid) {
        await _createUserNotification(
          recipientUid: sellerUid,
          type: 'favorite',
          title: '새 찜 알림',
          body: '${listing.title}을 다른 사용자가 찜했습니다.',
          actorUid: user.uid,
          listingId: listing.id,
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('찜 목록에 추가했습니다.')));
      }
    }
  } catch (error, stackTrace) {
    debugPrint('[Favorite] toggle failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('찜하기 처리에 실패했습니다.')));
    }
  }
}

class _FavoriteBottomButton extends StatelessWidget {
  const _FavoriteBottomButton({required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context) {
    final user = _currentUserOrNull();

    Widget buildButton({required bool isFavorite}) {
      return OutlinedButton.icon(
        onPressed: () => _toggleFavorite(context, listingId),
        style: OutlinedButton.styleFrom(
          foregroundColor: isFavorite ? _brandOrange : _ink,
          side: BorderSide(
            color: isFavorite ? _brandOrange : const Color(0xFFEDEDED),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        icon: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          size: 18,
        ),
        label: Text(isFavorite ? '찜함' : '찜하기'),
      );
    }

    if (user == null || _firebaseUnavailableMessage() != null) {
      return buildButton(isFavorite: false);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(listingId)
          .snapshots(),
      builder: (context, snapshot) {
        final isFavorite = snapshot.data?.exists ?? false;
        return buildButton(isFavorite: isFavorite);
      },
    );
  }
}

class _MyChatRoomsSection extends StatelessWidget {
  const _MyChatRoomsSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    if (_firebaseUnavailableMessage() != null) {
      return const _ChatRoomsPanel(
        rooms: [],
        emptyText: 'Firebase 연결 후 채팅 목록을 확인할 수 있습니다.',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chatRooms')
          .where('participantIds', arrayContains: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ChatRoomsPanel(rooms: [], isLoading: true);
        }
        if (snapshot.hasError) {
          debugPrint('[ChatRooms] ${snapshot.error}');
          return const _ChatRoomsPanel(
            rooms: [],
            emptyText: '채팅 목록을 불러오지 못했습니다.',
          );
        }

        final rooms = snapshot.data?.docs.toList() ?? [];
        rooms.sort((a, b) {
          final aTime = _timestampMillis(a.data()['updatedAt']);
          final bTime = _timestampMillis(b.data()['updatedAt']);
          return bTime.compareTo(aTime);
        });

        return _ChatRoomsPanel(rooms: rooms);
      },
    );
  }
}

class _ChatRoomsPanel extends StatelessWidget {
  const _ChatRoomsPanel({
    required this.rooms,
    this.emptyText = '진행 중인 채팅이 없습니다.',
    this.isLoading = false,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> rooms;
  final String emptyText;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '채팅 목록',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFEDEDED)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                )
              : rooms.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(emptyText, style: const TextStyle(color: _muted)),
                )
              : Column(
                  children: [
                    for (var i = 0; i < rooms.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, color: Color(0xFFEDEDED)),
                      _ChatRoomTile(room: rooms[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _ChatRoomTile extends StatelessWidget {
  const _ChatRoomTile({required this.room});

  final QueryDocumentSnapshot<Map<String, dynamic>> room;

  @override
  Widget build(BuildContext context) {
    final data = room.data();
    final currentUid = _currentUserOrNull()?.uid;
    final sellerUid = _stringValue(data['sellerUid'], '');
    final sellerName = _stringValue(data['sellerNickname'], '판매자');
    final buyerName = _stringValue(data['buyerNickname'], '구매자');
    final otherName = currentUid == sellerUid ? buyerName : sellerName;
    final listingTitle = _stringValue(data['listingTitle'], '물품');
    final lastMessage = _stringValue(data['lastMessage'], '아직 메시지가 없습니다.');
    final imageUrl = _stringValue(data['listingPhotoUrl'], '');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: imageUrl.isEmpty
            ? const Icon(Icons.chat_bubble_outline, color: _muted)
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.chat_bubble_outline, color: _muted),
                ),
              ),
      ),
      title: Text(
        '$otherName · $listingTitle',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _muted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: _muted),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('채팅방 삭제'),
                  content: const Text('채팅방을 삭제하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('삭제'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _deleteChatRoom(room.id);
              }
            },
          ),
          const Icon(Icons.chevron_right, color: _muted),
        ],
      ),
      onTap: () async {
        final listingId = _stringValue(data['listingId'], '');
        final listing = listingId.isEmpty
            ? null
            : await _findListingById(listingId);
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              roomId: room.id,
              listing: listing,
              otherUserName: otherName,
            ),
          ),
        );
      },
    );
  }
}

class _MyPageListingSection extends StatelessWidget {
  const _MyPageListingSection({
    required this.title,
    required this.listings,
    this.emptyText = '표시할 물품이 없습니다.',
    this.isLoading = false,
  });

  final String title;
  final List<MarketListing> listings;
  final String emptyText;
  final bool isLoading;

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
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFEDEDED)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                )
              : listings.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(emptyText, style: const TextStyle(color: _muted)),
                )
              : Column(
                  children: [
                    for (var i = 0; i < listings.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, color: Color(0xFFEDEDED)),
                      _MyPageListingTile(listing: listings[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _MyPageListingTile extends StatelessWidget {
  const _MyPageListingTile({required this.listing});

  final MarketListing listing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ListingDetailScreen(listing: listing),
        ),
      ),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: listing.color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: listing.photoUrls.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  listing.photoUrls.first,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Icon(listing.icon, color: Colors.white, size: 22),
                ),
              )
            : Icon(listing.icon, color: Colors.white, size: 22),
      ),
      title: Text(
        listing.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${listing.price} · ${listing.place}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _muted, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: _muted),
    );
  }
}

class _MySellingListingsSection extends StatelessWidget {
  const _MySellingListingsSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    if (_firebaseUnavailableMessage() != null) {
      return const _MyPageListingSection(
        title: '판매중인 물품 목록',
        listings: [],
        emptyText: 'Firebase 연결 후 등록한 물품을 확인할 수 있습니다.',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // Keep query index-light: sellerUid filter only.
      stream: FirebaseFirestore.instance
          .collection('listings')
          .where('sellerUid', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _MyPageListingSection(
            title: '판매중인 물품 목록',
            listings: [],
            isLoading: true,
          );
        }

        if (snapshot.hasError) {
          debugPrint('[MySellingListings] ${snapshot.error}');
          return _MyPageListingSection(
            title: '판매중인 물품 목록',
            listings: const [],
            emptyText: '등록한 물품을 불러오지 못했습니다. (${snapshot.error})',
          );
        }

        final listings =
            (snapshot.data?.docs.map(_listingFromDoc).toList() ??
                    <MarketListing>[])
                .where((listing) => listing.status != 'sold')
                .toList();

        return _MyPageListingSection(
          title: '판매중인 물품 목록',
          listings: listings,
          emptyText: '등록한 물품이 없습니다.',
        );
      },
    );
  }
}

class _MyFavoritesListSection extends StatelessWidget {
  const _MyFavoritesListSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    if (_firebaseUnavailableMessage() != null) {
      return const _MyPageListingSection(
        title: '내가 찜한 리스트',
        listings: [],
        emptyText: 'Firebase 연결 후 찜한 물품을 확인할 수 있습니다.',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _MyPageListingSection(
            title: '내가 찜한 리스트',
            listings: [],
            isLoading: true,
          );
        }

        if (snapshot.hasError) {
          debugPrint('[MyFavoritesList] ${snapshot.error}');
          return const _MyPageListingSection(
            title: '내가 찜한 리스트',
            listings: [],
            emptyText: '찜한 물품을 불러오지 못했습니다.',
          );
        }

        final favoriteIds =
            snapshot.data?.docs.map((doc) => doc.id).toList() ?? [];

        if (favoriteIds.isEmpty) {
          return const _MyPageListingSection(
            title: '내가 찜한 리스트',
            listings: [],
            emptyText: '찜한 물품이 없습니다.',
          );
        }

        return FutureBuilder<List<MarketListing>>(
          key: ValueKey(favoriteIds.join(',')),
          future: _loadListingsByIds(favoriteIds),
          builder: (context, listingSnapshot) {
            if (listingSnapshot.connectionState == ConnectionState.waiting) {
              return const _MyPageListingSection(
                title: '내가 찜한 리스트',
                listings: [],
                isLoading: true,
              );
            }

            final listings = listingSnapshot.data ?? [];

            return _MyPageListingSection(
              title: '내가 찜한 리스트',
              listings: listings,
              emptyText: '찜한 물품 정보를 찾을 수 없습니다.',
            );
          },
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
          width: double.infinity,
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
  const _InputLabel(this.text, {this.isRequired = false});

  final String text;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          if (isRequired)
            const Text(
              ' (필수)',
              style: TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
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
  const _TradeLocationText({required this.value, this.label = '거래 희망 장소'});

  final String value;
  final String label;

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
          Text(label, style: TextStyle(color: _muted)),
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

List<String> _stringListValue(Object? value) {
  if (value is! List) return const [];
  final result = <String>[];
  for (final item in value) {
    final text = item?.toString().trim() ?? '';
    if (text.isNotEmpty) result.add(text);
  }
  return result;
}

int _timestampMillis(Object? value) {
  if (value is Timestamp) return value.millisecondsSinceEpoch;
  return 0;
}

final _sellerNicknameCache = <String, String>{};

bool _needsSellerNicknameLookup(MarketListing listing) {
  final nickname = listing.sellerNickname.trim();
  return nickname.isEmpty || nickname == '익명';
}

Future<String> _fetchNicknameForUid(
  String uid, {
  String? displayName,
  String? email,
  String fallback = '익명',
}) async {
  if (displayName?.trim().isNotEmpty == true) {
    final name = displayName!.trim();
    _sellerNicknameCache[uid] = name;
    return name;
  }

  final cached = _sellerNicknameCache[uid];
  if (cached != null && cached.isNotEmpty) {
    return cached;
  }

  if (_firebaseUnavailableMessage() != null) {
    return fallback;
  }

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get()
        .timeout(_firebaseRequestTimeout);
    final data = doc.data();
    final nickname = _stringValue(data?['nickname'], '');
    if (nickname.isNotEmpty) {
      _sellerNicknameCache[uid] = nickname;
      return nickname;
    }
    final name = _stringValue(data?['name'], '');
    if (name.isNotEmpty) {
      _sellerNicknameCache[uid] = name;
      return name;
    }
  } catch (error, stackTrace) {
    debugPrint('[SellerNickname] lookup failed for $uid: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  if (email?.trim().isNotEmpty == true) {
    return email!.trim();
  }
  return fallback;
}

Future<String> _resolveSellerNickname(MarketListing listing) async {
  if (!_needsSellerNicknameLookup(listing)) {
    return listing.sellerNickname;
  }

  final sellerUid = listing.sellerUid?.trim();
  if (sellerUid == null || sellerUid.isEmpty) {
    return listing.sellerNickname;
  }

  return _fetchNicknameForUid(sellerUid, fallback: listing.sellerNickname);
}

class _SellerTradeLine extends StatelessWidget {
  const _SellerTradeLine({required this.listing});

  final MarketListing listing;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: _muted, fontSize: 12);
    final text = '${listing.sellerNickname} · 거래 ${listing.tradeCount}회';

    if (!_needsSellerNicknameLookup(listing) ||
        listing.sellerUid?.trim().isNotEmpty != true) {
      return Text(text, style: style);
    }

    return FutureBuilder<String>(
      future: _resolveSellerNickname(listing),
      builder: (context, snapshot) {
        final nickname = snapshot.data ?? listing.sellerNickname;
        return Text('$nickname · 거래 ${listing.tradeCount}회', style: style);
      },
    );
  }
}

ListingType _listingTypeFromValue(Object? value) {
  final name = value?.toString();
  return ListingType.values.firstWhere(
    (type) => type.name == name,
    orElse: () => ListingType.used,
  );
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

MarketListing _listingFromFirestoreData(String id, Map<String, dynamic> data) {
  final type = _listingTypeFromValue(data['type']);
  final place = _stringValue(data['place'], '위치 미입력');
  final seller = _stringValue(data['sellerNickname'], '익명');
  final sellerUid = _stringValue(data['sellerUid'], '');
  final photoUrls = _stringListValue(data['photoUrls']);

  return MarketListing(
    id: id,
    type: type,
    title: _stringValue(data['title'], '제목 없음'),
    category: _stringValue(data['category'], type.label),
    price: _stringValue(data['price'], '가격 미입력'),
    place: place,
    placeNote: place,
    postedAgo: _getTimeAgo(data['createdAt']),
    sellerNickname: seller,
    sellerUid: sellerUid.isEmpty ? null : sellerUid,
    status: _stringValue(data['status'], 'active'),
    itemName: () {
      final name = _stringValue(data['itemName'], '');
      return name.isEmpty ? null : name;
    }(),
    currencyDirection: () {
      final value = data['currencyDirection']?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }(),
    exchangeRate: () {
      final value = data['exchangeRate']?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }(),
    photoUrls: photoUrls,
    photoCount: photoUrls.isNotEmpty ? photoUrls.length : 1,
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

MarketListing _listingFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  return _listingFromFirestoreData(doc.id, doc.data());
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
    this.tradeType = 'sell',
    required this.title,
    required this.category,
    required this.price,
    required this.place,
    required this.placeNote,
    required this.postedAgo,
    required this.sellerNickname,
    this.sellerUid,
    this.status = 'active',
    this.itemName,
    this.currencyDirection,
    this.exchangeRate,
    this.photoUrls = const [],
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
  final String tradeType;
  final String title;
  final String category;
  final String price;
  final String place;
  final String placeNote;
  final String postedAgo;
  final String sellerNickname;
  final String? sellerUid;
  final String status;
  final String? itemName;
  final String? currencyDirection;
  final String? exchangeRate;
  final List<String> photoUrls;
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
  '전체보기',
  '디지털기기',
  '생활가전',
  '의류 / 잡화',
  '가구 / 인테리어',
  '자동차 / 바이크',
  '차량 용품',
  '스포츠 / 레저',
  '도서 / 티켓 / 취미',
  '킵카드',
  '회원권',
  '기타 중고물품',
];

const sampleListings = <MarketListing>[];

// --- 약관 전문 상수 ---

const _serviceTermsText = """
제1조 (목적)
본 약관은 서비스 제공자가 운영하는 플랫폼 서비스의 이용과 관련하여 서비스 제공자와 회원 간의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.

제2조 (회원가입)
회원은 본 약관에 동의한 후 회원가입 절차를 완료함으로써 서비스를 이용할 수 있습니다.

제3조 (서비스 제공)
본 서비스는 여행, 교통, 골프, 관광, 숙박, 맛집, 중고거래, 커뮤니티 및 기타 관련 정보를 제공하는 온라인 플랫폼입니다.

제4조 (회원의 의무)
회원은 다음 행위를 하여서는 안 됩니다.
* 허위 정보 등록
* 타인 정보 도용
* 서비스 운영 방해 행위
* 법령 위반 행위
* 사기 또는 기만 행위
* 타 회원에게 피해를 주는 행위

제5조 (서비스 변경 및 중단)
서비스 제공자는 운영상 또는 기술상의 필요에 따라 서비스의 일부 또는 전부를 변경하거나 중단할 수 있습니다.

제6조 (면책)
서비스는 플랫폼 제공자이며 회원 간 거래의 당사자가 아닙니다.
회원 간 거래, 예약, 계약, 결제 및 분쟁에 대해서는 해당 회원이 책임을 부담합니다.
""";

const _privacyPolicyText = """
1. 수집하는 개인정보
서비스는 다음 정보를 수집할 수 있습니다.
* 이름 또는 닉네임
* 이메일 주소
* 휴대전화 번호
* 프로필 사진
* 로그인 정보
* 기기 정보
* IP 주소
* 서비스 이용 기록
* 예약 및 거래 기록

2. 개인정보 수집 목적
수집된 개인정보는 다음 목적에 사용됩니다.
* 회원 식별 및 본인 확인
* 서비스 제공 및 운영
* 예약 및 거래 처리
* 고객 문의 응대
* 서비스 개선
* 부정 이용 방지
* 법령상 의무 이행

3. 개인정보 보관 기간
개인정보는 회원 탈퇴 시 원칙적으로 삭제됩니다.
단, 관련 법령에 따라 일정 기간 보관이 필요한 경우 해당 기간 동안 보관될 수 있습니다.

4. 개인정보 제공
서비스는 이용자의 동의 없이 개인정보를 제3자에게 판매하거나 제공하지 않습니다.
다만 법령에 따른 요청이 있는 경우 제공될 수 있습니다.

5. 개인정보 보호
서비스는 개인정보 보호를 위하여 합리적인 보안 조치를 시행합니다.
""";

const _transactionNoticeText = """
본 서비스는 회원 간 거래, 예약, 정보 공유 및 연결을 위한 플랫폼입니다.
서비스 운영자는 거래의 당사자가 아니며 거래에 직접 개입하지 않습니다.
회원은 거래 전 상대방의 신원, 상품 상태, 서비스 내용, 예약 조건, 결제 조건 및 기타 거래 정보를 직접 확인하여야 합니다.

다음 사항에 대한 책임은 거래 당사자에게 있습니다.
* 금전 거래 분쟁
* 예약 취소 분쟁
* 환불 관련 분쟁
* 상품 및 서비스 품질 문제
* 허위 정보로 인한 피해
* 계약 불이행
* 사기 행위로 인한 피해
* 기타 회원 간 발생하는 모든 민사 및 형사상 분쟁

서비스 운영자는 회원 간 거래에서 발생하는 손해, 사고, 분쟁 또는 계약상의 문제에 대해 책임을 지지 않습니다.
회원은 위 내용을 충분히 이해하고 이에 동의한 후 서비스를 이용합니다.
""";

const _marketingConsentText = """
회원은 이벤트, 프로모션, 할인 정보, 신규 서비스 안내 등 마케팅 정보를 이메일, 문자메시지, 앱 푸시 알림 등의 방법으로 수신할 수 있습니다.
회원은 언제든지 수신 동의를 철회할 수 있습니다.
""";

// --- 약관 관련 헬퍼 위젯 ---

class _TermsAccordion extends StatelessWidget {
  const _TermsAccordion({
    required this.title,
    required this.content,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String content;
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: _brandOrange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
        ],
      ),
      trailing: const Icon(Icons.keyboard_arrow_down, size: 20),
      shape: const Border(),
      childrenPadding: const EdgeInsets.fromLTRB(48, 0, 20, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            content,
            style: const TextStyle(fontSize: 12, color: _muted, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class TermsAgreementScreen extends StatefulWidget {
  const TermsAgreementScreen({required this.user, super.key});
  final User user;

  @override
  State<TermsAgreementScreen> createState() => _TermsAgreementScreenState();
}

class _TermsAgreementScreenState extends State<TermsAgreementScreen> {
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _agreeNotice = false;
  bool _agreeMarketing = false;
  bool _isSubmitting = false;

  bool get _allRequiredAgreed => _agreeTerms && _agreePrivacy && _agreeNotice;
  bool get _isAllAgreed => _allRequiredAgreed && _agreeMarketing;

  void _toggleAll(bool? value) {
    setState(() {
      _agreeTerms = value ?? false;
      _agreePrivacy = value ?? false;
      _agreeNotice = value ?? false;
      _agreeMarketing = value ?? false;
    });
  }

  Future<void> _submit() async {
    if (!_allRequiredAgreed) return;
    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).set({
        'termsAccepted': true,
        'privacyAccepted': true,
        'noticeAccepted': true,
        'marketingAccepted': _agreeMarketing,
        'acceptedAt': FieldValue.serverTimestamp(),
        'termsVersion': '1.0',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[TermsAgreementScreen] failed: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('약관 동의')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '서비스 이용을 위해\\n약관에 동의해주세요.',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFEDEDED)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                CheckboxListTile(
                  title: const Text('전체 동의', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: _isAllAgreed,
                  onChanged: _toggleAll,
                  activeColor: _brandOrange,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const Divider(height: 1),
                _TermsAccordion(
                  title: '[필수] 서비스 이용약관 동의',
                  content: _serviceTermsText,
                  value: _agreeTerms,
                  onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                ),
                _TermsAccordion(
                  title: '[필수] 개인정보 처리방침 동의',
                  content: _privacyPolicyText,
                  value: _agreePrivacy,
                  onChanged: (v) => setState(() => _agreePrivacy = v ?? false),
                ),
                _TermsAccordion(
                  title: '[필수] 거래 주의사항 동의',
                  content: _transactionNoticeText,
                  value: _agreeNotice,
                  onChanged: (v) => setState(() => _agreeNotice = v ?? false),
                ),
                _TermsAccordion(
                  title: '[선택] 마케팅 정보 수신 동의',
                  content: _marketingConsentText,
                  value: _agreeMarketing,
                  onChanged: (v) => setState(() => _agreeMarketing = v ?? false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _allRequiredAgreed && !_isSubmitting ? _submit : null,
            style: FilledButton.styleFrom(
              backgroundColor: _brandOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSubmitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('동의 완료'),
          ),
        ],
      ),
    );
  }
}
