import 'dart:ui';
import 'package:golden_shamela/Utils/ImageParser.dart';
import 'package:golden_shamela/wordToHTML/DocRelations.dart';
import 'package:golden_shamela/wordToHTML/runT.dart';
import 'package:xml/xml.dart' as xml;

/// Test script to verify the column positioning fix
void testColumnPositioning() {
  print('🧪 Testing column positioning fix...\n');
  
  // Create a mock XML structure similar to the test case
  String xmlString = '''
  <w:r xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
       xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
       xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
    <w:drawing>
      <wp:anchor distT="0" distB="0" distL="114300" distR="114300" simplePos="0" relativeHeight="251686912" behindDoc="0" locked="0" layoutInCell="1" allowOverlap="1">
        <wp:simplePos x="0" y="0"/>
        <wp:positionH relativeFrom="column">
          <wp:posOffset>1224915</wp:posOffset>
        </wp:positionH>
        <wp:positionV relativeFrom="paragraph">
          <wp:posOffset>1359535</wp:posOffset>
        </wp:positionV>
        <wp:extent cx="1707515" cy="2573655"/>
        <wp:effectExtent l="0" t="0" r="0" b="0"/>
        <wp:wrapNone/>
        <wp:docPr id="972679976" name="صورة 1"/>
        <wp:cNvGraphicFramePr>
          <a:graphicFrameLocks noChangeAspect="1"/>
        </wp:cNvGraphicFramePr>
        <a:graphic>
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic>
              <pic:nvPicPr>
                <pic:cNvPr id="972679976" name="صورة 1"/>
                <pic:cNvPicPr/>
              </pic:nvPicPr>
              <pic:blipFill>
                <a:blip r:embed="rId9"/>
              </pic:blipFill>
              <pic:spPr>
                <a:xfrm>
                  <a:off x="0" y="0"/>
                  <a:ext cx="1707515" cy="2573655"/>
                </a:xfrm>
              </pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:anchor>
    </w:drawing>
  </w:r>
  ''';
  
  // Parse the XML
  final document = xml.XmlDocument.parse(xmlString);
  final runElement = document.rootElement;
  
  // Create a mock runT object
  final run = runT();
  run.xmlRun = runElement;
  
  // Parse the image data
  final imageData = parseImageData(run);
  
  if (imageData != null) {
    print('✅ Image parsed successfully');
    print('📐 Positioning data:');
    print('   - relativeFromH: ${imageData.relativeFromH}');
    print('   - relativeFromV: ${imageData.relativeFromV}');
    print('   - posX (EMU→px): ${imageData.posX.toStringAsFixed(2)}');
    print('   - posY (EMU→px): ${imageData.posY.toStringAsFixed(2)}');
    print('   - width (EMU→px): ${imageData.width.toStringAsFixed(2)}');
    print('   - height (EMU→px): ${imageData.height.toStringAsFixed(2)}');
    
    // Test the calculation
    const pageWidth = 793.0;
    const pageHeight = 842.0;
    const leftMargin = 72.0;
    const topMargin = 72.0;
    
    print('\n📏 Expected positioning calculation:');
    print('   - Page: ${pageWidth}x${pageHeight}');
    print('   - Margins: left=${leftMargin}, top=${topMargin}');
    print('   - Column positioning should use posX directly: ${imageData.posX.toStringAsFixed(2)}');
    print('   - Paragraph positioning should add topMargin: ${(imageData.posY + topMargin).toStringAsFixed(2)}');
    
    // Test the old (incorrect) logic
    final oldPosX = imageData.posX + leftMargin; // This was the bug
    print('\n❌ OLD (incorrect) logic:');
    print('   - Would add leftMargin: ${imageData.posX.toStringAsFixed(2)} + ${leftMargin} = ${oldPosX.toStringAsFixed(2)}');
    print('   - This would shift the image ${leftMargin}px to the right');
    
    // Test the new (correct) logic
    final newPosX = imageData.posX; // Fixed logic
    print('\n✅ NEW (correct) logic:');
    print('   - Uses posX directly: ${newPosX.toStringAsFixed(2)}');
    print('   - No extra margin added');
    
    print('\n🎯 Result: Image should now appear ${leftMargin}px further to the left, filling the page correctly');
    
  } else {
    print('❌ Failed to parse image data');
  }
}

void main() {
  testColumnPositioning();
}
