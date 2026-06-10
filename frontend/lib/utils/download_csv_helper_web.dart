import 'dart:js_interop';
import 'package:web/web.dart' as web;

void downloadCsvFile(String filename, String csvContent) {
  final blob = web.Blob(
    [csvContent.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement;
  a.href = url;
  a.setAttribute('download', filename);
  a.click();
  web.URL.revokeObjectURL(url);
}
