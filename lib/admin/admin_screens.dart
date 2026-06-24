import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'admin_app.dart';
import 'admin_models.dart';
import 'admin_repositories.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const adminCategorySeeds = ['디지털기기', '생활가전', '의류', '가구', '자동차/바이크', '스포츠', '도서', '기타'];
const adminLocationSeeds = ['방콕', '파타야', '시라차', '푸켓', '치앙마이', '라용', '방센'];
const adminStatuses = ['active', 'reserved', 'sold', 'hidden'];

class AdminPage extends StatelessWidget {
  const AdminPage({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: child,
          ),
        ),
      ],
    );
  }
}

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final dashboardRepository = AdminDashboardRepository();
    final productRepository = AdminProductRepository();
    return AdminPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<AdminDashboardStats>(
            future: dashboardRepository.loadStats(),
            builder: (context, snapshot) {
              final stats = snapshot.data;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(label: '전체 회원 수', value: stats?.userCount),
                  _StatCard(label: '전체 상품 수', value: stats?.productCount),
                  _StatCard(label: '오늘 등록 상품 수', value: stats?.todayProductCount),
                  _StatCard(label: '판매중 상품 수', value: stats?.activeProductCount),
                  _StatCard(label: '신고 건수', value: stats?.reportCount),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const _SectionTitle('최근 등록 상품'),
          const SizedBox(height: 10),
          StreamBuilder<List<AdminProduct>>(
            stream: productRepository.watchRecentProducts(),
            builder: (context, snapshot) {
              final products = snapshot.data ?? const <AdminProduct>[];
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _Panel(child: Center(child: CircularProgressIndicator()));
              }
              if (products.isEmpty) {
                return const _Panel(child: Text('등록된 상품이 없습니다.'));
              }
              return _Panel(child: _ProductTable(products: products, compact: true));
            },
          ),
        ],
      ),
    );
  }
}

class AdminProductListScreen extends StatefulWidget {
  const AdminProductListScreen({super.key});
  @override
  State<AdminProductListScreen> createState() => _AdminProductListScreenState();
}

class _AdminProductListScreenState extends State<AdminProductListScreen> {
  final _searchController = TextEditingController();
  String _statusFilter = 'all';
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final repository = AdminProductRepository();
    return AdminPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '상품명, 카테고리, 지역 검색',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('전체')),
                  ButtonSegment(value: 'active', label: Text('판매중')),
                  ButtonSegment(value: 'reserved', label: Text('예약중')),
                  ButtonSegment(value: 'sold', label: Text('판매완료')),
                  ButtonSegment(value: 'hidden', label: Text('숨김')),
                ],
                selected: {_statusFilter},
                onSelectionChanged: (value) => setState(() => _statusFilter = value.first),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<AdminProduct>>(
            stream: repository.watchProducts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _Panel(child: Center(child: CircularProgressIndicator()));
              }
              final keyword = _searchController.text.trim().toLowerCase();
              final products = (snapshot.data ?? const <AdminProduct>[]).where((product) {
                final matchesStatus = _statusFilter == 'all' || product.status == _statusFilter;
                final target = '${product.title} ${product.category} ${product.location}'.toLowerCase();
                final matchesKeyword = keyword.isEmpty || target.contains(keyword);
                return matchesStatus && matchesKeyword;
              }).toList();
              return _Panel(
                child: _ProductTable(
                  products: products,
                  onStatusChanged: repository.updateProductStatus,
                  onDelete: (id) async {
                    final confirmed = await _confirm(context, '상품을 삭제하시겠습니까?');
                    if (confirmed) await repository.deleteProduct(id);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AdminProductFormScreen extends StatelessWidget {
  const AdminProductFormScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const AdminPage(child: _ProductEditor(source: 'manual'));
  }
}

class AdminAiProductScreen extends StatefulWidget {
  const AdminAiProductScreen({super.key});
  @override
  State<AdminAiProductScreen> createState() => _AdminAiProductScreenState();
}

class _AdminAiProductScreenState extends State<AdminAiProductScreen> {
  final _rawController = TextEditingController();
  AdminProductDraft? _draft;
  @override
  void dispose() {
    _rawController.dispose();
    super.dispose();
  }
  void _analyze() {
    setState(() => _draft = parseMarketplaceText(_rawController.text));
  }
  @override
  Widget build(BuildContext context) {
    return AdminPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('AI 상품 등록'),
          const SizedBox(height: 6),
          const Text(
            '현재는 Mock 파싱 함수로 동작합니다. 이후 OpenAI API 호출로 교체 예정입니다.',
            style: TextStyle(color: adminMuted),
          ),
          const SizedBox(height: 16),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _rawController,
                  minLines: 8,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: '원문 입력',
                    alignLabelWithHint: true,
                    hintText: '예시: iPhone 15 Pro Max\n256GB\n29000 baht',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _analyze,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('AI 파싱'),
                  ),
                ),
              ],
            ),
          ),
          if (_draft != null) ...[
            const SizedBox(height: 18),
            const _SectionTitle('결과 미리보기'),
            const SizedBox(height: 10),
            _ProductEditor(initialDraft: _draft!, source: 'facebook_marketplace'),
          ],
        ],
      ),
    );
  }
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({this.initialDraft, required this.source});
  final AdminProductDraft? initialDraft;
  final String source;
  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  final _locationController = TextEditingController();
  String _category = adminCategorySeeds.first;
  String _location = adminLocationSeeds.first;
  bool _isCustomLocation = false;
  String _status = 'active';
  String _condition = '중고';
  final _images = <AdminUploadFile>[];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    _titleController = TextEditingController(text: draft?.title ?? '');
    _priceController = TextEditingController(
      text: draft?.price == null ? '' : '${draft!.price}',
    );
    _descriptionController = TextEditingController(text: draft?.description ?? '');
    _category = _validOrFirst(draft?.category, adminCategorySeeds);
    _location = _validOrFirst(draft?.location, adminLocationSeeds);
    _locationController.text = _location;
    _status = _validOrFirst(draft?.status, adminStatuses);
    _condition = draft?.condition ?? '중고';
  }

  @override
  void dispose() {
    _locationController.dispose();
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    setState(() {
      _images
        ..clear()
        ..addAll(
          result.files
              .where((file) => file.bytes != null)
              .map(
                (file) => AdminUploadFile(
                  name: file.name,
                  bytes: file.bytes!,
                  contentType: _contentTypeForName(file.name),
                ),
              ),
        );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final draft = AdminProductDraft(
        title: _titleController.text.trim(),
        price: int.parse(_priceController.text.replaceAll(RegExp(r'[^0-9]'), '')),
        category: _category,
        description: _descriptionController.text.trim(),
        location: _location,
        condition: _condition,
        status: _status,
        source: widget.source,
      );
      await AdminProductRepository().createProduct(draft, _images);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('상품이 등록되었습니다.')));
      _formKey.currentState!.reset();
      _titleController.clear();
      _priceController.clear();
      _descriptionController.clear();
      setState(() => _images.clear());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('상품 등록에 실패했습니다. $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _FieldBox(
                  child: TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: '상품명'),
                    validator: _required,
                  ),
                ),
                _FieldBox(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '가격'),
                    validator: _priceValidator,
                  ),
                ),
                _FieldBox(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: '카테고리'),
                    items: adminCategorySeeds
                        .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                        .toList(),
                    onChanged: (value) => setState(() => _category = value ?? _category),
                  ),
                ),
                _FieldBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _isCustomLocation ? '직접 입력' : _location,
                        decoration: const InputDecoration(labelText: '지역'),
                        items: [
                          ...adminLocationSeeds.map(
                            (item) => DropdownMenuItem(value: item, child: Text(item)),
                          ),
                          const DropdownMenuItem(value: '직접 입력', child: Text('✏️ 직접 입력')),
                        ],
                        onChanged: (value) => setState(() {
                          if (value == '직접 입력') {
                            _isCustomLocation = true;
                            _location = '';
                          } else {
                            _isCustomLocation = false;
                            _location = value ?? _location;
                          }
                        }),
                      ),
                      if (_isCustomLocation) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            hintText: '예: 촌부리, 파타야 중심가',
                          ),
                          onChanged: (val) => _location = val.trim(),
                        ),
                      ],
                    ],
                  ),
                ),
                _FieldBox(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: '상태'),
                    items: adminStatuses
                        .map((item) => DropdownMenuItem(
                            value: item, child: Text(adminStatusLabel(item))))
                        .toList(),
                    onChanged: (value) => setState(() => _status = value ?? _status),
                  ),
                ),
                _FieldBox(
                  child: TextFormField(
                    initialValue: _condition,
                    decoration: const InputDecoration(labelText: '상품 상태'),
                    onChanged: (value) => _condition = value,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              minLines: 5,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: '설명',
                alignLabelWithHint: true,
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('이미지 추가'),
                ),
                const SizedBox(width: 12),
                Text('${_images.length}개 선택됨', style: const TextStyle(color: adminMuted)),
              ],
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: const Text('등록'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repository = AdminUserRepository();
    return AdminPage(
      child: StreamBuilder<List<AdminUserRecord>>(
        stream: repository.watchUsers(),
        builder: (context, snapshot) {
          final users = snapshot.data ?? const <AdminUserRecord>[];
          return _Panel(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('닉네임')),
                  DataColumn(label: Text('이메일')),
                  DataColumn(label: Text('가입일')),
                  DataColumn(label: Text('상품수')),
                  DataColumn(label: Text('상태')),
                  DataColumn(label: Text('관리')),
                ],
                rows: users.map((user) => DataRow(
                  cells: [
                    DataCell(Text(user.nickname)),
                    DataCell(Text(user.email)),
                    DataCell(Text(adminDateLabel(user.createdAt))),
                    DataCell(Text('${user.productCount}')),
                    DataCell(Text(adminStatusLabel(user.status))),
                    DataCell(Row(
                      children: [
                        TextButton(
                          onPressed: () => _showUserDetail(context, user),
                          child: const Text('상세'),
                        ),
                        TextButton(
                          onPressed: () => repository.updateUserStatus(user.id, 'suspended'),
                          child: const Text('정지'),
                        ),
                        TextButton(
                          onPressed: () => repository.updateUserStatus(user.id, 'active'),
                          child: const Text('활성화'),
                        ),
                      ],
                    )),
                  ],
                )).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AdminTaxonomyScreen extends StatefulWidget {
  const AdminTaxonomyScreen.categories({super.key})
    : collectionName = 'categories',
      title = '카테고리 관리',
      seeds = adminCategorySeeds;

  const AdminTaxonomyScreen.locations({super.key})
    : collectionName = 'locations',
      title = '지역 관리',
      seeds = adminLocationSeeds;

  final String collectionName;
  final String title;
  final List<String> seeds;

  @override
  State<AdminTaxonomyScreen> createState() => _AdminTaxonomyScreenState();
}

class _AdminTaxonomyScreenState extends State<AdminTaxonomyScreen> {
  late final AdminTaxonomyRepository _repository;
  @override
  void initState() {
    super.initState();
    _repository = AdminTaxonomyRepository(widget.collectionName, widget.seeds);
    _repository.ensureSeedData();
  }
  Future<void> _openEditor({AdminTaxonomyItem? item}) async {
    final controller = TextEditingController(text: item?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? '${widget.title} 추가' : '${widget.title} 수정'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    if (item == null) {
      await _repository.addItem(name);
    } else {
      await _repository.updateItem(item.id, name);
    }
  }
  @override
  Widget build(BuildContext context) {
    return AdminPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('추가'),
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<AdminTaxonomyItem>>(
            stream: _repository.watchItems(),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <AdminTaxonomyItem>[];
              return _Panel(
                child: Column(
                  children: items.map((item) => ListTile(
                    title: Text(item.name),
                    subtitle: Text('생성일: ${adminDateLabel(item.createdAt)}'),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          tooltip: '수정',
                          onPressed: () => _openEditor(item: item),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: '삭제',
                          onPressed: () => _repository.deleteItem(item.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repository = AdminReportRepository();
    return AdminPage(
      child: StreamBuilder<List<AdminReportRecord>>(
        stream: repository.watchReports(),
        builder: (context, snapshot) {
          final reports = snapshot.data ?? const <AdminReportRecord>[];
          return _Panel(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('신고대상ID')),
                  DataColumn(label: Text('신고자')),
                  DataColumn(label: Text('신고사유')),
                  DataColumn(label: Text('처리상태')),
                  DataColumn(label: Text('신고일')),
                  DataColumn(label: Text('처리')),
                ],
                rows: reports.map((report) => DataRow(
                  cells: [
                    DataCell(Text(report.targetId)),
                    DataCell(Text(report.reporterId)),
                    DataCell(SizedBox(width: 260, child: Text(report.reason))),
                    DataCell(Text(adminStatusLabel(report.status))),
                    DataCell(Text(adminDateLabel(report.createdAt))),
                    DataCell(Wrap(
                      spacing: 6,
                      children: [
                        TextButton(
                          onPressed: () => repository.updateReportStatus(report.id, 'ignored'),
                          child: const Text('무시'),
                        ),
                        TextButton(
                          onPressed: () => repository.hideProduct(report.targetId),
                          child: const Text('숨김'),
                        ),
                        TextButton(
                          onPressed: () => repository.deleteProduct(report.targetId),
                          child: const Text('삭제'),
                        ),
                        TextButton(
                          onPressed: () => repository.suspendUser(report.reporterId),
                          child: const Text('회원 정지'),
                        ),
                      ],
                    )),
                  ],
                )).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const AdminPage(
      child: _Panel(
        child: SizedBox(
          height: 220,
          child: Center(
            child: Text('시스템 기본 설정은 이후 추가 예정입니다.', style: TextStyle(color: adminMuted)),
          ),
        ),
      ),
    );
  }
}

class AdminNoticeScreen extends StatefulWidget {
  const AdminNoticeScreen({super.key});

  @override
  State<AdminNoticeScreen> createState() => _AdminNoticeScreenState();
}

class _AdminNoticeScreenState extends State<AdminNoticeScreen> {
  final _repo = AdminNoticeRepository();

  Future<void> _openEditor({Map<String, dynamic>? notice}) async {
    final titleController = TextEditingController(text: notice?['title'] ?? '');
    final contentController = TextEditingController(text: notice?['content'] ?? '');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notice == null ? '공지사항 등록' : '공지사항 수정'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '제목'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '내용',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (title.isEmpty || content.isEmpty) return;
              if (notice == null) {
                await _repo.addNotice(title: title, content: content);
              } else {
                await _repo.updateNotice(
                  id: notice['id'],
                  title: title,
                  content: content,
                );
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    titleController.dispose();
    contentController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionTitle('공지사항 관리'),
              FilledButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('공지 등록'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _repo.watchNotices(),
            builder: (context, snapshot) {
              final notices = snapshot.data ?? [];
              if (notices.isEmpty) {
                return const _Panel(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('등록된 공지사항이 없습니다.', style: TextStyle(color: adminMuted)),
                    ),
                  ),
                );
              }
              return _Panel(
                child: Column(
                  children: notices.map((notice) => ListTile(
                    title: Text(
                      notice['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      adminDateLabel(notice['createdAt'] is Timestamp
                          ? (notice['createdAt'] as Timestamp).toDate()
                          : null),
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          tooltip: '수정',
                          onPressed: () => _openEditor(notice: notice),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: '삭제',
                          onPressed: () async {
                            final confirmed = await _confirm(context, '공지사항을 삭제하시겠습니까?');
                            if (confirmed) await _repo.deleteNotice(notice['id']);
                          },
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
class AdminChatScreen extends StatefulWidget {
  const AdminChatScreen({super.key});
  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final _repo = AdminProductRepository();
  String? _selectedRoomId;
  String? _selectedSellerName;
  final _msgController = TextEditingController();
  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AdminPage(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 320,
            child: _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('채팅 문의'),
                  const SizedBox(height: 12),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _repo.watchAdminChatRooms(),
                    builder: (context, snapshot) {
                      final rooms = snapshot.data ?? [];
                      if (rooms.isEmpty) {
                        return const Text('문의 채팅이 없습니다.', style: TextStyle(color: adminMuted));
                      }
                      return Column(
                        children: rooms.map((room) {
                          final isSelected = _selectedRoomId == room['id'];
                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: adminSurface,
                            title: Text(room['listingTitle'] ?? room['productTitle'] ?? '상품'),
                            subtitle: Text(room['lastMessage'] ?? ''),
                            onTap: () => setState(() {
                              _selectedRoomId = room['id'];
                              _selectedSellerName = room['sellerNickname'];
                            }),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _selectedRoomId == null
                ? const _Panel(child: Center(child: Text('채팅방을 선택하세요.')))
                : _Panel(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 480,
                          child: StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _repo.watchMessages(_selectedRoomId!),
                            builder: (context, snapshot) {
                              final messages = snapshot.data ?? [];
                              return ListView.builder(
                                itemCount: messages.length,
                                itemBuilder: (context, i) {
                                  final msg = messages[i];
                                  final isAdmin = msg['isAdmin'] == true;
                                  return Align(
                                    alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: isAdmin ? const Color(0xFF1C2B3A) : adminSurface,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                        children: [
                                          Text(msg['senderNickname'] ?? '',
                                              style: TextStyle(fontSize: 11, color: isAdmin ? Colors.white70 : adminMuted)),
                                          Text(msg['text'] ?? '',
                                              style: TextStyle(color: isAdmin ? Colors.white : adminInk)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const Divider(),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _msgController,
                                decoration: const InputDecoration(hintText: '답변 입력...'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () async {
                                final text = _msgController.text.trim();
                                if (text.isEmpty) return;
                                await _repo.sendAdminMessage(
                                  roomId: _selectedRoomId!,
                                  sellerName: _selectedSellerName ?? '관리자',
                                  text: text,
                                );
                                _msgController.clear();
                              },
                              child: const Text('발송'),
                            ),
                          ],
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

class _ProductTable extends StatelessWidget {
  const _ProductTable({
    required this.products,
    this.compact = false,
    this.onStatusChanged,
    this.onDelete,
  });
  final List<AdminProduct> products;
  final bool compact;
  final Future<void> Function(String id, String status)? onStatusChanged;
  final Future<void> Function(String id)? onDelete;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('썸네일')),
          const DataColumn(label: Text('상품명')),
          const DataColumn(label: Text('가격')),
          const DataColumn(label: Text('카테고리')),
          const DataColumn(label: Text('지역')),
          const DataColumn(label: Text('상태')),
          const DataColumn(label: Text('등록일')),
          if (!compact) const DataColumn(label: Text('관리')),
        ],
        rows: products.map((product) => DataRow(
          cells: [
            DataCell(_Thumb(url: product.images.isEmpty ? null : product.images.first)),
            DataCell(SizedBox(width: 260, child: Text(product.title))),
            DataCell(Text('${product.price}')),
            DataCell(Text(product.category)),
            DataCell(Text(product.location)),
            DataCell(
              onStatusChanged == null
                  ? Text(adminStatusLabel(product.status))
                  : DropdownButton<String>(
                      value: adminStatuses.contains(product.status) ? product.status : 'active',
                      underline: const SizedBox.shrink(),
                      items: adminStatuses
                          .map((status) => DropdownMenuItem(value: status, child: Text(adminStatusLabel(status))))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) onStatusChanged!(product.id, value);
                      },
                    ),
            ),
            DataCell(Text(adminDateLabel(product.createdAt))),
            if (!compact)
              DataCell(Wrap(
                spacing: 6,
                children: [
                  TextButton(onPressed: () {}, child: const Text('수정')),
                  TextButton(
                    onPressed: onDelete == null ? null : () => onDelete!(product.id),
                    child: const Text('삭제'),
                  ),
                ],
              )),
          ],
        )).toList(),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.url});
  final String? url;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: adminSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: adminBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? const Icon(Icons.image_outlined, color: adminMuted)
          : Image.network(url!, fit: BoxFit.cover),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final int? value;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 212,
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: adminMuted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(value == null ? '-' : '$value',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: adminBorder),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: adminInk));
  }
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 260, child: child);
  }
}

void _showUserDetail(BuildContext context, AdminUserRecord user) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(user.nickname),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('UID: ${user.id}'),
          Text('이메일: ${user.email}'),
          Text('가입일: ${adminDateLabel(user.createdAt)}'),
          Text('상품수: ${user.productCount}'),
          Text('상태: ${adminStatusLabel(user.status)}'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
      ],
    ),
  );
}

Future<bool> _confirm(BuildContext context, String message) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('확인')),
          ],
        ),
      ) ??
      false;
}

String? _required(String? value) {
  return value?.trim().isEmpty == true ? '필수 입력 항목입니다.' : null;
}

String? _priceValidator(String? value) {
  final price = int.tryParse(value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '');
  return price == null || price <= 0 ? '가격을 올바르게 입력해주세요.' : null;
}

String _validOrFirst(String? value, List<String> values) {
  if (value != null && values.contains(value)) return value;
  return values.first;
}

String _contentTypeForName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}