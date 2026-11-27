import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'jpeg_pdf_writer.dart';
import 'l10n/app_localizations.dart';

/// Obergrenze für die längste Seite eines gerenderten Seitenbilds in Pixeln.
/// Schützt vor Speichermangel bei übergroßen Seiten (z. B. Pläne, Poster).
const int _maxRenderPixels = 3000;

/// Kanal zur nativen Android-Seite: kopiert eine Datei per Datenstrom in den
/// vom Nutzer gewählten Speicherort, ohne sie ganz in den Speicher zu laden.
const MethodChannel _saveChannel = MethodChannel(
  'net.grafm.pdfcompressor/save',
);

/// Eine Seite konnte nicht gerendert werden ([page] beginnt bei 1).
class _PageRenderException implements Exception {
  const _PageRenderException(this.page);
  final int page;
}

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
Future<Uint8List> _encodeJpgInBackground(
  Uint8List bgra,
  int width,
  int height,
  int quality,
) {
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
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      // Sprache folgt dem Gerät; nicht unterstützte Sprachen fallen auf Englisch zurück.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, supported) {
        for (final s in supported) {
          if (s.languageCode == locale?.languageCode) return s;
        }
        return const Locale('en');
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A56C4),
          brightness: Brightness.light,
          // Kräftiges Blau wie im App-Symbol statt abgeschwächter Töne
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
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

  // Übersetzte Texte für die aktuelle Gerätesprache
  AppLocalizations get _l => AppLocalizations.of(context);

  // Dateiname der Ausgabe, z. B. "Rechnung_komprimiert.pdf" / "Rechnung_compressed.pdf"
  String _outputFileName() {
    final String originalName = _selectedFile!.name.replaceAll(
      RegExp(r'\.pdf$', caseSensitive: false),
      '',
    );
    return '${originalName}_${_l.compressedFileSuffix}.pdf';
  }

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
              Text(_l.aboutTitle),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                Icons.person_outline_rounded,
                _l.aboutAuthor,
                'Michael Graf',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.flutter_dash_rounded,
                _l.aboutTechnology,
                _l.aboutTechnologyValue,
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.gavel_rounded,
                _l.aboutLicense,
                _l.aboutLicenseValue,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_l.close),
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
          content: Text(_l.errorOpenFile('$e')),
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
    JpegPdfWriter? writer;
    String? partPath;
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

      final Directory tempDir = await getTemporaryDirectory();
      if (!mounted) return;
      final String outputPath = '${tempDir.path}/${_outputFileName()}';

      // Jede Seite wird sofort in eine Zwischendatei geschrieben, damit der
      // Speicherbedarf nicht mit der Seitenzahl wächst.
      partPath = '$outputPath.part';
      writer = await JpegPdfWriter.open(partPath);

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
        // Lieber abbrechen als eine PDF mit fehlenden Seiten ausgeben
        if (rendered == null) throw _PageRenderException(page.pageNumber);

        final int w = rendered.width;
        final int h = rendered.height;
        final Uint8List jpgBytes;
        try {
          jpgBytes = await _encodeJpgInBackground(
            rendered.pixels,
            w,
            h,
            jpegQuality,
          );
        } finally {
          rendered.dispose();
        }

        await writer.addPage(
          jpgBytes,
          pixelWidth: w,
          pixelHeight: h,
          pageWidth: page.width,
          pageHeight: page.height,
        );
      }

      final JpegPdfWriter finishedWriter = writer;
      writer = null;
      await finishedWriter.close();

      // Ist das Ergebnis nicht kleiner als das Original (z. B. bei reinen
      // Text-PDFs, die durch die Umwandlung in Bilder wachsen), wird das
      // Original unverändert übernommen. So entsteht nie eine größere Datei.
      final File partFile = File(partPath);
      final File inputFile = File(_selectedFile!.path!);
      final int originalSize = await inputFile.length();
      final int outputSize = await partFile.length();
      final bool keepOriginal = outputSize >= originalSize;
      final File outFile;
      if (keepOriginal) {
        await partFile.delete();
        outFile = await inputFile.copy(outputPath);
      } else {
        outFile = await partFile.rename(outputPath);
      }
      partPath = null;

      if (!mounted) return;
      setState(() {
        _compressedFile = outFile;
        _compressedFileSize = keepOriginal ? originalSize : outputSize;
        _keptOriginal = keepOriginal;
        _isCompressing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCompressing = false;
      });
      final String message = e is _PageRenderException
          ? _l.errorRenderPage(e.page)
          : _l.errorCompress('$e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      await writer?.abort();
      // Unfertige Zwischendatei nach Abbruch oder Fehler entfernen
      if (partPath != null) {
        try {
          await File(partPath).delete();
        } catch (_) {}
      }
      await inputDoc?.dispose();
    }
  }

  // 3a. Fertige PDF direkt im Wunschordner (z. B. Downloads) speichern
  Future<void> _saveCompressedPdfToDevice() async {
    if (_compressedFile == null || _selectedFile == null) return;

    try {
      final String suggestedName = _outputFileName();
      final bool saved;

      if (Platform.isAndroid) {
        // Android: "Speichern unter"-Dialog des Systems; die Datei wird nativ
        // per Datenstrom kopiert. Wichtig, wenn das Original übernommen wurde
        // und mehrere hundert MB groß ist.
        saved =
            await _saveChannel.invokeMethod<bool>('saveFile', {
              'path': _compressedFile!.path,
              'name': suggestedName,
            }) ??
            false;
      } else {
        final Uri? savedUri = await FilePicker.saveFile(
          dialogTitle: _l.saveDialogTitle,
          fileName: suggestedName,
          bytes: await _compressedFile!.readAsBytes(),
        );
        saved = savedUri != null;
      }

      if (saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l.savedSuccess),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l.errorSave('$e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 3b. Fertige PDF über andere Apps teilen (WhatsApp, Mail etc.)
  Future<void> _shareCompressedPdf() async {
    if (_compressedFile == null) return;
    await Share.shareXFiles([XFile(_compressedFile!.path)], text: _l.shareText);
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _getCompressionLabel() {
    if (_compressionLevel == 0) return _l.levelLight;
    if (_compressionLevel == 1) return _l.levelRecommended;
    return _l.levelStrong;
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
        // Dunkle Statusleisten-Symbole auf hellem Hintergrund
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: colorScheme.surface,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: _l.infoTooltip,
            onPressed: () => _showInfoDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        // Scrollbar, falls der Platz nicht reicht (Querformat, große Schrift).
        // Sonst füllt die Spalte den Bildschirm und die Spacer verteilen den Raum.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),

                      // Kopfbereich: Icon + Titel. Das große Icon ist reine Deko und
                      // wird ausgeblendet, sobald eine Datei gewählt ist, damit
                      // Dateikarte und Button auch auf kleineren Displays passen.
                      if (_selectedFile == null) ...[
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
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        _l.appTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _l.appSubtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFeatureChip(
                            context,
                            Icons.wifi_off_rounded,
                            _l.featureOffline,
                          ),
                          const SizedBox(width: 12),
                          _buildFeatureChip(
                            context,
                            Icons.shield_outlined,
                            _l.featurePrivacy,
                          ),
                        ],
                      ),

                      // Hinweis: Seiten werden zu Bildern, Text geht als Text verloren.
                      // Nach dem Verkleinern ausgeblendet, um Platz für das Ergebnis zu lassen.
                      if (_compressedFile == null) ...[
                        const SizedBox(height: 20),
                        _buildTextLossHint(context),
                      ],

                      const Spacer(),
                      // Mindestabstand, falls der Spacer auf null schrumpft
                      const SizedBox(height: 16),

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
                                  Icon(
                                    Icons.description_rounded,
                                    color: colorScheme.primary,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedFile!.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          _l.originalSize(
                                            _formatFileSize(
                                              _selectedFileSize ?? 0,
                                            ),
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!_isCompressing)
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded),
                                      tooltip: _l.chooseOtherFile,
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
                              if (_compressedFile == null &&
                                  !_isCompressing) ...[
                                const Divider(height: 24),
                                Text(
                                  _l.compressionStrength(
                                    _getCompressionLabel(),
                                  ),
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(_l.processingPage(_processedPages)),
                                  ],
                                ),
                              ],

                              // Ergebnis-Anzeige nach erfolgreicher Komprimierung
                              if (_compressedFile != null &&
                                  _compressedFileSize != null) ...[
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _l.newSize,
                                          style: const TextStyle(fontSize: 12),
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
                                    if (_selectedFileSize != null &&
                                        _selectedFileSize! > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          !_keptOriginal &&
                                                  _compressedFileSize! <
                                                      _selectedFileSize!
                                              ? '-${((1 - (_compressedFileSize! / _selectedFileSize!)) * 100).toStringAsFixed(0)}%'
                                              : _l.alreadyOptimal,
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
                                    _l.keptOriginalHint,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
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
                              : (_selectedFile == null
                                    ? _pickPdfFile
                                    : _compressPdf),
                          icon: Icon(
                            _selectedFile == null
                                ? Icons.upload_file_rounded
                                : Icons.compress_rounded,
                          ),
                          label: Text(
                            _selectedFile == null ? _l.pickPdf : _l.compressNow,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
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
                                    label: Text(
                                      _l.save,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
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
                                    label: Text(
                                      _l.share,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
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
                              child: Text(_l.compressAnother),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextLossHint(BuildContext context) {
    // Helles Bernstein mit dunkler Schrift: auffällig, aber gut lesbar
    const Color background = Color(0xFFFFF3DC);
    const Color border = Color(0xFFF2C46D);
    const Color foreground = Color(0xFF4A3000);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 22, color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${_l.textLossHintTitle} ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: _l.textLossHintBody),
                ],
              ),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: foreground),
            ),
          ),
        ],
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
