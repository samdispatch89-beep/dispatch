import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import '../services/error_dialog_service.dart';
import '../services/storage_service.dart';

class PdfScanner extends StatefulWidget {
  final String loadId;
  const PdfScanner({super.key, required this.loadId});

  @override
  State<PdfScanner> createState() => _PdfScannerState();
}

class _PdfScannerState extends State<PdfScanner> {
  final StorageService storage = StorageService();
  final List<PlatformFile> _pages = [];

  Future<void> _pickPages() async {
  final result = await FilePicker.pickFiles(allowMultiple: true, withData: true, type: FileType.image);
    if (result == null) return;
    setState(() => _pages.addAll(result.files));
  }

  Future<void> _savePdf() async {
    try {
      final pdf = pw.Document();
      for (final pf in _pages) {
        final pageBytes = pf.bytes;
        if (pageBytes == null) {
          throw StateError('One of the selected images could not be read.');
        }
        final image = pw.MemoryImage(pageBytes);
        pdf.addPage(pw.Page(build: (c) => pw.Center(child: pw.Image(image))));
      }
      final bytes = await pdf.save();
      final filename = 'scan_${widget.loadId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final upload = await storage.uploadBytes(
        bytes,
        'scans/${widget.loadId}/$filename',
        fileName: filename,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploaded: ${upload.downloadUrl}')),
        );
      }
    } catch (error) {
      if (mounted) {
        await ErrorDialogService.show(
          context,
          message: 'Upload failed: $error',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan to PDF')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ElevatedButton(onPressed: _pickPages, child: const Text('Pick images')),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: _pages.isEmpty ? null : _savePdf, child: const Text('Save & Upload PDF')),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _pages.length,
            itemBuilder: (context, i) => ListTile(title: Text(_pages[i].name)),
          ),
        )
      ]),
    );
  }
}
