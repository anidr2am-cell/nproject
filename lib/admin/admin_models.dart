import 'package:cloud_firestore/cloud_firestore.dart';

class AdminProductDraft {
  const AdminProductDraft({
    required this.title,
    required this.price,
    required this.category,
    required this.description,
    required this.location,
    required this.condition,
    required this.status,
    required this.source,
  });

  final String title;
  final int price;
  final String category;
  final String description;
  final String location;
  final String condition;
  final String status;
  final String source;

  Map<String, Object?> toMap(List<String> imageUrls) {
    return {
      'title': title,
      'price': price,
      'category': category,
      'description': description,
      'location': location,
      'condition': condition,
      'images': imageUrls,
      'sellerId': '${location}사랑',
      'sellerNickname': '${location}사랑',
      'status': status,
      'source': source,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class AdminProduct {
  const AdminProduct({
    required this.id,
    required this.title,
    required this.price,
    required this.category,
    required this.description,
    required this.location,
    required this.condition,
    required this.images,
    required this.sellerId,
    required this.status,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final int price;
  final String category;
  final String description;
  final String location;
  final String condition;
  final List<String> images;
  final String sellerId;
  final String status;
  final String source;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AdminProduct.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AdminProduct(
      id: doc.id,
      title: _string(data['title'], '제목 없음'),
      price: _int(data['price']),
      category: _string(data['category'], '기타'),
      description: _string(data['description'], ''),
      location: _string(data['location'], ''),
      condition: _string(data['condition'], '중고'),
      images: _stringList(data['images']),
      sellerId: _string(data['sellerId'], ''),
      status: _string(data['status'], 'active'),
      source: _string(data['source'], 'manual'),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }
}

class AdminDashboardStats {
  const AdminDashboardStats({
    required this.userCount,
    required this.productCount,
    required this.todayProductCount,
    required this.activeProductCount,
    required this.reportCount,
  });

  final int userCount;
  final int productCount;
  final int todayProductCount;
  final int activeProductCount;
  final int reportCount;
}

class AdminUserRecord {
  const AdminUserRecord({
    required this.id,
    required this.nickname,
    required this.email,
    required this.status,
    required this.createdAt,
    required this.productCount,
  });

  final String id;
  final String nickname;
  final String email;
  final String status;
  final DateTime? createdAt;
  final int productCount;

  factory AdminUserRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    int productCount = 0,
  }) {
    final data = doc.data() ?? {};
    return AdminUserRecord(
      id: doc.id,
      nickname: _string(data['nickname'], _string(data['name'], '익명')),
      email: _string(data['email'], ''),
      status: _string(data['status'], 'active'),
      createdAt: _date(data['createdAt']),
      productCount: productCount,
    );
  }
}

class AdminTaxonomyItem {
  const AdminTaxonomyItem({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime? createdAt;

  factory AdminTaxonomyItem.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AdminTaxonomyItem(
      id: doc.id,
      name: _string(data['name'], doc.id),
      createdAt: _date(data['createdAt']),
    );
  }
}

class AdminReportRecord {
  const AdminReportRecord({
    required this.id,
    required this.targetId,
    required this.reporterId,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String targetId;
  final String reporterId;
  final String reason;
  final String status;
  final DateTime? createdAt;

  factory AdminReportRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AdminReportRecord(
      id: doc.id,
      targetId: _string(data['targetId'], _string(data['productId'], '')),
      reporterId: _string(data['reporterId'], ''),
      reason: _string(data['reason'], ''),
      status: _string(data['status'], 'pending'),
      createdAt: _date(data['createdAt']),
    );
  }
}

AdminProductDraft parseMarketplaceText(String input) {
  final normalized = input.trim();
  final lines = normalized
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  final joined = lines.join(' ');
  final priceMatch = RegExp(
    r'(\d[\d,\.]*)\s*(บาท|baht|thb)?',
    caseSensitive: false,
  ).firstMatch(joined);
  final price =
      int.tryParse(
        (priceMatch?.group(1) ?? '0').replaceAll(RegExp(r'[,\.]'), ''),
      ) ??
      0;

  var title = lines.isEmpty ? '상품명 미분석' : lines.first;
  title = title
      .replaceAll(RegExp(r'ขาย\s*', caseSensitive: false), '')
      .replaceAll('iPhone', '아이폰')
      .replaceAll('Pro Max', '프로 맥스')
      .trim();
  final storage = RegExp(
    r'\b\d+\s*GB\b',
    caseSensitive: false,
  ).firstMatch(joined);
  if (storage != null && !title.toLowerCase().contains('gb')) {
    title = '$title ${storage.group(0)}';
  }

  final lower = joined.toLowerCase();
  final category =
      lower.contains('iphone') ||
          lower.contains('phone') ||
          lower.contains('มือถือ')
      ? '휴대폰'
      : '기타';

  return AdminProductDraft(
    title: title,
    price: price,
    category: category,
    description: '태국 현지 판매 상품입니다.',
    location: '파타야',
    condition: '중고',
    status: 'active',
    source: 'facebook_marketplace',
  );
}

String adminStatusLabel(String status) {
  return switch (status) {
    'active' => '판매중',
    'reserved' => '예약중',
    'sold' => '판매완료',
    'hidden' => '숨김',
    'suspended' => '정지',
    'ignored' => '무시',
    'resolved' => '처리완료',
    _ => status,
  };
}

String adminDateLabel(DateTime? date) {
  if (date == null) return '-';
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

String _string(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(
        value?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '',
      ) ??
      0;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
