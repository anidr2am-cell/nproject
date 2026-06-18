import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'real_estate_detail_screen.dart';
import 'real_estate_write_screen.dart';

class RealEstateScreen extends StatefulWidget {
  const RealEstateScreen({super.key});

  @override
  State<RealEstateScreen> createState() => _RealEstateScreenState();
}

class _RealEstateScreenState extends State<RealEstateScreen> {
  String _selectedTradeType = '전체';
  String _selectedPropertyType = '전체';

  final List<String> _tradeTypes = ['전체', '매매', '월세'];
  final List<String> _propertyTypes = ['전체', '아파트', '콘도', '주택', '상가'];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('부동산', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('realEstate')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('[RealEstateScreen] Firestore Error: ${snapshot.error}');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('데이터를 불러오는 중 오류가 발생했습니다.\n${snapshot.error}', 
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data?.docs ?? [];

                // Client-side filtering
                if (_selectedTradeType != '전체') {
                  docs = docs.where((doc) => doc.data()['dealType'] == _selectedTradeType).toList();
                }
                if (_selectedPropertyType != '전체') {
                  docs = docs.where((doc) => doc.data()['propertyType'] == _selectedPropertyType).toList();
                }

                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home_work_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('등록된 매물이 없습니다.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    indent: 112,
                    endIndent: 20,
                    color: brandBorder,
                  ),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    return _RealEstateTile(
                      docId: doc.id,
                      data: data,
                      timeAgo: _getTimeAgo(data['createdAt']),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: brandOrange,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RealEstateWriteScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('매물 등록'),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: brandBorder)),
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: _tradeTypes.map((type) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(type),
                  selected: _selectedTradeType == type,
                  onSelected: (_) => setState(() => _selectedTradeType = type),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: _selectedTradeType == type ? Colors.white : ink,
                    fontWeight: _selectedTradeType == type ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  selectedColor: brandOrange,
                  backgroundColor: surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: _selectedTradeType == type ? brandOrange : brandBorder,
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: _propertyTypes.map((type) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(type),
                  selected: _selectedPropertyType == type,
                  onSelected: (_) => setState(() => _selectedPropertyType = type),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: _selectedPropertyType == type ? Colors.white : ink,
                    fontWeight: _selectedPropertyType == type ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  selectedColor: brandOrange,
                  backgroundColor: surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: _selectedPropertyType == type ? brandOrange : brandBorder,
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RealEstateTile extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String timeAgo;

  const _RealEstateTile({required this.docId, required this.data, required this.timeAgo});

  @override
  Widget build(BuildContext context) {
    final photoUrls = data['photoUrls'] as List?;
    final thumbnailUrl = (photoUrls != null && photoUrls.isNotEmpty) ? photoUrls.first : null;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RealEstateDetailScreen(docId: docId, data: data),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: brandBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: thumbnailUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.home_work, color: Colors.grey, size: 34),
                      ),
                    )
                  : const Icon(Icons.home_work, color: Colors.grey, size: 34),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'] ?? '제목 없음',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['dealType'] == '월세'
                        ? '월세 ${data['deposit'] ?? ''}/${data['monthlyRent'] ?? ''}'
                        : '매매 ${data['price'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: brandSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data['address'] ?? ''} · $timeAgo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: brandBackground,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      data['propertyType'] ?? '',
                      style: const TextStyle(color: muted, fontSize: 10),
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

