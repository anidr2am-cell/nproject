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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brandBorder, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: listing.id,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: listing.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: imageUrl == null
                      ? Icon(listing.icon, color: Colors.white, size: 34)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            listing.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: brandPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                                    ? brandPrimary
                                    : brandMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${listing.place} · ${listing.postedAgo}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: brandMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      listing.price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: brandSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SellerTradeLine(listing: listing),
                  ],
                ),
              ),
            ],
          ),
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
