import 'dart:convert';
import 'dart:html' as html;

/// Opens a CSV export in the browser as a file download.
/// All LANCON client targets are web builds.
void downloadReportCsv(String filename, String csv) {
  final blob = html.Blob([utf8.encode(csv)], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
