/// Shared formatting helpers so every dashboard and service page renders
/// money and dates consistently.
abstract final class AppFormat {
  static String money(dynamic value, {String currency = 'NGN'}) {
    final amount = double.tryParse(value.toString()) ?? 0;
    final text = amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '$currency $text';
  }

  static String amount(dynamic value) {
    final amount = double.tryParse(value.toString()) ?? 0;
    return amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
  }

  static String date(String? value) {
    if (value == null || value.isEmpty) return '—';
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }
}
