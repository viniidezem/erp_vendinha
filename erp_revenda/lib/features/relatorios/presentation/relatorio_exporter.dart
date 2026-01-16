import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class RelatorioExportSection {
  final String title;
  final List<String> headers;
  final List<List<String>> rows;

  const RelatorioExportSection({
    required this.title,
    required this.headers,
    required this.rows,
  });
}

enum RelatorioExportTipo { csv, pdf }

enum RelatorioExportDestino { saveLocal, share }

class RelatorioExporter {
  static Future<void> export(
    BuildContext context, {
    required String title,
    required String fileBaseName,
    required List<RelatorioExportSection> sections,
  }) async {
    final tipo = await _pickTipo(context);
    if (tipo == null) return;
    if (!context.mounted) return;
    final destino = await _pickDestino(context);
    if (destino == null) return;
    if (!context.mounted) return;

    final stamp = _timestamp();
    final ext = tipo == RelatorioExportTipo.csv ? 'csv' : 'pdf';
    final fileName = '${fileBaseName}_$stamp.$ext';

    final bytes = tipo == RelatorioExportTipo.csv
        ? Uint8List.fromList(_buildCsv(title, sections))
        : await _buildPdf(title, sections);
    if (!context.mounted) return;

    if (destino == RelatorioExportDestino.saveLocal) {
      await _saveLocal(context, fileName, bytes);
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final path = p.join(tempDir.path, fileName);
    final file = await File(path).writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: title);
  }

  static String _timestamp() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return '$y$m${d}_$hh$mm$ss';
  }

  static Future<RelatorioExportTipo?> _pickTipo(BuildContext context) {
    return showModalBottomSheet<RelatorioExportTipo>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_view_outlined),
              title: const Text('Exportar CSV'),
              onTap: () => Navigator.of(ctx).pop(RelatorioExportTipo.csv),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Exportar PDF'),
              onTap: () => Navigator.of(ctx).pop(RelatorioExportTipo.pdf),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static Future<RelatorioExportDestino?> _pickDestino(BuildContext context) {
    return showModalBottomSheet<RelatorioExportDestino>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save_alt_outlined),
              title: const Text('Salvar localmente'),
              onTap: () => Navigator.of(ctx).pop(RelatorioExportDestino.saveLocal),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Compartilhar'),
              onTap: () => Navigator.of(ctx).pop(RelatorioExportDestino.share),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static Future<void> _saveLocal(
    BuildContext context,
    String fileName,
    Uint8List bytes,
  ) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar relatorio',
        fileName: fileName,
        bytes: bytes,
      );
      if (savedPath == null) return;
      return;
    }

    final targetPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Salvar relatorio',
      fileName: fileName,
    );
    if (targetPath == null) return;
    await File(targetPath).writeAsBytes(bytes, flush: true);
  }

  static List<int> _buildCsv(
    String title,
    List<RelatorioExportSection> sections,
  ) {
    final lines = <String>[];
    lines.add(title);
    lines.add('');

    for (final section in sections) {
      lines.add(section.title);
      lines.add(_csvLine(section.headers));
      for (final row in section.rows) {
        lines.add(_csvLine(row));
      }
      lines.add('');
    }

    return const Utf8Encoder().convert(lines.join('\n'));
  }

  static String _csvLine(List<String> values) {
    return values.map(_escapeCsv).join(',');
  }

  static String _escapeCsv(String value) {
    final needsQuote = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    final escaped = value.replaceAll('"', '""');
    return needsQuote ? '"$escaped"' : escaped;
  }

  static Future<Uint8List> _buildPdf(
    String title,
    List<RelatorioExportSection> sections,
  ) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          for (final section in sections) ...[
            pw.Text(
              section.title,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: section.headers,
              data: section.rows,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellHeight: 24,
            ),
            pw.SizedBox(height: 12),
          ],
        ],
      ),
    );

    return doc.save();
  }
}
