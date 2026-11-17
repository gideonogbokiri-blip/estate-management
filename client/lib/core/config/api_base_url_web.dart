import 'dart:html' as html;

/// Web builds can set `data-api-base` on the document element before Flutter
/// starts. This lets one set of bundles run on any host without rebuilding.
String? runtimeApiBaseUrl() {
  final value = html.document.documentElement?.getAttribute('data-api-base');
  return value != null && value.isNotEmpty ? value : null;
}
