import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/colors.dart';
import '../constants/categories.dart';
import '../models/listing_type.dart';
import '../models/market_listing.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';

class PostListingScreen extends StatefulWidget {
  final String? editingListingId;
  final MarketListing? initialListing;
  final VoidCallback? onSubmitSuccess;

  const PostListingScreen({
    this.editingListingId,
    this.initialListing,
    this.onSubmitSuccess,
    super.key,
  });

  bool get isEditing => editingListingId != null;

  @override
  State<PostListingScreen> createState() => _PostListingScreenState();
}

class _PostListingScreenState extends State<PostListingScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _placeController = TextEditingController();
  final _descriptionController = TextEditingController();

  ListingType _type = ListingType.used;
  String _category = categories.first;

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _pickedPhotos = [];
  final List<Uint8List> _photoBytesList = [];
  final List<String> _existingPhotoUrls = [];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.initialListing != null) {
      final listing = widget.initialListing!;
      _titleController.text = listing.title;
      _priceController.text = listing.price;
      _placeController.text = listing.place;
      _descriptionController.text = listing.description;
      _type = listing.type;
      if (categories.contains(listing.category)) {
        _category = listing.category;
      }
      _existingPhotoUrls.addAll(listing.photoUrls);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _placeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final totalPhotos = _pickedPhotos.length + _existingPhotoUrls.length;
    if (totalPhotos >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진은 최대 10장까지 등록 가능합니다.')),
      );
      return;
    }

    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (picked.isNotEmpty) {
        final remaining = 10 - totalPhotos;
        final toAdd = picked.take(remaining).toList();
        
        final List<Uint8List> newBytes = [];
        for (var file in toAdd) {
          newBytes.add(await file.readAsBytes());
        }

        setState(() {
          _pickedPhotos.addAll(toAdd);
          _photoBytesList.addAll(newBytes);
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  void _removePickedImage(int index) {
    setState(() {
      _pickedPhotos.removeAt(index);
      _photoBytesList.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingPhotoUrls.removeAt(index);
    });
  }

  Future<List<String>> _uploadPhotos(String userId) async {
    final uploadedUrls = <String>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < _pickedPhotos.length; i++) {
      final bytes = _photoBytesList[i];

      final ref = FirebaseStorage.instance.ref().child(
        'listings/$userId/$timestamp/${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
      );

      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      uploadedUrls.add(url);
    }
    return uploadedUrls;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final newPhotoUrls = await _uploadPhotos(user.uid);
      final finalPhotoUrls = [..._existingPhotoUrls, ...newPhotoUrls];
      final nickname = await fetchNicknameForUid(user.uid, fallback: user.displayName ?? '익명');

      final data = {
        'type': _type.name,
        'title': _titleController.text.trim(),
        'price': _priceController.text.trim(),
        'place': _placeController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _type == ListingType.used ? _category : _type.label,
        'photoUrls': finalPhotoUrls,
        'sellerUid': user.uid,
        'sellerNickname': nickname,
        if (!widget.isEditing) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': widget.initialListing?.status ?? 'active',
      };

      if (widget.isEditing) {
        await FirebaseFirestore.instance.collection('listings').doc(widget.editingListingId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('listings').add(data);
      }

      if (mounted) {
        if (widget.onSubmitSuccess != null) {
          widget.onSubmitSuccess!();
        } else {
          Navigator.of(context).pop(true);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isEditing ? '글이 수정되었습니다.' : '글이 등록되었습니다.')),
        );
      }
    } catch (e) {
      debugPrint('Error submitting listing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('처리 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '글 수정' : '중고거래 글쓰기', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isSubmitting)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else
            TextButton(
              onPressed: _submit,
              child: Text(widget.isEditing ? '수정' : '완료', style: const TextStyle(color: brandOrange, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildPhotoPicker(),
            const SizedBox(height: 24),
            const Text('카테고리', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _category,
              items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
              onChanged: (val) => setState(() => _category = val!),
              decoration: _inputDecoration('카테고리 선택'),
            ),
            const SizedBox(height: 20),
            const Text('제목', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: _inputDecoration('제목을 입력하세요'),
              validator: (v) => v!.isEmpty ? '제목을 입력해주세요' : null,
            ),
            const SizedBox(height: 20),
            const Text('가격', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _priceController,
              decoration: _inputDecoration('가격을 입력하세요 (예: 10,000원)'),
              validator: (v) => v!.isEmpty ? '가격을 입력해주세요' : null,
            ),
            const SizedBox(height: 20),
            const Text('거래 장소', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _placeController,
              decoration: _inputDecoration('거래 장소를 입력하세요'),
            ),
            const SizedBox(height: 20),
            const Text('상세 설명', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 8,
              decoration: _inputDecoration('게시글 내용을 입력하세요'),
              validator: (v) => v!.isEmpty ? '내용을 입력해주세요' : null,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('사진 (최대 10장)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              InkWell(
                onTap: _pickImages,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt, color: muted),
                      Text('${_pickedPhotos.length + _existingPhotoUrls.length}/10', style: const TextStyle(color: muted, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              ...List.generate(_existingPhotoUrls.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(_existingPhotoUrls[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => _removeExistingImage(index),
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              ...List.generate(_pickedPhotos.length, (index) {
                final bytes = _photoBytesList[index];
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: MemoryImage(bytes),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => _removePickedImage(index),
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: brandOrange)),
    );
  }
}
