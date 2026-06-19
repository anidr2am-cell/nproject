import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/colors.dart';
import '../services/firebase_service.dart';
import '../utils/price_formatter.dart';
import 'login_screen.dart';

class RealEstateWriteScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? initialData;

  const RealEstateWriteScreen({this.docId, this.initialData, super.key});

  @override
  State<RealEstateWriteScreen> createState() => _RealEstateWriteScreenState();
}

class _RealEstateWriteScreenState extends State<RealEstateWriteScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  String _dealType = '매매';
  String _propertyType = '아파트';
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _depositController = TextEditingController();
  final _monthlyRentController = TextEditingController();
  final _areaController = TextEditingController();
  final _roomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _floorController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _pickedPhotos = [];
  final List<Uint8List> _photoBytesList = [];
  final List<String> _existingPhotoUrls = [];
  final List<String> _propertyTypes = ['아파트', '콘도', '주택', '상가'];

  bool get _isEditMode => widget.docId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode && widget.initialData != null) {
      final data = widget.initialData!;
      _dealType = data['dealType'] ?? '매매';
      _propertyType = data['propertyType'] ?? '아파트';
      _titleController.text = data['title'] ?? '';
      _priceController.text = formatPriceInput(data['price']);
      _depositController.text = formatPriceInput(data['deposit']);
      _monthlyRentController.text = formatPriceInput(data['monthlyRent']);
      _areaController.text = data['area'] ?? '';
      _roomsController.text = data['rooms'] ?? '';
      _bathroomsController.text = data['bathrooms'] ?? '';
      _floorController.text = data['floor'] ?? '';
      _addressController.text = data['address'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      if (data['photoUrls'] != null) {
        _existingPhotoUrls.addAll(List<String>.from(data['photoUrls']));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _depositController.dispose();
    _monthlyRentController.dispose();
    _areaController.dispose();
    _roomsController.dispose();
    _bathroomsController.dispose();
    _floorController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final totalPhotos = _pickedPhotos.length + _existingPhotoUrls.length;
    if (totalPhotos >= 10) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사진은 최대 10장까지 등록 가능합니다.')));
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
        'realEstate/$userId/$timestamp/${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
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
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final newPhotoUrls = await _uploadPhotos(user.uid);
      final finalPhotoUrls = [..._existingPhotoUrls, ...newPhotoUrls];
      final nickname = await fetchNicknameForUid(
        user.uid,
        fallback: user.displayName ?? '익명',
      );

      final data = {
        'dealType': _dealType,
        'propertyType': _propertyType,
        'title': _titleController.text.trim(),
        'price': _dealType == '매매'
            ? normalizePriceInput(_priceController.text)
            : '',
        'deposit': _dealType == '월세'
            ? normalizePriceInput(_depositController.text)
            : '',
        'monthlyRent': _dealType == '월세'
            ? normalizePriceInput(_monthlyRentController.text)
            : '',
        'area': _areaController.text.trim(),
        'rooms': _roomsController.text.trim(),
        'bathrooms': _bathroomsController.text.trim(),
        'floor': _floorController.text.trim(),
        'address': _addressController.text.trim(),
        'description': _descriptionController.text.trim(),
        'photoUrls': finalPhotoUrls,
        'sellerUid': user.uid,
        'sellerNickname': nickname,
        if (!_isEditMode) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'available',
      };

      if (_isEditMode) {
        await FirebaseFirestore.instance
            .collection('realEstate')
            .doc(widget.docId)
            .update(data);
      } else {
        await FirebaseFirestore.instance.collection('realEstate').add(data);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? '매물이 수정되었습니다.' : '매물이 등록되었습니다.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting real estate: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('처리 중 오류가 발생했습니다: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? '매물 수정' : '매물 등록',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isSubmitting)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _submit,
              child: Text(
                _isEditMode ? '수정' : '등록',
                style: const TextStyle(
                  color: brandPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
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
            _buildLabel('거래 유형'),
            Row(
              children: [
                _buildTypeChip('매매'),
                const SizedBox(width: 12),
                _buildTypeChip('월세'),
              ],
            ),
            const SizedBox(height: 20),
            _buildLabel('부동산 종류'),
            DropdownButtonFormField<String>(
              value: _propertyType,
              items: _propertyTypes
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _propertyType = val!),
              decoration: _inputDecoration('종류 선택'),
            ),
            const SizedBox(height: 20),
            _buildLabel('제목'),
            TextFormField(
              controller: _titleController,
              decoration: _inputDecoration('제목을 입력하세요'),
              validator: (v) => v!.isEmpty ? '제목을 입력해주세요' : null,
            ),
            const SizedBox(height: 20),
            if (_dealType == '매매') ...[
              _buildLabel('매매가'),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [PriceInputFormatter()],
                decoration: _inputDecoration('매매가를 입력하세요 (예: 15억)'),
                validator: (v) =>
                    _dealType == '매매' && v!.isEmpty ? '매매가를 입력해주세요' : null,
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('보증금'),
                        TextFormField(
                          controller: _depositController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [PriceInputFormatter()],
                          decoration: _inputDecoration('보증금'),
                          validator: (v) =>
                              _dealType == '월세' && v!.isEmpty ? '입력 필수' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('월세'),
                        TextFormField(
                          controller: _monthlyRentController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [PriceInputFormatter()],
                          decoration: _inputDecoration('월세'),
                          validator: (v) =>
                              _dealType == '월세' && v!.isEmpty ? '입력 필수' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('평수 (㎡)'),
                      TextFormField(
                        controller: _areaController,
                        decoration: _inputDecoration('㎡'),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('층수'),
                      TextFormField(
                        controller: _floorController,
                        decoration: _inputDecoration('층'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('방 개수'),
                      TextFormField(
                        controller: _roomsController,
                        decoration: _inputDecoration('개'),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('욕실 개수'),
                      TextFormField(
                        controller: _bathroomsController,
                        decoration: _inputDecoration('개'),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildLabel('주소'),
            TextFormField(
              controller: _addressController,
              decoration: _inputDecoration('상세 주소를 입력하세요'),
              validator: (v) => v!.isEmpty ? '주소를 입력해주세요' : null,
            ),
            const SizedBox(height: 20),
            _buildLabel('상세 설명'),
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: _inputDecoration('매물에 대한 상세 설명을 입력하세요'),
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
        _buildLabel('사진 (최대 10장)'),
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
                      Text(
                        '${_pickedPhotos.length + _existingPhotoUrls.length}/10',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              // Existing photos
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
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              // Newly picked photos
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
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    final isSelected = _dealType == type;
    return ChoiceChip(
      label: Text(type),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _dealType = type);
      },
      selectedColor: brandPrimary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : brandInk,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? brandPrimary : brandBorder),
      ),
      showCheckmark: false,
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: brandMuted, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: brandBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: brandBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: brandPrimary, width: 1.4),
      ),
    );
  }
}
