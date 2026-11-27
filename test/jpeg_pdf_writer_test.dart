import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_tool/jpeg_pdf_writer.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('jpeg_pdf_writer_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('writes a valid PDF with one image per page', () async {
    final jpeg = img.encodeJpg(img.Image(width: 20, height: 30), quality: 50);
    final path = '${dir.path}/out.pdf';

    final writer = await JpegPdfWriter.open(path);
    await writer.addPage(jpeg, pixelWidth: 20, pixelHeight: 30, pageWidth: 595.276, pageHeight: 841.89);
    await writer.addPage(jpeg, pixelWidth: 20, pixelHeight: 30, pageWidth: 842, pageHeight: 595);
    expect(writer.pageCount, 2);
    await writer.close();

    final bytes = File(path).readAsBytesSync();
    final text = latin1.decode(bytes);

    expect(text, startsWith('%PDF-1.4'));
    expect(text, contains('/Count 2'));
    expect(text, contains('/MediaBox [0 0 595.276 841.89]'));
    expect(text, contains('/MediaBox [0 0 842 595]'));
    expect('/Filter /DCTDecode'.allMatches(text).length, 2);
    expect(text.trimRight(), endsWith('%%EOF'));

    // startxref zeigt auf die Querverweistabelle ...
    final startXref = int.parse(RegExp(r'startxref\n(\d+)').firstMatch(text)!.group(1)!);
    expect(text.substring(startXref, startXref + 4), 'xref');

    // ... und jeder Eintrag dort auf den Anfang des richtigen Objekts.
    final entries = RegExp(r'(\d{10}) 00000 n ').allMatches(text.substring(startXref)).toList();
    expect(entries.length, 8); // Katalog, Seitenbaum, 2 × (Bild, Inhalt, Seite)
    for (var i = 0; i < entries.length; i++) {
      final offset = int.parse(entries[i].group(1)!);
      expect(text.substring(offset), startsWith('${i + 1} 0 obj'));
    }
  });

  test('a PDF without pages is still well-formed', () async {
    final path = '${dir.path}/empty.pdf';
    final writer = await JpegPdfWriter.open(path);
    await writer.close();

    final text = latin1.decode(File(path).readAsBytesSync());
    expect(text, contains('/Count 0'));
    expect(text.trimRight(), endsWith('%%EOF'));
  });
}
