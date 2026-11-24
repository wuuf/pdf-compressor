import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Obergrenze für die längste Seite eines gerenderten Seitenbilds in Pixeln.
/// Schützt vor Speichermangel bei übergroßen Seiten (z. B. Pläne, Poster).
const int _maxRenderPixels = 3000;

/// Kodiert BGRA-Rohpixel als JPEG. Läuft in einem Hintergrund-Isolate,
/// damit die Oberfläche flüssig bleibt.
Uint8List _encodeBgraToJpg(Uint8List bgra, int width, int height, int quality) {
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: bgra.buffer,
    bytesOffset: bgra.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.bgra,
  );
  return img.encodeJpg(image, quality: quality);
}

/// Startet [_encodeBgraToJpg] in einem eigenen Isolate. Muss top-level sein,
/// damit die Closure keinen Widget-Zustand mitschleppt (der ist nicht sendbar).
Future<Uint8List> _encodeJpgInBackground(Uint8List bgra, int width, int height, int quality) {
  return Isolate.run(() => _encodeBgraToJpg(bgra, width, height, quality));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrx.pdfrxFlutterInitialize();
  runApp(const PdfCompressorApp());
}

class PdfCompressorApp extends StatelessWidget {
  const PdfCompressorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF-Compressor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.redAccent,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const LandingPage(),
    );
  }
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  PlatformFile? _selectedFile;
  int? _selectedFileSize;

  // Kompressionsstufe: 0 = Leicht (hohe Qualität), 1 = Mittel (Empfohlen), 2 = Stark (kleinste Datei)
  double _compressionLevel = 1;

  bool _isCompressing = false;
  int _processedPages = 0;

  File? _compressedFile;
  int? _compressedFileSize;

  // true, wenn die Komprimierung nichts gebracht hat und das Original übernommen wurde
  bool _keptOriginal = false;

  // Info-Dialog einblenden
  void _showInfoDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: colorScheme.primary),
              const SizedBox(width: 10),
              const Text('Über die App'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(Icons.person_outline_rounded, 'Autor', 'Michael Graf'),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.flutter_dash_rounded, 'Technologie', 'Programmiert in Flutter'),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.gavel_rounded, 'Lizenz', 'Code unter Apache License 2.0'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Schließen'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 1. PDF-Datei auswählen
  Future<void> _pickPdfFile() async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (file != null) {
        final int? length = await file.length();
        setState(() {
          _selectedFile = file;
          _selectedFileSize = length;
          _compressedFile = null;
          _compressedFileSize = null;
          _keptOriginal = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Öffnen der Datei: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 2. PDF offline verkleinern
  Future<void> _compressPdf() async {
    if (_selectedFile?.path == null) return;

    setState(() {
      _isCompressing = true;
      _processedPages = 0;
      _compressedFile = null;
      _compressedFileSize = null;
      _keptOriginal = false;
    });

    pdfrx.PdfDocument? inputDoc;
    try {
      // PDF direkt von der Datei öffnen, statt sie komplett in den Speicher
      // zu laden. Große PDFs (z. B. Scans) haben sonst den Speicher gesprengt
      // und die App wurde von Android beendet.
      inputDoc = await pdfrx.PdfDocument.openFile(_selectedFile!.path!);

      late final double dpi;
      late final int jpegQuality;

      if (_compressionLevel == 0) {
        dpi = 150.0;
        jpegQuality = 75;
      } else if (_compressionLevel == 1) {
        dpi = 110.0;
        jpegQuality = 55;
      } else {
        dpi = 72.0;
        jpegQuality = 35;
      }

      final pw.Document outputPdf = pw.Document();

      for (final pdfrx.PdfPage page in inputDoc.pages) {
        if (!mounted) return;
        setState(() {
          _processedPages++;
        });

        // Seitengröße in Punkten (1/72 Zoll) -> Pixel bei gewählter DPI,
        // begrenzt auf _maxRenderPixels für die längere Seite.
        double scale = dpi / 72.0;
        final double longest = math.max(page.width, page.height) * scale;
        if (longest > _maxRenderPixels) {
          scale *= _maxRenderPixels / longest;
        }
        final int pxWidth = math.max(1, (page.width * scale).round());
        final int pxHeight = math.max(1, (page.height * scale).round());

        final pdfrx.PdfImage? rendered = await page.render(
          fullWidth: pxWidth.toDouble(),
          fullHeight: pxHeight.toDouble(),
          backgroundColor: 0xFFFFFFFF,
        );
        if (rendered == null) continue;

        final Uint8List pixels = rendered.pixels;
        final int w = rendered.width;
        final int h = rendered.height;
        final Uint8List jpgBytes;
        try {
          jpgBytes = await _encodeJpgInBackground(pixels, w, h, jpegQuality);
        } finally {
          rendered.dispose();
        }

        final pw.MemoryImage pdfImage = pw.MemoryImage(jpgBytes);
        outputPdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height),
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
              );
            },
          ),
        );
      }

      final Directory tempDir = await getTemporaryDirectory();
      final String originalName = _selectedFile!.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      final String outputPath = '${tempDir.path}/${originalName}_komprimiert.pdf';

      final File outFile = File(outputPath);
      final Uint8List outputBytes = await outputPdf.save();

      // Ist das Ergebnis nicht kleiner als das Original (z. B. bei reinen
      // Text-PDFs, die durch die Umwandlung in Bilder wachsen), wird das
      // Original unverändert übernommen. So entsteht nie eine größere Datei.
      final File inputFile = File(_selectedFile!.path!);
      final int originalSize = await inputFile.length();
      final bool keepOriginal = outputBytes.length >= originalSize;
      if (keepOriginal) {
        await inputFile.copy(outputPath);
      } else {
        await outFile.writeAsBytes(outputBytes);
      }

      if (!mounted) return;
      setState(() {
        _compressedFile = outFile;
        _compressedFileSize = keepOriginal ? originalSize : outputBytes.length;
        _keptOriginal = keepOriginal;
        _isCompressing = false;
      });
    } catch (e) {
      setState(() {
        _isCompressing = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler bei der Komprimierung: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      await inputDoc?.dispose();
    }
  }
// 3a. Fertige PDF direkt im Wunschordner (z. B. Downloads) speichern
Future<void> _saveCompressedPdfToDevice() async {
    if (_compressedFile == null || _selectedFile == null) return;

    try {
      final String originalName = _selectedFile!.name.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
      final String suggestedName = '${originalName}_komprimiert.pdf';

      // Bytes der fertig komprimierten Datei lesen
      final Uint8List bytes = await _compressedFile!.readAsBytes();

      // Öffnet den Android-"Speichern unter"-Dialog (gibt in v13 ein Uri? zurück)
      final Uri? savedUri = await FilePicker.saveFile(
        dialogTitle: 'Komprimierte PDF speichern',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );

      if (savedUri != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF erfolgreich auf dem Gerät gespeichert!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Speichern: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
}
  // 3b. Fertige PDF über andere Apps teilen (WhatsApp, Mail etc.)
Future<void> _shareCompressedPdf() async {
    if (_compressedFile == null) return;
    await Share.shareXFiles(
      [XFile(_compressedFile!.path)],
      text: 'Komprimiert mit PDF-Compressor',
    );
  }
  

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _getCompressionLabel() {
    if (_compressionLevel == 0) return 'Leicht (Hohe Qualität, 150 DPI)';
    if (_compressionLevel == 1) return 'Empfohlen (Gute Balance, 110 DPI)';
    return 'Stark (Kleinste Datei, 72 DPI)';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      // Transparente AppBar oben für den Info-Button
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Info',
            onPressed: () => _showInfoDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Kopfbereich: Icon + Titel
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 72,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'PDF-Compressor',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Einfach und offline PDF-Dateien verkleinern',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFeatureChip(context, Icons.wifi_off_rounded, '100% Offline'),
                  const SizedBox(width: 12),
                  _buildFeatureChip(context, Icons.shield_outlined, 'Datenschutz-sicher'),
                ],
              ),

              const Spacer(),

              // Wenn eine Datei ausgewählt wurde: Datei-Info & Einstellungen anzeigen
              if (_selectedFile != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.description_rounded, color: colorScheme.primary, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedFile!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Originalgröße: ${_formatFileSize(_selectedFileSize ?? 0)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (!_isCompressing)
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Andere Datei wählen',
                              onPressed: () {
                                setState(() {
                                  _selectedFile = null;
                                  _selectedFileSize = null;
                                  _compressedFile = null;
                                });
                              },
                            ),
                        ],
                      ),

                      // Regler für Kompressionsstärke
                      if (_compressedFile == null && !_isCompressing) ...[
                        const Divider(height: 24),
                        Text(
                          'Kompressionsstärke: ${_getCompressionLabel()}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Slider(
                          value: _compressionLevel,
                          min: 0,
                          max: 2,
                          divisions: 2,
                          label: _getCompressionLabel(),
                          onChanged: (value) {
                            setState(() {
                              _compressionLevel = value;
                            });
                          },
                        ),
                      ],

                      // Ladeanzeige während der Komprimierung
                      if (_isCompressing) ...[
                        const Divider(height: 24),
                        Row(
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                            const SizedBox(width: 16),
                            Text('Verarbeite Seite $_processedPages...'),
                          ],
                        ),
                      ],

                      // Ergebnis-Anzeige nach erfolgreicher Komprimierung
                      if (_compressedFile != null && _compressedFileSize != null) ...[
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Neue Größe:',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  _formatFileSize(_compressedFileSize!),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedFileSize != null && _selectedFileSize! > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  !_keptOriginal && _compressedFileSize! < _selectedFileSize!
                                      ? '-${((1 - (_compressedFileSize! / _selectedFileSize!)) * 100).toStringAsFixed(0)}%'
                                      : 'Bereits optimal',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (_keptOriginal) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Diese PDF lässt sich nicht weiter verkleinern. '
                            'Das Original wird unverändert übernommen.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Haupt-Button unten
              if (_compressedFile == null)
                FilledButton.icon(
                  onPressed: _isCompressing
                      ? null
                      : (_selectedFile == null ? _pickPdfFile : _compressPdf),
                  icon: Icon(
                    _selectedFile == null ? Icons.upload_file_rounded : Icons.compress_rounded,
                  ),
                  label: Text(
                    _selectedFile == null ? 'PDF auswählen' : 'Jetzt verkleinern',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                )
             else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        // Button 1: Direkt auf dem Gerät speichern (Downloads etc.)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saveCompressedPdfToDevice,
                            icon: const Icon(Icons.download_rounded),
                            label: const Text(
                              'Speichern',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Button 2: Teilen (WhatsApp, E-Mail etc.)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _shareCompressedPdf,
                            icon: const Icon(Icons.share_rounded),
                            label: const Text(
                              'Teilen',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _pickPdfFile,
                      child: const Text('Weiteres PDF verkleinern'),
                    ),
                  ],
                ), 
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip(BuildContext context, IconData icon, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}