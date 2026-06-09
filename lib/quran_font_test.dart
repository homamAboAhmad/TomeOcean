import 'dart:io';
import 'package:flutter/material.dart';
import 'package:golden_shamela/FontsLoaderController.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:window_manager/window_manager.dart';
import 'package:golden_shamela/core/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1300, 800),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  runApp(const MaterialApp(home: QuranFontTestScreen()));
}

class QuranFontTestScreen extends StatefulWidget {
  const QuranFontTestScreen({Key? key}) : super(key: key);

  @override
  State<QuranFontTestScreen> createState() => _QuranFontTestScreenState();
}

class _QuranFontTestScreenState extends State<QuranFontTestScreen> {
  String status = "Loading fonts...";
  List<String> availableHFSPFonts = [];
  String? selectedFont;

  @override
  void initState() {
    super.initState();
    _loadFonts();
  }

  Future<void> _loadFonts() async {
    try {
      final fontsDir = Directory(AppStoragePaths.sharedFontsPath);
      if (!await fontsDir.exists()) {
        setState(() => status = "Fonts directory not found.");
        return;
      }

      final files = await fontsDir.list().toList();
      Map<String, String> fontsToLoad = {};

      for (var entity in files) {
        if (entity is File &&
            entity.path.endsWith('.ttf') &&
            entity.path.contains('HFS_P')) {
          String fileName = entity.uri.pathSegments.last;
          String familyName = fileName
              .split('_')
              .take(2)
              .join('_'); // Extract HFS_Pxxx

          if (!availableHFSPFonts.contains(familyName)) {
            availableHFSPFonts.add(familyName);
            fontsToLoad[familyName] = entity.path;
          }
        }
      }

      if (fontsToLoad.isEmpty) {
        setState(
          () => status =
              "No HFS_P fonts found in _shared_fonts. Please parse a book first.",
        );
        return;
      }

      await loadExtractedFonts(fontsToLoad);

      setState(() {
        status = "Fonts loaded successfully.";
        selectedFont = availableHFSPFonts.first;
      });
    } catch (e) {
      setState(() => status = "Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quranic Font Test")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text("Status: $status", style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            if (availableHFSPFonts.isNotEmpty)
              DropdownButton<String>(
                value: selectedFont,
                items: availableHFSPFonts.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    selectedFont = newValue;
                  });
                },
              ),
            const SizedBox(height: 40),
            Expanded(
              child: ListView(
                children: [
                  _buildTestText("ﱩﮧ", "Text 1 (ﱩﮧ)"),
                  _buildTestText("ﱩﯬ", "Text 2 (ﱩﯬ)"),
                  _buildTestText("ﱩﭶ", "Text 3 (ﱩﭶ)"),
                  _buildTestText(
                    "ني به ه ه ج ش",
                    "Literal Garbled Text from user screenshot",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestText(String text, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.grey[200],
            child: Text(
              text,
              style: TextStyle(
                fontFamily: selectedFont,
                fontSize: 40,
                color: Colors.black,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
          Text(
            "System Font Fallback:",
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(text, style: const TextStyle(fontSize: 40)),
          const Divider(),
        ],
      ),
    );
  }
}
