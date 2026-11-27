import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pdf_tool/main.dart';

void main() {
  Future<void> pumpWithLocale(WidgetTester tester, Locale locale) async {
    tester.platformDispatcher.localesTestValue = [locale];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const PdfCompressorApp());
    await tester.pumpAndSettle();
  }

  testWidgets('Startseite auf Deutsch', (tester) async {
    await pumpWithLocale(tester, const Locale('de', 'DE'));

    expect(find.text('PDF-Compressor'), findsOneWidget);
    expect(find.text('Einfach und offline PDF-Dateien verkleinern'), findsOneWidget);
    expect(find.text('PDF auswählen'), findsOneWidget);
  });

  testWidgets('start page in English', (tester) async {
    await pumpWithLocale(tester, const Locale('en', 'US'));

    expect(find.text('PDF Compressor'), findsOneWidget);
    expect(find.text('Choose PDF'), findsOneWidget);
  });

  testWidgets('unsupported language falls back to English', (tester) async {
    await pumpWithLocale(tester, const Locale('fr', 'FR'));

    expect(find.text('PDF Compressor'), findsOneWidget);
  });

  testWidgets('no overflow in landscape with large text', (tester) async {
    tester.view.physicalSize = const Size(2220, 1080);
    tester.view.devicePixelRatio = 2.75;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpWithLocale(tester, const Locale('de', 'DE'));

    expect(tester.takeException(), isNull);
    expect(find.text('PDF auswählen'), findsOneWidget);
  });
}
