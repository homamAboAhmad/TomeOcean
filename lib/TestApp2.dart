import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Testapp2 extends StatefulWidget {
  const Testapp2({super.key});

  @override
  State<Testapp2> createState() => _Testapp2State();
}

class _Testapp2State extends State<Testapp2> {
  @override
  Widget build(BuildContext context) {
    List<InlineSpan> spans = [
      TextSpan(text: "هذا نص أول ", style: TextStyle(color: Colors.black)),
      WidgetSpan(child: Text("هذا نص ثانٍ")),
      TextSpan(text: "هذا نص ثالث ", style: TextStyle(color: Colors.black)),
     // WidgetSpan(child: Text(" هذا نص رابع ")),
      TextSpan(text: "هذا نص خامس ", style: TextStyle(color: Colors.black)),
    ];
    spans = fixRtlWidgetSpan(spans);
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: RichText(
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.justify,
              text: TextSpan(children: spans)),
        ),
      ),
    );
  }
}

fixRtlWidgetSpan(List<InlineSpan> list) {
  if(!_needToFix(list)) return list;
  Map<int, InlineSpan> map = toWidgetSpanMap(list);
  Map<int, InlineSpan> reversedMap = reverseValues(map);
  reversedMap.forEach((i, widget) {
    list[i] = widget;
  });
  return list;
}

bool _needToFix(List<InlineSpan> list) {
  int count = list.where((item)=>item is WidgetSpan).length;
  return count>1;
}

Map<int, InlineSpan> toWidgetSpanMap(List<InlineSpan> list) {
  Map<int, InlineSpan> map = {};
  for (int i = 0; i < list.length; i++) {
    if (list[i] is WidgetSpan) map[i] = list[i];
  }
  return map;
}

Map<K, V> reverseValues<K, V>(Map<K, V> map) {
  List<V> reversedValues = map.values.toList().reversed.toList();
  return Map.fromIterables(map.keys, reversedValues);
}
