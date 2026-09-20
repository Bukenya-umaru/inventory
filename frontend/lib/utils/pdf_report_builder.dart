import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PdfReportBuilder {
  static final _dateFmt = DateFormat('MMM d, yyyy');
  static final _dateTimeFmt = DateFormat('MMM d, yyyy HH:mm');

  static const _muted = PdfColor.fromInt(0xFF666666);
  static const _line = PdfColor.fromInt(0xFFBBBBBB);

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
    final sales = (r['sales'] as List?) ?? [];
    final damages = (r['damages'] as List?) ?? [];
    final allProducts = (r['allProducts'] as Map?) ?? {};
    final productBreakdown = (r['productBreakdown'] as Map?) ?? {};
    final damageBreakdown = (r['damageBreakdown'] as Map?) ?? {};

    final sortedProductKeys = allProducts.keys.toList()..sort((a, b) {
      final pa = allProducts[a] as Map;
      final pb = allProducts[b] as Map;
      final aActive = (pa['quantitySold'] ?? 0) > 0 || (pa['quantityDamaged'] ?? 0) > 0;
      final bActive = (pb['quantitySold'] ?? 0) > 0 || (pb['quantityDamaged'] ?? 0) > 0;
      if (aActive && !bActive) return -1;
      if (!aActive && bActive) return 1;
      return a.compareTo(b);
    });

    final sortedSales = List.of(sales)..sort((a, b) {
      final da = a['saleDate'] != null ? DateTime.parse(a['saleDate']) : DateTime(0);
      final db = b['saleDate'] != null ? DateTime.parse(b['saleDate']) : DateTime(0);
      return db.compareTo(da);
    });
    final sortedDamages = List.of(damages)..sort((a, b) {
      final da = a['reportDate'] != null ? DateTime.parse(a['reportDate']) : DateTime(0);
      final db = b['reportDate'] != null ? DateTime.parse(b['reportDate']) : DateTime(0);
      return db.compareTo(da);
    });

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: _muted)),
      ),
      build: (ctx) => [

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoImage != null) ...[
              pw.SizedBox(
                height: 48,
                width: 48,
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 12),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (businessName.isNotEmpty)
                    pw.Text(businessName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Sales & Inventory Report', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Period: $dateRangeLabel', style: const pw.TextStyle(fontSize: 10, color: _muted)),
                  pw.Text('Generated: ${_dateTimeFmt.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: _muted)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),

        _sectionTitle('Summary'),
        pw.SizedBox(height: 4),
        _kvRow('Total Revenue', _fmt((r['totalRevenue'] ?? 0).toDouble())),
        _kvRow('Total Profit', _fmt((r['totalProfit'] ?? 0).toDouble())),
        _kvRow('Damage Loss', '-${_fmt((r['totalDamageLoss'] ?? 0).toDouble())}'),
        _kvRow('Net Profit', _fmt((r['netProfit'] ?? 0).toDouble())),
        _kvRow('Sales Transactions', '${r['totalSales'] ?? 0}'),
        _kvRow('Damage Reports', '${r['totalDamageReports'] ?? 0}'),
        pw.SizedBox(height: 16),

        if (inventory != null) ...[
          _sectionTitle('Inventory Overview'),
          pw.SizedBox(height: 4),
          _kvRow('Stock', '${inventory['totalProducts'] ?? 0}'),
          _kvRow('Stock Value', _fmt((inventory['totalStockValue'] ?? 0).toDouble())),
          _kvRow('Low Stock Items', '${inventory['lowStockCount'] ?? 0}'),
          pw.SizedBox(height: 16),
        ],

        if (productBreakdown.isNotEmpty) ...[
          _sectionTitle('Sales by Product'),
          pw.SizedBox(height: 4),
          _table(
            headers: ['Product', 'Qty Sold', 'Revenue', 'Profit'],
            alignRight: const {1, 2, 3},
            rows: _sortedEntries(productBreakdown, 'profit').map((e) {
              final d = e.value as Map;
              return <String>[e.key, '${d['quantity'] ?? 0}', _fmt((d['revenue'] ?? 0).toDouble()), _fmt((d['profit'] ?? 0).toDouble())];
            }).toList(),
          ),
          pw.SizedBox(height: 16),
        ],

        if (damageBreakdown.isNotEmpty) ...[
          _sectionTitle('Damages by Product'),
          pw.SizedBox(height: 4),
          _table(
            headers: ['Product', 'Qty Damaged', 'Loss'],
            alignRight: const {1, 2},
            rows: _sortedEntries(damageBreakdown, 'loss').map((e) {
              final d = e.value as Map;
              return <String>[e.key, '${d['quantity'] ?? 0}', '-${_fmt((d['loss'] ?? 0).toDouble())}'];
            }).toList(),
          ),
          pw.SizedBox(height: 16),
        ],

        if (sortedProductKeys.isNotEmpty) ...[
          _sectionTitle('Product Details (${sortedProductKeys.length})'),
          pw.SizedBox(height: 4),
          _table(
            headers: ['Product', 'Cost', 'Sell', 'Stock', 'Min', 'Sold', 'Dmg', 'Revenue', 'Profit', 'Loss', 'Margin'],
            alignRight: const {1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
            rows: sortedProductKeys.map((name) {
              final p = allProducts[name] as Map;
              final revenue = (p['revenue'] ?? 0).toDouble();
              final profit = (p['profit'] ?? 0).toDouble();
              final margin = revenue > 0 ? (profit / revenue * 100) : 0.0;
              return <String>[
                name,
                _fmtFull((p['costPrice'] ?? 0).toDouble()),
                _fmtFull((p['sellingPrice'] ?? 0).toDouble()),
                '${p['totalStockPieces'] ?? 0}',
                '${p['minimumStock'] ?? 0}',
                '${p['quantitySold'] ?? 0}',
                '${p['quantityDamaged'] ?? 0}',
                _fmt(revenue),
                _fmt(profit),
                _fmt((p['loss'] ?? 0).toDouble()),
                '${margin.toStringAsFixed(1)}%',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 16),
        ],

        if (sortedSales.isNotEmpty) ...[
          _sectionTitle('Sales Transactions (${sortedSales.length})'),
          pw.SizedBox(height: 4),
          _table(
            headers: ['Date', 'Product', 'Qty', 'Unit', 'Price', 'Total', 'Profit', 'Customer'],
            alignRight: const {2, 4, 5, 6},
            rows: sortedSales.map((s) {
              return <String>[
                s['saleDate'] != null ? _dateFmt.format(DateTime.parse(s['saleDate'])) : '',
                s['productName'] ?? 'Unknown',
                '${s['quantity'] ?? 0}',
                s['saleUnit'] == 'box' ? 'Box' : 'Pc',
                _fmtFull((s['unitPrice'] ?? 0).toDouble()),
                _fmt((s['totalAmount'] ?? 0).toDouble()),
                _fmt((s['profit'] ?? 0).toDouble()),
                s['customerName'] ?? '-',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 16),
        ],

        if (sortedDamages.isNotEmpty) ...[
          _sectionTitle('Damage Reports (${sortedDamages.length})'),
          pw.SizedBox(height: 4),
          _table(
            headers: ['Date', 'Product', 'Qty', 'Unit', 'Reason', 'Loss', 'Reported By'],
            alignRight: const {2, 5},
            rows: sortedDamages.map((d) {
              return <String>[
                d['reportDate'] != null ? _dateFmt.format(DateTime.parse(d['reportDate'])) : '',
                d['productName'] ?? 'Unknown',
                '${d['quantity'] ?? 0}',
                d['damageUnit'] == 'box' ? 'Box' : 'Pc',
                '${d['reason'] ?? '-'}',
                '-${_fmt((d['estimatedLoss'] ?? 0).toDouble())}',
                d['reportedBy'] ?? '-',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 16),
        ],
      ],
    ));

    return pdf.save();
  }

  static List<MapEntry> _sortedEntries(Map map, String sortKey) {
    return map.entries.toList()..sort((a, b) => (b.value[sortKey] ?? 0).compareTo(a.value[sortKey] ?? 0));
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold));
  }

  static pw.Widget _kvRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
    Set<int> alignRight = const {},
  }) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellHeight: 18,
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      border: pw.TableBorder.all(color: _line, width: 0.5),
      headerAlignments: {
        for (var i = 0; i < headers.length; i++)
          i: alignRight.contains(i) ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      },
      cellAlignments: {
        for (var i = 0; i < headers.length; i++)
          i: alignRight.contains(i) ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      },
    );
  }

  static String _fmt(double v) {
    final nf = NumberFormat('#,##0.##', 'en_US');
    return nf.format(v);
  }

  static String _fmtFull(double v) {
    final nf = NumberFormat('#,##0.00', 'en_US');
    return nf.format(v);
  }
}