import 'package:test/test.dart';

// Simulate the fixed _parseUnit function
double _parseUnit(String value) {
  double val = 0;
  if (value.endsWith('pt')) {
    val = double.tryParse(value.replaceAll('pt', '')) ?? 0;
    val = val * 1.333;
  } else if (value.endsWith('px')) {
    val = double.tryParse(value.replaceAll('px', '')) ?? 0;
  } else if (value.endsWith('in')) {
    val = double.tryParse(value.replaceAll('in', '')) ?? 0;
    val = val * 96.0; // inches to pixels
  } else {
    val = double.tryParse(value) ?? 0;
  }
  return val;
}

void main() {
  test('VML image width 6in should parse to 576 pixels', () {
    double width = _parseUnit('6in');
    expect(width, equals(576.0)); // 6 * 96 = 576
  });

  test('VML image height 593.4pt should parse to ~791 pixels', () {
    double height = _parseUnit('593.4pt');
    expect(height, closeTo(593.4 * 1.333, 0.1)); // ~791.1
  });

  test('Mixed units: width in inches, height in points', () {
    double width = _parseUnit('6in');
    double height = _parseUnit('593.4pt');
    expect(width, greaterThan(0));
    expect(height, greaterThan(0));
  });

  test('Edge case: 0 inches', () {
    double val = _parseUnit('0in');
    expect(val, equals(0.0));
  });

  test('Edge case: fractional inches', () {
    double val = _parseUnit('2.5in');
    expect(val, equals(240.0)); // 2.5 * 96 = 240
  });
}
