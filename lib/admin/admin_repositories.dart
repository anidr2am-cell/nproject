import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'admin_models.dart';

class AdminAuthRepository {
  AdminAuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<bool> isAdmin(User user) async {
    try {
      final admins = _firestore.collection('admins');
      final uidDoc = await admins.doc(user.uid).get();
      if (uidDoc.exists) return true;

      final email = user.email?.trim().toLowerCase();
      if (email == null || email.isEmpty) return false;

      final emailDoc = await admins.doc(email).get();
      return emailDoc.exists;
    } on FirebaseException {
      return false;
    }
  }
}

class AdminProductRepository {
  AdminProductRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection('listings');

  Stream<List<AdminProduct>> watchProducts() {
    return _products
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AdminProduct.fromDoc).toList());
  }

  Stream<List<AdminProduct>> watchRecentProducts({int limit = 8}) {
    return _products
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AdminProduct.fromDoc).toList());
  }

  Future<List<AdminProduct>> loadProductsOnce() async {
    final snapshot = await _products
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map(AdminProduct.fromDoc).toList();
  }

  Future<String> createProduct(
    AdminProductDraft draft,
    List<AdminUploadFile> images,
  ) async {
    final doc = _products.doc();
    final imageUrls = await _uploadImages(doc.id, images);
    await doc.set(draft.toMap(imageUrls));
    return doc.id;
  }

  Future<void> updateProductStatus(String productId, String status) {
    return _products.doc(productId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProduct(String productId, Map<String, Object?> values) {
    return _products.doc(productId).update({
      ...values,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProduct(String productId) {
    return _products.doc(productId).delete();
  }
  Stream<List<Map<String, dynamic>>> watchAdminChatRooms() {
    return _firestore
        .collection('chatRooms')
        .where('isAdminProduct', isEqualTo: true)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String roomId) {
    return _firestore
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Future<void> sendAdminMessage({
    required String roomId,
    required String sellerName,
    required String text,
  }) async {
    final batch = _firestore.batch();
    final msgRef = _firestore
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .doc();
    batch.set(msgRef, {
      'text': text,
      'senderUid': sellerName,
      'senderNickname': sellerName,
      'createdAt': FieldValue.serverTimestamp(),
      'isAdmin': true,
    });
    batch.update(_firestore.collection('chatRooms').doc(roomId), {
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<List<String>> _uploadImages(
    String productId,
    List<AdminUploadFile> images,
  ) async {
    final urls = <String>[];
    for (var i = 0; i < images.length; i++) {
      final image = images[i];
      final ref = _storage.ref(
        'admin_products/$productId/${DateTime.now().millisecondsSinceEpoch}_${i}_${image.name}',
      );
      final metadata = SettableMetadata(contentType: image.contentType);
      final task = await ref.putData(image.bytes, metadata);
      urls.add(await task.ref.getDownloadURL());
    }
    return urls;
  }
}

class AdminUploadFile {
  const AdminUploadFile({
    required this.name,
    required this.bytes,
    required this.contentType,
  });

  final String name;
  final Uint8List bytes;
  final String contentType;
}

class AdminDashboardRepository {
  AdminDashboardRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<AdminDashboardStats> loadStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final results = await Future.wait([
      _firestore.collection('users').count().get(),
      _firestore.collection('products').count().get(),
      _firestore
          .collection('products')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
          )
          .count()
          .get(),
      _firestore
          .collection('products')
          .where('status', isEqualTo: 'active')
          .count()
          .get(),
      _firestore.collection('reports').count().get(),
    ]);

    return AdminDashboardStats(
      userCount: results[0].count ?? 0,
      productCount: results[1].count ?? 0,
      todayProductCount: results[2].count ?? 0,
      activeProductCount: results[3].count ?? 0,
      reportCount: results[4].count ?? 0,
    );
  }
}

class AdminUserRepository {
  AdminUserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<AdminUserRecord>> watchUsers() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final users = <AdminUserRecord>[];
          for (final doc in snapshot.docs) {
            final count = await _firestore
                .collection('products')
                .where('sellerId', isEqualTo: doc.id)
                .count()
                .get();
            users.add(
              AdminUserRecord.fromDoc(doc, productCount: count.count ?? 0),
            );
          }
          return users;
        });
  }

  Future<void> updateUserStatus(String uid, String status) {
    return _firestore.collection('users').doc(uid).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class AdminTaxonomyRepository {
  AdminTaxonomyRepository(
    this.collectionName,
    this.seedNames, {
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String collectionName;
  final List<String> seedNames;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  Stream<List<AdminTaxonomyItem>> watchItems() {
    return _collection
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(AdminTaxonomyItem.fromDoc).toList(),
        );
  }

  Future<void> ensureSeedData() async {
    final snapshot = await _collection.limit(1).get();
    if (snapshot.docs.isNotEmpty) return;
    final batch = _firestore.batch();
    for (final name in seedNames) {
      batch.set(_collection.doc(name), {
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> addItem(String name) {
    return _collection.doc(name).set({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateItem(String id, String name) async {
    if (id == name) {
      await _collection.doc(id).update({
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    final oldDoc = await _collection.doc(id).get();
    await _collection.doc(name).set({
      ...?oldDoc.data(),
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _collection.doc(id).delete();
  }

  Future<void> deleteItem(String id) {
    return _collection.doc(id).delete();
  }
}

class AdminReportRepository {
  AdminReportRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<AdminReportRecord>> watchReports() {
    return _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(AdminReportRecord.fromDoc).toList(),
        );
  }

  Future<void> updateReportStatus(String id, String status) {
    return _firestore.collection('reports').doc(id).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> hideProduct(String productId) {
    return _firestore.collection('products').doc(productId).update({
      'status': 'hidden',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProduct(String productId) {
    return _firestore.collection('products').doc(productId).delete();
  }

  Future<void> suspendUser(String uid) {
    return _firestore.collection('users').doc(uid).set({
      'status': 'suspended',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
