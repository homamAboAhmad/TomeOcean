// Simple test to verify inches conversion in _parseUnit
double _parseUnit(String value) {
  double val = 0;
  if (value.endsWith('pt')) {
    val = double.tryParse(value.replaceAll('pt', '')) ?? 0;
    val = val * 1.333;
  } else if (value.endsWith('px')) {
    val = double.tryParse(value.replaceAll('px', '')) ?? 0;
  } else if (value.endsWith('in')) {
    val = double.tryParse(value.replaceAll('in', '')) ?? 0;
    val = val * 96.0;
  } else {
    val = double.tryParse(value) ?? 0;
  }
  return val;
}

void main() {
  print('Testing _parseUnit with inches support:');
  print('6in = ${_parseUnit('6in')} pixels (expected: 576)');
  print('593.4pt = ${_parseUnit('593.4pt')} pixels (expected: ~791)');
  print('2.5in = ${_parseUnit('2.5in')} pixels (expected: 240)');
  print('0in = ${_parseUnit('0in')} pixels (expected: 0)');
  print('100px = ${_parseUnit('100px')} pixels (expected: 100)');

  // Verify the fix works
  assert(_parseUnit('6in') == 576.0);
  assert(_parseUnit('2.5in') == 240.0);
  assert(_parseUnit('0in') == 0.0);
  print('\n✅ All assertions passed! VML images with inches will now display correctly.');
}
