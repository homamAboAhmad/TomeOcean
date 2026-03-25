import 'package:flutter/material.dart';
import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:golden_shamela/FontsLoaderController.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final String text1 = "أَعْمَالُ عَبْدِ العَزِيزِ بْنِ شَاكِرِ الرَّافِعِي";
  final String text2 = "جَمْعٌ لِمَا وُجِدَ مِنْ كِتَابَاتِهِ وَمُحَاوَرَاتِهِ";
  final String fontFamily = "(A) Arslan Wessam B"; 

  bool _fontsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadFonts();
  }

  Future<void> _loadFonts() async {
    await loadFonts([]); 
    setState(() {
      _fontsLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_fontsLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final reshaperKeepHarakat = ArabicReshaper(
      configuration: const ArabicReshaperConfig(
        deleteHarakat: false,
        supportZwj: true,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Test Font Shaping')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("النص العادي (بدون معالجة):", style: TextStyle(fontSize: 20, color: Colors.red)),
              Text(
                text1,
                style: TextStyle(fontFamily: fontFamily, fontSize: 50),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
              const Divider(height: 50, thickness: 2),
              const Text("النص المعالج (arabic_reshaper) - مع الحركات:", style: TextStyle(fontSize: 20, color: Colors.green)),
              Text(
                reshaperKeepHarakat.reshape(text1),
                style: TextStyle(fontFamily: fontFamily, fontSize: 50),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

