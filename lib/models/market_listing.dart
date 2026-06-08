import 'package:flutter/material.dart';
import 'listing_type.dart';

class MarketListing {
  const MarketListing({
    required this.id,
    required this.type,
    this.tradeType = 'sell',
    required this.title,
    required this.category,
    required this.price,
    required this.place,
    required this.placeNote,
    required this.postedAgo,
    required this.sellerNickname,
    this.sellerUid,
    this.status = 'active',
    this.itemName,
    this.currencyDirection,
    this.exchangeRate,
    this.photoUrls = const [],
    required this.tradeCount,
    required this.description,
    required this.icon,
    required this.color,
    this.photoCount = 1,
    this.contactNote,
    this.kakaoId,
    this.lineId,
    this.previousTrades = const [],
  });

  final String id;
  final ListingType type;
  final String tradeType;
  final String title;
  final String category;
  final String price;
  final String place;
  final String placeNote;
  final String postedAgo;
  final String sellerNickname;
  final String? sellerUid;
  final String status;
  final String? itemName;
  final String? currencyDirection;
  final String? exchangeRate;
  final List<String> photoUrls;
  final int tradeCount;
  final String description;
  final IconData icon;
  final Color color;
  final int photoCount;
  final String? contactNote;
  final String? kakaoId;
  final String? lineId;
  final List<String> previousTrades;
}
