import 'package:flutter/material.dart';
import '../models/market_listing.dart';
import '../constants/colors.dart';
import '../services/firebase_service.dart';
import 'common_widgets.dart';

class ListingTile extends StatelessWidget {
  const ListingTile({required this.listing, required this.onTap, super.key});

  final MarketListing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = listing.photoUrls.isNotEmpty
        ? listing.photoUrls.first
        : null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: listing.id,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: listing.color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: imageUrl == null
                    ? Icon(listing.icon, color: Colors.white, size: 34)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Icon(listing.icon, color: Colors.white, size: 34),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            // [1] 메인 콘텐츠 Column을 Expanded로 감싸서 남은 가로 공간을 모두 활용하게 함
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // [2] 제목 부분을 Expanded로 감싸서 긴 제목 대응
                      Expanded(
                        child: Text(
                          listing.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // [3] 우측 상태 태그 (고정 크기 유지)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TypePill(text: listing.type.label),
                          const SizedBox(height: 4),
                          Text(
                            listing.status == 'sold'
                                ? '판매완료'
                                : listing.status == 'reserved'
                                ? '거래 예약중'
                                : '판매중',
                            style: TextStyle(
                              color: listing.status == 'active'
                                  ? brandOrange
                                  : muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // [4] 지역 정보 및 시간 정보 (Expanded 처리된 Column 내부이므로 자동 대응)
                  Text(
                    '${listing.place} · ${listing.postedAgo}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  // [5] 가격 정보
                  Text(
                    listing.price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: brandSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // [6] 판매자 및 거래 횟수 정보
                  _SellerTradeLine(listing: listing),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellerTradeLine extends StatelessWidget {
  const _SellerTradeLine({required this.listing});

  final MarketListing listing;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: muted, fontSize: 12);
    
    // FutureBuilder 내부의 Text 위젯에도 overflow 설정을 적용합니다.
    if (!needsSellerNicknameLookup(listing) ||
        listing.sellerUid?.trim().isNotEmpty != true) {
      return Text(
        '${listing.sellerNickname} · 거래 ${listing.tradeCount}회',
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return FutureBuilder<String>(
      future: resolveSellerNickname(listing),
      builder: (context, snapshot) {
        final nickname = snapshot.data ?? listing.sellerNickname;
        return Text(
          '$nickname · 거래 ${listing.tradeCount}회',
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
