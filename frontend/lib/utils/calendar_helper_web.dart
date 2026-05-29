import 'dart:js_interop';
import 'package:web/web.dart' as web;

void addClimbToCalendar({
  required String title,
  required DateTime start,
  required String location,
  required String description,
}) {
  final end = start.add(const Duration(hours: 2));
  final ics = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Hookd//Hookd//EN',
    'BEGIN:VEVENT',
    'DTSTART:${_fmt(start.toUtc())}',
    'DTEND:${_fmt(end.toUtc())}',
    'SUMMARY:${_escape(title)}',
    'LOCATION:${_escape(location)}',
    'DESCRIPTION:${_escape(description)}',
    'END:VEVENT',
    'END:VCALENDAR',
  ].join('\r\n');

  final blob = web.Blob(
    [ics.toJS].toJS,
    web.BlobPropertyBag(type: 'text/calendar'),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement;
  a.href = url;
  a.setAttribute('download', 'climb.ics');
  a.click();
  web.URL.revokeObjectURL(url);
}

String _fmt(DateTime dt) =>
    '${_p(dt.year, 4)}${_p(dt.month)}${_p(dt.day)}'
    'T${_p(dt.hour)}${_p(dt.minute)}00Z';

String _p(int v, [int w = 2]) => v.toString().padLeft(w, '0');

String _escape(String s) =>
    s.replaceAll(r'\', r'\\').replaceAll(',', r'\,').replaceAll('\n', r'\n');
