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
                    color: Color(0xFFEDEDED),
                  ),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    return _RealEstateTile(
                      data: data,
                      docId: doc.id,
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1)),
      ),
      child: Column(
        children: [
          // 1. 거래유형 필터 (전체/매매/월세) - 균등 너비
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _tradeTypes.map((type) {
                final isSelected = _selectedTradeType == type;
                final isFirst = type == _tradeTypes.first;
                final isLast = type == _tradeTypes.last;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: isLast ? 0 : 6,
                    ),
                    child: InkWell(
                      onTap: () => setState(() => _selectedTradeType = type),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF333333) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                          ),
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF888888),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // 2. 부동산종류 필터 (가로 스크롤 캡슐)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _propertyTypes.map((type) {
                final isSelected = _selectedPropertyType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedPropertyType = type),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF5F5F5) : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF333333) : const Color(0xFF999999),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RealEstateTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final String timeAgo;

  const _RealEstateTile({
    required this.data,
    required this.docId,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrls = data['photoUrls'] as List?;
    final thumbnailUrl = (photoUrls != null && photoUrls.isNotEmpty) ? photoUrls.first : null;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RealEstateDetailScreen(data: data, docId: docId),
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
                color: const Color(0xFFF5F5F5),
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
                      color: brandOrange,
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
                      color: const Color(0xFFF5F5F5),
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
