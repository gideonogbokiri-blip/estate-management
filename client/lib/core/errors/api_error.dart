import '../utils/formatters.dart';

/// Maps API exceptions to short, user-safe messages in one place.
abstract final class ApiErrorText {
  static String message(Object error, {String fallback = 'The request could not be completed.'}) {
    if (error is Exception) {
      final text = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      if (text.isNotEmpty && text.length < 240) return text;
    }
    return fallback;
  }

  static String money(Object error) => ApiErrorText.message(
        error,
        fallback: 'The financial service could not complete this request.',
      );

  static String report(String value) => AppFormat.amount(value);
}
