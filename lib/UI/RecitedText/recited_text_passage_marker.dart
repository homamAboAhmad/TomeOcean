const String _firstStrongIsolate = '\u2068';
const String _popDirectionalIsolate = '\u2069';

String recitedTextPassageMarker(int number) {
  return '$_firstStrongIsolate($number)$_popDirectionalIsolate ';
}

String cleanRecitedTextControls(String text) {
  return text.replaceAll(RegExp(r'[\u2066-\u2069]'), '');
}
