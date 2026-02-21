import 'package:universal_io/io.dart';
// import 'package:cunning_document_scanner/cunning_document_scanner.dart'; // Mobile Only (See Conditional Import below)
// Since we can't do conditional imports easily without separate files,
// we will just wrap the usage and suppress checks or use `invokeMethod` if possible,
// OR simpler: Use conditional compilation if possible.
// Actually, CunningDocumentScanner plugin usually compiles on web but throws at runtime?
// The user request says "It will crash on Web. You must hide it..."
// To strictly avoid compile errors if the package doesn't support web at all, we might need conditional imports.
// But for now, let's try wrapping with kIsWeb.
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

import 'package:flutter/foundation.dart';

class ScannerService {
  /// Opens the native Camera UI with Edge Detection
  Future<List<String>?> scanDocument() async {
    try {
      if (kIsWeb) {
        debugPrint("Scanner not supported on Web");
        return null;
      }
      List<String>? images = await CunningDocumentScanner.getPictures();
      return images;
    } catch (e) {
      debugPrint("Scanner Error: $e");
      return null;
    }
  }

  /// Converts the scanned images into a single PDF file
  Future<File> generatePdf(List<String> imagePaths) async {
    final pdf = pw.Document();

    for (var path in imagePaths) {
      final image = pw.MemoryImage(File(path).readAsBytesSync());

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(image));
          },
        ),
      );
    }

    final output = await getTemporaryDirectory();
    final file = File(
      "${output.path}/scanned_doc_${DateTime.now().millisecondsSinceEpoch}.pdf",
    );
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
