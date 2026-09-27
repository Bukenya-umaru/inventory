import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PdfReportBuilder {
  static final _dateTimeFmt = DateFormat('MMM d, yyyy HH:mm');

  static const _navy = PdfColor.fromInt(0xFF12304A);
  static const _blue = PdfColor.fromInt(0xFF2563EB);
  static const _green = PdfColor.fromInt(0xFF15803D);
  static const _orange = PdfColor.fromInt(0xFFB45309);
  static const _red = PdfColor.fromInt(0xFFB91C1C);
  static const _softBlue = PdfColor.fromInt(0xFFEFF6FF);
  static const _softGreen = PdfColor.fromInt(0xFFF0FDF4);
  static const _softOrange = PdfColor.fromInt(0xFFFFFBEB);
  static const _softRed = PdfColor.fromInt(0xFFFEF2F2);
  static const _muted = PdfColor.fromInt(0xFF666666);

  static Future<List<int>> build({
    required Map<String, dynamic> report,
    required String dateRangeLabel,
    String businessName = '',
    Map<String, dynamic>? inventory,
    Uint8List? logoBytes,
  }) async {
    final pdf = pw.Document();

    // MemoryImage cannot decode every uploaded format (e.g. SVG); fall back
    // to a text-only header instead of failing the whole export.
    pw.MemoryImage? logoImage;
    if (logoBytes != null) {
      try {
        logoImage = pw.MemoryImage(logoBytes);
      } catch (_) {
        logoImage = null;
      }
    }

    final r = report;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text('designed by Bukcode tech',
            style: const pw.TextStyle(fontSize: 8, color: _muted)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _muted)),
        ],
      ),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(18),
          decoration: const pw.BoxDecoration(
            color: _navy,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null) ...[
                pw.Container(
                  height: 52,
                  width: 52,
                  padding: const pw.EdgeInsets.all(5),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(7)),
                  ),
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 14),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (businessName.isNotEmpty)
                      pw.Text(
                        businessName,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Sales & Inventory Report',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 7),
                    pw.Text(
                      dateRangeLabel,
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                    ),
                    pw.Text(
                      'Generated ${_dateTimeFmt.format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 22),

        _sectionTitle('Summary'),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Expanded(child: _metricCard('Total Sales', _fmt((r['totalRevenue'] ?? 0).toDouble()), _blue, _softBlue)),
            pw.SizedBox(width: 10),
            pw.Expanded(child: _metricCard('Total Profit', _fmt((r['totalProfit'] ?? 0).toDouble()), _green, _softGreen)),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Expanded(child: _metricCard('Total Expenses', _fmt((r['totalExpenses'] ?? 0).toDouble()), _orange, _softOrange)),
            pw.SizedBox(width: 10),
            pw.Expanded(child: _metricCard('Damage Loss', _fmt((r['totalDamageLoss'] ?? 0).toDouble()), _red, _softRed)),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: const pw.BoxDecoration(
            color: _navy,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Net Profit', style: pw.TextStyle(fontSize: 11, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              pw.Text(_fmt((r['netProfit'] ?? 0).toDouble()), style: pw.TextStyle(fontSize: 13, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          children: [
            pw.Expanded(child: _kvRow('Sales Transactions', '${r['totalSales'] ?? 0}')),
            pw.SizedBox(width: 20),
            pw.Expanded(child: _kvRow('Damage Reports', '${r['totalDamageReports'] ?? 0}')),
          ],
        ),
        pw.SizedBox(height: 22),

        if (inventory != null) ...[
          _sectionTitle('Inventory Overview'),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF8FAFC),
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(7)),
            ),
            child: pw.Column(
              children: [
                _kvRow('Active Products', '${inventory['totalProducts'] ?? 0}'),
                _kvRow('Stock Value', _fmt((inventory['totalStockValue'] ?? 0).toDouble())),
                _kvRow('Low Stock Items', '${inventory['lowStockCount'] ?? 0}'),
              ],
            ),
          ),
        ],
      ],
    ));

    return pdf.save();
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Row(
      children: [
        pw.Container(width: 4, height: 14, color: _blue),
        pw.SizedBox(width: 7),
        pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _navy)),
      ],
    );
  }

  static pw.Widget _kvRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: _muted)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _navy)),
        ],
      ),
    );
  }

  static pw.Widget _metricCard(String label, String value, PdfColor color, PdfColor background) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: background,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
        border: pw.Border.all(color: color, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _muted)),
          pw.SizedBox(height: 5),
          pw.Text(value, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  static String _fmt(double v) {
    final nf = NumberFormat('#,##0.##', 'en_US');
    return nf.format(v);
  }

}