import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Schreibt ein PDF, das aus einem JPEG-Bild pro Seite besteht, direkt auf
/// die Festplatte. Jede Seite wird sofort geschrieben und danach vergessen,
/// der Speicherbedarf hängt also nicht von der Seitenzahl ab.
///
/// Aufbau pro Seite: Bild-Objekt (DCTDecode), Inhalts-Stream, Seiten-Objekt.
/// Am Ende folgen Seitenbaum, Katalog, Querverweistabelle und Trailer.
class JpegPdfWriter {
  JpegPdfWriter._(this._file);

  final RandomAccessFile _file;
  int _offset = 0;

  // Objekt 1 = Katalog, Objekt 2 = Seitenbaum; Seiten beginnen bei 3.
  final Map<int, int> _objectOffsets = {};
  final List<int> _pageObjects = [];
  int _nextObject = 3;

  static Future<JpegPdfWriter> open(String path) async {
    final file = await File(path).open(mode: FileMode.write);
    final writer = JpegPdfWriter._(file);
    // Kopfzeile plus Binärkommentar, damit Programme die Datei als binär erkennen
    await writer._writeBytes(
      Uint8List.fromList([
        ...latin1.encode('%PDF-1.4\n%'),
        0xE2,
        0xE3,
        0xCF,
        0xD3,
        0x0A,
      ]),
    );
    return writer;
  }

  int get pageCount => _pageObjects.length;

  /// Fügt eine Seite mit dem JPEG [jpeg] ([pixelWidth] × [pixelHeight] Pixel)
  /// hinzu, das die ganze Seite ([pageWidth] × [pageHeight] Punkt) ausfüllt.
  Future<void> addPage(
    Uint8List jpeg, {
    required int pixelWidth,
    required int pixelHeight,
    required double pageWidth,
    required double pageHeight,
  }) async {
    final int imageObj = _nextObject++;
    final int contentObj = _nextObject++;
    final int pageObj = _nextObject++;
    final String w = _num(pageWidth);
    final String h = _num(pageHeight);

    await _beginObject(imageObj);
    await _writeString(
      '<< /Type /XObject /Subtype /Image /Width $pixelWidth /Height $pixelHeight '
      '/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode '
      '/Length ${jpeg.length} >>\nstream\n',
    );
    await _writeBytes(jpeg);
    await _writeString('\nendstream\nendobj\n');

    final List<int> content = latin1.encode('q $w 0 0 $h 0 0 cm /Im0 Do Q');
    await _beginObject(contentObj);
    await _writeString('<< /Length ${content.length} >>\nstream\n');
    await _writeBytes(content);
    await _writeString('\nendstream\nendobj\n');

    await _beginObject(pageObj);
    await _writeString(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $w $h] '
      '/Resources << /XObject << /Im0 $imageObj 0 R >> >> '
      '/Contents $contentObj 0 R >>\nendobj\n',
    );
    _pageObjects.add(pageObj);
  }

  /// Schreibt Seitenbaum, Katalog und Querverweistabelle und schließt die Datei.
  Future<void> close() async {
    try {
      await _beginObject(2);
      final String kids = _pageObjects.map((o) => '$o 0 R').join(' ');
      await _writeString(
        '<< /Type /Pages /Kids [$kids] /Count ${_pageObjects.length} >>\nendobj\n',
      );
      await _beginObject(1);
      await _writeString('<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');

      final int xrefOffset = _offset;
      final int size = _nextObject;
      final StringBuffer xref = StringBuffer(
        'xref\n0 $size\n0000000000 65535 f \n',
      );
      for (int obj = 1; obj < size; obj++) {
        xref.write(
          '${_objectOffsets[obj]!.toString().padLeft(10, '0')} 00000 n \n',
        );
      }
      xref.write(
        'trailer\n<< /Size $size /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n',
      );
      await _writeString(xref.toString());
    } finally {
      await _file.close();
    }
  }

  /// Schließt die Datei ohne sie fertigzustellen, z. B. nach einem Fehler.
  Future<void> abort() => _file.close();

  Future<void> _beginObject(int number) async {
    _objectOffsets[number] = _offset;
    await _writeString('$number 0 obj\n');
  }

  Future<void> _writeString(String s) => _writeBytes(latin1.encode(s));

  Future<void> _writeBytes(List<int> bytes) async {
    await _file.writeFrom(bytes);
    _offset += bytes.length;
  }

  // Zahlen ohne Exponentialschreibweise und ohne überflüssige Nullen
  static String _num(double v) {
    final String s = v.toStringAsFixed(3);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
