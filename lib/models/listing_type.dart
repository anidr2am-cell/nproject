import 'package:flutter/material.dart';

enum ListingType {
  used('중고거래', Icons.shopping_bag_outlined),
  request('해주세요', Icons.flight_takeoff),
  currency('화폐 교환', Icons.currency_exchange);

  const ListingType(this.label, this.icon);

  final String label;
  final IconData icon;
}
