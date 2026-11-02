import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/src/pdf/font/ttf_parser.dart';

void main() {
  test('reproduce U+FEF1 zero-width in Tajawal via TtfParser', () async {
    final fontBoldData =
        File('assets/fonts/Tajawal-Bold.ttf').readAsBytesSync();
    final parser = TtfParser(fontBoldData.buffer.asByteData());

    print('fontName: ${parser.fontName}');
    print('unicode: ${parser.unicode}');

    int gidFEF1 = parser.charToGlyphIndexMap[0xFEF1] ?? -1;
    int gidFEF2 = parser.charToGlyphIndexMap[0xFEF2] ?? -1;
    int gid064A = parser.charToGlyphIndexMap[0x064A] ?? -1;
    int gidFEAD = parser.charToGlyphIndexMap[0xFEAD] ?? -1;
    int gid0631 = parser.charToGlyphIndexMap[0x0631] ?? -1;

    print('charToGlyphIndexMap[FEF1] = $gidFEF1');
    print('charToGlyphIndexMap[FEF2] = $gidFEF2');
    print('charToGlyphIndexMap[064A] = $gid064A');
    print('charToGlyphIndexMap[FEAD] = $gidFEAD');
    print('charToGlyphIndexMap[0631] = $gid0631');

    if (gidFEF1 >= 0) {
      final info = parser.glyphInfoMap[gidFEF1];
      print('glyphInfoMap[FEF1 gid=$gidFEF1] = $info');
    }
    if (gidFEF2 >= 0) {
      final info = parser.glyphInfoMap[gidFEF2];
      print('glyphInfoMap[FEF2 gid=$gidFEF2] = $info');
    }
    if (gid064A >= 0) {
      final info = parser.glyphInfoMap[gid064A];
      print('glyphInfoMap[064A gid=$gid064A] = $info');
    }

    print('total chars in map: ${parser.charToGlyphIndexMap.length}');
  });
}
