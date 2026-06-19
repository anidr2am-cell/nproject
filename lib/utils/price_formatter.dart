import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _priceFormatter = NumberFormat('#,###');

String formatPrice(Object? price) {
  if (price == null) return '';
  if (price is num) return '฿${_priceFormatter.format(price)}';

  final text = price.toString().trim();
  if (text.isEmpty) return '';

  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return text;

  final numericPrice = num.tryParse(digits);
  if (numericPrice == null) return text;

  return '฿${_priceFormatter.format(numericPrice)}';
}

String normalizePriceInput(String price) {
  return price.replaceAll(RegExp(r'[^0-9]'), '');
}

String formatPriceInput(Object? price) {
  if (price == null) return '';
  final digits = normalizePriceInput(price.toString());
  if (digits.isEmpty) return '';

  final numericPrice = num.tryParse(digits);
  if (numericPrice == null) return '';

  return _priceFormatter.format(numericPrice);
}

class PriceInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = normalizePriceInput(newValue.text);
    if (digits.isEmpty) {
      return const TextEditingValue();
    }

    final formatted = _priceFormatter.format(num.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
