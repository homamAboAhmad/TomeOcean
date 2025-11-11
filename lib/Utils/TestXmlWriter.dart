import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For rootBundle
import 'package:xml/xml.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

Future<void> writeParagraphXmlToTestAsset(BuildContext context, XmlElement paragraphXml) async {
  final bool? confirm = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Confirm Write to test.xml'),
        content: const Text('Do you want to overwrite test.xml with the XML of this paragraph?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Overwrite'),
          ),
        ],
      );
    },
  );

  if (confirm == true) {
    try {
      // Get the project root directory (assuming it's the current working directory of the Flutter app)
      // This is a simplification for debugging purposes. In a real app, you might use a more robust way
      // to get the project root or a specific debug output directory.
      final String projectRoot = Directory.current.path;
      final String filePath = '$projectRoot/test.xml'; // Save to project root

      final File file = File(filePath);
      await file.writeAsString(paragraphXml.toXmlString(pretty: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paragraph XML written to: $filePath')),
      );
      debugPrint('Paragraph XML written to: $filePath');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to write XML: $e')),
      );
      debugPrint('Failed to write XML: $e');
    }
  }
}
