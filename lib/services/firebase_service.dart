import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/listing_type.dart';
import '../models/market_listing.dart';

const firebaseRequestTimeout = Duration(seconds: 15);
bool firebaseReady = false;
String? firebaseInitMessage;

String? firebaseUnavailableMessage() {
  if (firebaseReady && Firebase.apps.isNotEmpty) return null;
  return firebaseInitMessage ?? 'Firebase가 아직 초기화되지 않았습니다. 잠시 후 다시 시도해주세요.';
}

Stream<User?> authStateStream() {
  if (firebaseUnavailableMessage() != null) return Stream<User?>.value(null);
  return FirebaseAuth.instance.authStateChanges();
}

User? currentUserOrNull() {
  if (firebaseUnavailableMessage() != null) return null;
  return FirebaseAuth.instance.currentUser;
}

final GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId: '400795002326-dpiq0jgh2aukud62ncedfmfkp98qfnsg.apps.googleusercontent.com',
);

Future<UserCredential?> signInWithGoogle() async {
  try {
    if (kIsWeb) {
      // 웹에서는 google_sign_in의 signIn()이 deprecated 되었고 
      // Cross-Origin-Opener-Policy(COOP) 이슈가 있으므로 
      // Firebase의 native popup 방식을 사용합니다.
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      return await FirebaseAuth.instance.signInWithPopup(googleProvider);
    }

    // 모바일 환경
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await FirebaseAuth.instance.signInWithCredential(credential);
  } catch (e) {
    debugPrint('[Auth] Google Sign-In Error: $e');
    rethrow;
  }
}

Future<void> signOut() async {
  try {
    if (kIsWeb) {
      await FirebaseAuth.instance.signOut();
    } else {
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
    }
  } catch (e) {
    debugPrint('[Auth] Sign-Out Error: $e');
  }
}

String firebaseMessage(FirebaseException error) {
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

Future<void> createUserNotification({
  required String recipientUid,
  required String type,
  required String title,
  required String body,
  String? actorUid,
  String? listingId,
  String? chatRoomId,
}) async {
  if (recipientUid.trim().isEmpty || firebaseUnavailableMessage() != null) {
    return;
  }

  try {
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
        .timeout(firebaseRequestTimeout);
  } catch (error, stackTrace) {
    debugPrint('[Notification] create failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

Future<void> deleteNotification(String userId, String notificationId) async {
  if (firebaseUnavailableMessage() != null) return;
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .delete()
        .timeout(firebaseRequestTimeout);
  } catch (e) {
    debugPrint('[Notification] delete failed: $e');
  }
}

Future<void> deleteChatNotifications(String userId, String chatRoomId) async {
  if (firebaseUnavailableMessage() != null) return;
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('type', isEqualTo: 'chat')
        .where('chatRoomId', isEqualTo: chatRoomId)
        .get()
        .timeout(firebaseRequestTimeout);

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  } catch (e) {
    debugPrint('[Notification] deleteChatNotifications failed: $e');
  }
}

String stringValue(Object? value, String fallback) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

List<String> stringListValue(Object? value) {
  if (value is! List) return const [];
  final result = <String>[];
  for (final item in value) {
    final text = item?.toString().trim() ?? '';
    if (text.isNotEmpty) result.add(text);
  }
  return result;
}

ListingType listingTypeFromValue(Object? value) {
  final name = value?.toString();
  return ListingType.values.firstWhere(
    (type) => type.name == name,
    orElse: () => ListingType.used,
  );
}

MarketListing listingFromFirestoreData(String id, Map<String, dynamic> data) {
  final type = listingTypeFromValue(data['type']);
  final place = stringValue(data['place'], '위치 미입력');
  final seller = stringValue(data['sellerNickname'], '익명');
  final sellerUid = stringValue(data['sellerUid'], '');
  final photoUrls = stringListValue(data['photoUrls']);

  return MarketListing(
    id: id,
    type: type,
    title: stringValue(data['title'], '제목 없음'),
    category: stringValue(data['category'], type.label),
    price: stringValue(data['price'], '가격 미입력'),
    place: place,
    placeNote: place,
    postedAgo: '방금 전',
    sellerNickname: seller,
    sellerUid: sellerUid.isEmpty ? null : sellerUid,
    status: stringValue(data['status'], 'active'),
    itemName: () {
      final name = stringValue(data['itemName'], '');
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
    description: stringValue(data['description'], ''),
    icon: type.icon,
    color: switch (type) {
      ListingType.used => const Color(0xFF6750A4),
      ListingType.request => const Color(0xFFE16A54),
      ListingType.currency => const Color(0xFF2F80ED),
    },
    contactNote: stringValue(data['contact'], '').isEmpty
        ? null
        : stringValue(data['contact'], ''),
  );
}

MarketListing listingFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  return listingFromFirestoreData(doc.id, doc.data());
}

final _sellerNicknameCache = <String, String>{};

bool needsSellerNicknameLookup(MarketListing listing) {
  final nickname = listing.sellerNickname.trim();
  return nickname.isEmpty || nickname == '익명';
}

Future<String> fetchNicknameForUid(
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

  if (firebaseUnavailableMessage() != null) {
    return fallback;
  }

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get()
        .timeout(firebaseRequestTimeout);
    final data = doc.data();
    final nickname = stringValue(data?['nickname'], '');
    if (nickname.isNotEmpty) {
      _sellerNicknameCache[uid] = nickname;
      return nickname;
    }
    final name = stringValue(data?['name'], '');
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

Future<String> resolveSellerNickname(MarketListing listing) async {
  if (!needsSellerNicknameLookup(listing)) {
    return listing.sellerNickname;
  }

  final sellerUid = listing.sellerUid?.trim();
  if (sellerUid == null || sellerUid.isEmpty) {
    return listing.sellerNickname;
  }

  return fetchNicknameForUid(sellerUid, fallback: listing.sellerNickname);
}
