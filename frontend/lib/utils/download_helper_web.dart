import 'dart:html' as html;
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> downloadCsv(String csvContent, String fileName) async {
  final encoder = web.TextEncoder();
  final jsBytes = encoder.encode(csvContent);
  final blob = web.Blob(
    [jsBytes].toJS,
    web.BlobPropertyBag(type: 'text/csv'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

Future<void> downloadBytes(List<int> bytes, String fileName, String mimeType) async {
  final blob = html.Blob([bytes], mimeType, 'transparent');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
