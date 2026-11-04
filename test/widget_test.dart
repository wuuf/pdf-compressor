import 'package:flutter_test/flutter_test.dart';

import 'package:pdf_tool/main.dart';

void main() {
  testWidgets('landing page shows the PDF compressor UI', (tester) async {
    await tester.pumpWidget(const PdfCompressorApp());

    expect(find.text('PDF-Compressor'), findsOneWidget);
    expect(find.text('Einfach und offline PDF-Dateien verkleinern'), findsOneWidget);
    expect(find.text('PDF auswählen'), findsOneWidget);
  });
}
