import 'package:flutter/material.dart';

void main() {
  runApp(const NprojectApp());
}

const _brandOrange = Color(0xFFFF6F0F);
const _ink = Color(0xFF222222);
const _muted = Color(0xFF767676);
const _surface = Color(0xFFF7F8FA);
const _warning = Color(0xFFFFF3E8);

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
  Widget build(BuildContext context) {
    return Scaffold(
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
        title: const Text('하늘상점님'),
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
          SliverList.separated(
            itemCount: sampleListings.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              indent: 112,
              endIndent: 20,
              color: Color(0xFFEDEDED),
            ),
            itemBuilder: (context, index) {
              final listing = sampleListings[index];
              return ListingTile(
                listing: listing,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ListingDetailScreen(listing: listing),
                  ),
                ),
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
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 15, color: _muted),
                      const SizedBox(width: 4),
                      Text(
                        '${listing.sellerNickname} · 거래 ${listing.tradeCount}회',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
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
                onPressed: () {},
                icon: const Icon(Icons.ios_share),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: PageView.builder(
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
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_imageIndex + 1}/${listing.photoCount}',
                        style: const TextStyle(color: _muted),
                      ),
                    ),
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
                  _InfoRow(
                    icon: Icons.place_outlined,
                    label: '거래 희망 장소',
                    value: listing.placeNote,
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
                onPressed: () {},
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
  ListingType _type = ListingType.used;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('글 등록')),
      body: Form(
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
              onSelectionChanged: (value) =>
                  setState(() => _type = value.first),
            ),
            const SizedBox(height: 18),
            if (_type == ListingType.used) const _UsedListingForm(),
            if (_type == ListingType.request) const _DeliveryRequestForm(),
            if (_type == ListingType.currency) const _CurrencyExchangeForm(),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: _brandOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('${_type.label} 등록하기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsedListingForm extends StatelessWidget {
  const _UsedListingForm();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PhotoPickerMock(),
        SizedBox(height: 22),
        _InputLabel('제품명'),
        TextField(decoration: InputDecoration(hintText: '예: 아이폰 14 프로 256GB')),
        SizedBox(height: 18),
        _InputLabel('판매 가격'),
        TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: 'THB 또는 KRW 금액 입력'),
        ),
        SizedBox(height: 18),
        _InputLabel('카테고리'),
        _CategoryDropdown(),
        SizedBox(height: 18),
        _InputLabel('거래 희망 장소'),
        TextField(decoration: InputDecoration(hintText: '예: 파타야 힐튼호텔 앞')),
        SizedBox(height: 18),
        _InputLabel('제품 상세 설명'),
        TextField(
          minLines: 5,
          maxLines: 8,
          decoration: InputDecoration(
            hintText: '상태, 구매 시기, 전달 가능 시간 등을 자세히 적어주세요.',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

class _DeliveryRequestForm extends StatelessWidget {
  const _DeliveryRequestForm();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PhotoPickerMock(),
        SizedBox(height: 22),
        _InputLabel('물품명'),
        TextField(decoration: InputDecoration(hintText: '배달 원하는 물품을 기재하세요.')),
        SizedBox(height: 18),
        _InputLabel('배달 수수료'),
        TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '수수료 제시'),
        ),
        SizedBox(height: 18),
        _InputLabel('카카오톡 or 라인 ID'),
        TextField(decoration: InputDecoration(hintText: '연락 가능한 ID 입력')),
        SizedBox(height: 18),
        _InputLabel('상세 설명'),
        TextField(
          minLines: 6,
          maxLines: 9,
          decoration: InputDecoration(
            hintText:
                '구체적인 제품 명과 색상, 크기, 무게 등을 상세히 설명해주세요. 태국 반입 금지 물품은 등록 불가합니다.',
            alignLabelWithHint: true,
          ),
        ),
        SizedBox(height: 14),
        _NoticeBox(
          icon: Icons.info_outline,
          text: '태국 반입 금지 물품, 고가품, 통관 문제가 생길 수 있는 물품은 등록할 수 없습니다.',
        ),
      ],
    );
  }
}

class _CurrencyExchangeForm extends StatelessWidget {
  const _CurrencyExchangeForm();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InputLabel('원하는 화폐'),
        _CurrencyDropdown(),
        SizedBox(height: 18),
        _InputLabel('금액'),
        TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '예: 3,200 THB 또는 120,000 KRW'),
        ),
        SizedBox(height: 18),
        _InputLabel('적용 환율'),
        TextField(decoration: InputDecoration(hintText: '예: 네이버 살때')),
        SizedBox(height: 18),
        _InputLabel('거래 희망 장소'),
        TextField(decoration: InputDecoration(hintText: '예: 방콕 한인 식당, 파타야 카페')),
        SizedBox(height: 18),
        _InputLabel('거래방법'),
        TextField(
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: '예: 한국 계좌에서 송금 후 바트 현금 수령 등',
            alignLabelWithHint: true,
          ),
        ),
        SizedBox(height: 14),
        _NoticeBox(
          icon: Icons.warning_amber_rounded,
          text:
              '최근 화폐 교환 관련 사기가 많으니 주의해서 거래하시기 바랍니다. 가급적 거래 장소를 한인이 운영하는 식당 같은 공개 장소로 정하세요.',
        ),
      ],
    );
  }
}

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원 가입')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const _InputLabel('이름'),
          const TextField(decoration: InputDecoration(hintText: '실명 입력')),
          const SizedBox(height: 18),
          const _InputLabel('닉네임'),
          const TextField(decoration: InputDecoration(hintText: '앱에 표시될 이름')),
          const SizedBox(height: 18),
          const _InputLabel('이메일 ID'),
          const TextField(
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(hintText: 'example@email.com'),
          ),
          const SizedBox(height: 18),
          const _InputLabel('비밀번호'),
          const TextField(
            obscureText: true,
            decoration: InputDecoration(hintText: '6자리 이상'),
          ),
          const SizedBox(height: 24),
          const _InputLabel('선택 정보'),
          const TextField(
            decoration: InputDecoration(hintText: '거주지 위치 예: 방콕, 파타야, 치앙마이'),
          ),
          const SizedBox(height: 12),
          const TextField(decoration: InputDecoration(hintText: '카카오톡 ID')),
          const SizedBox(height: 12),
          const TextField(decoration: InputDecoration(hintText: '라인 ID')),
          const SizedBox(height: 12),
          Row(
            children: const [
              SizedBox(width: 104, child: _PhoneCountryDropdown()),
              SizedBox(width: 10),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(hintText: '연락처'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: _brandOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('회원 가입하기'),
          ),
        ],
      ),
    );
  }
}

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('나의 정보')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const _ProfileHeader(),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AuthScreen())),
            style: FilledButton.styleFrom(
              backgroundColor: _brandOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('회원 가입'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: _ink,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('로그아웃'),
          ),
          const SizedBox(height: 22),
          const _ProfileSection(
            title: '회원 가입 필수 정보',
            rows: [
              ('이름', '김하늘'),
              ('닉네임', '하늘상점'),
              ('이메일 ID', 'haneul@example.com'),
              ('비밀번호', '6자리 이상'),
            ],
          ),
          const SizedBox(height: 18),
          const _ProfileSection(
            title: '선택 정보',
            rows: [
              ('거주지 위치', '파타야'),
              ('카카오톡 ID', 'nproject_th'),
              ('라인 ID', 'nproject.line'),
              ('연락처', '+66 81 234 5678'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoPickerMock extends StatelessWidget {
  const _PhotoPickerMock();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDADADA)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined),
              SizedBox(height: 4),
              Text('0/5'),
            ],
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
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: _brandOrange,
            child: Text(
              '하',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '하늘상점',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text('파타야 · 거래 12회', style: TextStyle(color: _muted)),
              ],
            ),
          ),
        ],
      ),
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
  const _CategoryDropdown();

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: categories.first,
      items: categories
          .map(
            (category) =>
                DropdownMenuItem(value: category, child: Text(category)),
          )
          .toList(),
      onChanged: (_) {},
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown();

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: '바트를 원화로',
      items: const [
        DropdownMenuItem(value: '바트를 원화로', child: Text('바트를 원화로')),
        DropdownMenuItem(value: '원화를 바트로', child: Text('원화를 바트로')),
      ],
      onChanged: (_) {},
    );
  }
}

class _PhoneCountryDropdown extends StatelessWidget {
  const _PhoneCountryDropdown();

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: '+66',
      items: const [
        DropdownMenuItem(value: '+66', child: Text('태국 +66')),
        DropdownMenuItem(value: '+82', child: Text('한국 +82')),
      ],
      onChanged: (_) {},
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
  ),
];
