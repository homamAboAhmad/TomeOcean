import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart' as xml;
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/wordToHTML/Paragraph.dart';
import 'package:golden_shamela/wordToHTML/runT.dart'; // Import runT
import 'package:golden_shamela/Utils/ImageParser.dart'; // Import ImageParser
import 'package:golden_shamela/WordToWidget/ImageToWidget.dart'; // Import ImageToWidget
import 'package:archive/archive.dart';
import 'package:golden_shamela/wordToHTML/AddDocData.dart';
import 'package:flutter/foundation.dart';


class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  WordDocument? _wordDocument;
  Widget? _renderedContent; // To hold the dynamically rendered widget
  bool _isLoading = true;
  String _error = '';
  String _rawXmlContent = ''; // To store raw XML for display

  @override
  void initState() {
    super.initState();
    _loadTestXml();
  }

  Future<void> _loadTestXml() async {
    debugPrint('Executing _loadTestXml() with updated parsing logic.');
    try {
      String xmlString;
      // Get the project root directory
      final String projectRoot = Directory.current.path;
      final String filePathInProjectRoot = '$projectRoot/test.xml';
      final File fileInProjectRoot = File(filePathInProjectRoot);

      if (await fileInProjectRoot.exists()) {
        xmlString = await fileInProjectRoot.readAsString();
        debugPrint('Loaded test.xml from project root: $filePathInProjectRoot');
      } else {
        // Fallback to assets if file doesn't exist in project root
        xmlString = await rootBundle.loadString('test.xml');
        debugPrint('Loaded test.xml from assets.');
      }

      _rawXmlContent = xmlString; // Store raw XML
      final xml.XmlDocument document = xml.XmlDocument.parse(xmlString);
      final xml.XmlElement rootElement = document.rootElement;

      _wordDocument = WordDocument();
      _wordDocument!.title = "Test Document";
      final WordPage testPage = WordPage(_wordDocument!); // Create a single page for testing

      // Attempt to render based on the root element type
      if (rootElement.name.local == "p") {
        final Paragraph paragraph = Paragraph(testPage).fromXml(rootElement);
        _renderedContent = paragraph.toWidget();
      } else if (rootElement.name.local == "r") {
        // For a run, we need a dummy paragraph to create it
        final Paragraph dummyParagraph = Paragraph(testPage);
        final runT run = runT(dummyParagraph, prPr: null, pPr: null).fromXml(rootElement);
        _renderedContent = Text.rich(run.toWidget()); // Render run as rich text
      } else if (rootElement.name.local == "drawing") { // Assuming w:drawing is the root
        // For a drawing, we need a dummy run to parse it
        final Paragraph dummyParagraph = Paragraph(testPage);
        final runT dummyRun = runT(dummyParagraph, prPr: null, pPr: null);
        dummyRun.xmlRun = xml.XmlElement(xml.XmlName('w:r'), [], [rootElement]); // Wrap drawing in a dummy run
        final ImageData? imageData = parseImageData(dummyRun);
        if (imageData != null) {
          _renderedContent = getImageWidget(imageData);
        } else {
          _error = "Failed to parse image data from w:drawing element.";
        }
      } else if (rootElement.name.local == "sdt") {
        final xml.XmlElement? sdtContent = rootElement.findAllElements('w:sdtContent').firstOrNull;
        if (sdtContent != null) {
          final List<Widget> childrenWidgets = [];
          for (final xml.XmlElement childElement in sdtContent.children.whereType<xml.XmlElement>()) {
            if (childElement.name.local == "p") {
              final Paragraph paragraph = Paragraph(testPage).fromXml(childElement);
              childrenWidgets.add(paragraph.toWidget());
            }
            else {
              childrenWidgets.add(Text('Unsupported element in sdtContent: ${childElement.name.local}'));
            }
          }
          _renderedContent = Column(children: childrenWidgets);
        } else {
          _error = "w:sdt element does not contain w:sdtContent.";
        }
      } else {
        _error = "Unsupported root element for direct rendering: ${rootElement.name.local}";
      }

    } catch (e) {
      _error = 'Failed to load or parse test.xml: ${e.toString()}';
      debugPrint(_error);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Error: $_error'); // Keep this debugPrint for console visibility
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Screen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.code),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Raw XML Content'),
                  content: SingleChildScrollView(
                    child: Text(_rawXmlContent),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(
                  'Error: $_error',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ))
              : _renderedContent ?? const Center(child: Text('No content to display.')),
    );
  }
}
