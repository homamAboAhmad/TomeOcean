void main() {
  String value = "6in";
  double val = 0;
  if (value.endsWith("pt")) {
    val = double.tryParse(value.replaceAll("pt", "")) ?? 0;
    val = val * 1.333;
  } else if (value.endsWith("px")) {
    val = double.tryParse(value.replaceAll("px", "")) ?? 0;
  } else {
    val = double.tryParse(value) ?? 0;
  }
  print(val);
}
