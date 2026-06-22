import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_repositories.dart';
import 'admin_screens.dart';

const adminPrimary = Color(0xFF1E5EFF);
const adminInk = Color(0xFF172033);
const adminMuted = Color(0xFF687084);
const adminSurface = Color(0xFFF5F7FB);
const adminBorder = Color(0xFFE2E6EF);

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '82saja Admin',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: adminPrimary,
          primary: adminPrimary,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: adminSurface,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: adminInk,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: adminBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: adminBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: adminPrimary, width: 1.4),
          ),
        ),
        dataTableTheme: const DataTableThemeData(
          headingRowColor: WidgetStatePropertyAll(Color(0xFFF8FAFE)),
          dividerThickness: 0.7,
        ),
      ),
      home: const AdminAuthGate(),
    );
  }
}

class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepository = AdminAuthRepository();
    return StreamBuilder<User?>(
      stream: authRepository.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AdminLoadingScreen();
        }
        if (user == null) {
          return const AdminLoginScreen();
        }
        return FutureBuilder<bool>(
          future: authRepository.isAdmin(user),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              return const AdminLoadingScreen();
            }
            if (adminSnapshot.data == true) {
              return const AdminShell();
            }
            return AdminBlockedScreen(email: user.email ?? 'unknown');
          },
        );
      },
    );
  }
}

class AdminLoadingScreen extends StatelessWidget {
  const AdminLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final authRepository = AdminAuthRepository();
      final credential = await authRepository.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      final uid = credential.user?.uid;
      final isAdmin =
          credential.user != null &&
          await authRepository.isAdmin(credential.user!);
      if (!isAdmin) {
        await authRepository.signOut();
        setState(() => _errorText = '관리자 계정이 아닙니다. 접근이 차단되었습니다.');
      }
    } on FirebaseAuthException catch (error) {
      setState(() => _errorText = error.message ?? '로그인에 실패했습니다.');
    } catch (_) {
      setState(() => _errorText = '로그인에 실패했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: adminBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '82saja Admin',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: adminInk,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '관리자 계정으로 로그인하세요.',
                        style: TextStyle(color: adminMuted),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: '이메일'),
                        validator: (value) => value?.trim().isEmpty == true
                            ? '이메일을 입력해주세요.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: '비밀번호'),
                        validator: (value) => value == null || value.length < 6
                            ? '비밀번호를 입력해주세요.'
                            : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorText!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('로그인'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminBlockedScreen extends StatelessWidget {
  const AdminBlockedScreen({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 52, color: Colors.red),
            const SizedBox(height: 16),
            const Text('관리자 권한이 없습니다.', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(email, style: const TextStyle(color: adminMuted)),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => AdminAuthRepository().signOut(),
              child: const Text('로그아웃'),
            ),
          ],
        ),
      ),
    );
  }
}

enum AdminSection {
  dashboard('대시보드', Icons.dashboard_outlined),
  productList('상품 목록', Icons.inventory_2_outlined),
  productCreate('일반 등록', Icons.add_box_outlined),
  aiCreate('AI 등록', Icons.auto_awesome_outlined),
  users('회원 관리', Icons.people_outline),
  categories('카테고리 관리', Icons.category_outlined),
  locations('지역 관리', Icons.place_outlined),
  reports('신고 관리', Icons.report_outlined),
  settings('설정', Icons.settings_outlined);

  const AdminSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  AdminSection _section = AdminSection.dashboard;

  String get _title => _section.label;

  Widget _buildScreen() {
    return switch (_section) {
      AdminSection.dashboard => const AdminDashboardScreen(),
      AdminSection.productList => const AdminProductListScreen(),
      AdminSection.productCreate => const AdminProductFormScreen(),
      AdminSection.aiCreate => const AdminAiProductScreen(),
      AdminSection.users => const AdminUsersScreen(),
      AdminSection.categories => const AdminTaxonomyScreen.categories(),
      AdminSection.locations => const AdminTaxonomyScreen.locations(),
      AdminSection.reports => const AdminReportsScreen(),
      AdminSection.settings => const AdminSettingsScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 920;
    final content = Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: '로그아웃',
            onPressed: () => AdminAuthRepository().signOut(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: isWide
          ? null
          : Drawer(
              child: AdminNavigation(
                selected: _section,
                onSelected: (section) {
                  Navigator.of(context).pop();
                  setState(() => _section = section);
                },
              ),
            ),
      body: _buildScreen(),
    );

    if (!isWide) return content;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 260,
            child: AdminNavigation(
              selected: _section,
              onSelected: (section) => setState(() => _section = section),
            ),
          ),
          const VerticalDivider(width: 1, color: adminBorder),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class AdminNavigation extends StatelessWidget {
  const AdminNavigation({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final AdminSection selected;
  final ValueChanged<AdminSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          children: [
            const Text(
              '82saja',
              style: TextStyle(
                color: adminInk,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text('Admin CMS', style: TextStyle(color: adminMuted)),
            const SizedBox(height: 24),
            _NavTile(
              section: AdminSection.dashboard,
              selected: selected,
              onSelected: onSelected,
            ),
            const _NavGroupLabel('상품 관리'),
            _NavTile(
              section: AdminSection.productList,
              selected: selected,
              onSelected: onSelected,
            ),
            _NavTile(
              section: AdminSection.productCreate,
              selected: selected,
              onSelected: onSelected,
            ),
            _NavTile(
              section: AdminSection.aiCreate,
              selected: selected,
              onSelected: onSelected,
            ),
            const _NavGroupLabel('운영'),
            _NavTile(
              section: AdminSection.users,
              selected: selected,
              onSelected: onSelected,
            ),
            _NavTile(
              section: AdminSection.categories,
              selected: selected,
              onSelected: onSelected,
            ),
            _NavTile(
              section: AdminSection.locations,
              selected: selected,
              onSelected: onSelected,
            ),
            _NavTile(
              section: AdminSection.reports,
              selected: selected,
              onSelected: onSelected,
            ),
            const _NavGroupLabel('시스템'),
            _NavTile(
              section: AdminSection.settings,
              selected: selected,
              onSelected: onSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavGroupLabel extends StatelessWidget {
  const _NavGroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
      child: Text(
        text,
        style: const TextStyle(
          color: adminMuted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.section,
    required this.selected,
    required this.onSelected,
  });

  final AdminSection section;
  final AdminSection selected;
  final ValueChanged<AdminSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == section;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        selected: isSelected,
        selectedTileColor: const Color(0xFFEAF0FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(
          section.icon,
          color: isSelected ? adminPrimary : adminMuted,
        ),
        title: Text(
          section.label,
          style: TextStyle(
            color: isSelected ? adminPrimary : adminInk,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
        onTap: () => onSelected(section),
      ),
    );
  }
}
