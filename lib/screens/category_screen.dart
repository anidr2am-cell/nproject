import 'package:flutter/material.dart';
import '../constants/categories.dart';
import '../constants/colors.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('카테고리'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 24,
          crossAxisSpacing: 20,
          childAspectRatio: 0.75,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return InkWell(
            onTap: () {
              // TODO: 카테고리별 검색 결과 화면으로 이동
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getCategoryIcon(category),
                    size: 30,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    category,
                    textAlign: TextAlign.center,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    return switch (category) {
      '디지털기기' => Icons.laptop_mac_outlined,
      '생활가전' => Icons.kitchen_outlined,
      '가구/인테리어' => Icons.chair_outlined,
      '생활/주방' => Icons.flatware_outlined,
      '유아동' => Icons.child_care_outlined,
      '여성패션/잡화' => Icons.checkroom_outlined,
      '남성패션/잡화' => Icons.dry_cleaning_outlined,
      '뷰티/미용' => Icons.face_retouching_natural_outlined,
      '스포츠/레저' => Icons.sports_tennis_outlined,
      '취미/게임/음반' => Icons.videogame_asset_outlined,
      '도서' => Icons.menu_book_outlined,
      '반려동물용품' => Icons.pets_outlined,
      '회원권' => Icons.confirmation_number_outlined,
      _ => Icons.more_horiz_outlined,
    };
  }
}
