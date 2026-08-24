import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class PdfReportBuilder {
  static final _dateFmt = DateFormat('MMM d, yyyy');
  static final _dateTimeFmt = DateFormat('MMM d, yyyy HH:mm');

  static const _primary = PdfColor.fromInt(0xFF1565C0);
  static const _success = PdfColor.fromInt(0xFF2E7D32);
  static const _danger = PdfColor.fromInt(0xFFC62828);
  static const _warning = PdfColor.fromInt(0xFFEF6C00);
  static const _lightGray = PdfColor.fromInt(0xFFF5F5F5);
  static const _darkText = PdfColor.fromInt(0xFF212121);
  static const _mutedText = PdfColor.fromInt(0xFF757575);
  static const _border = PdfColor.fromInt(0xFFE0E0E0);

  /// Build the full report PDF and return bytes.
  static Future<List<int>> build({
    required Map<String, dynamic> report,
    required String dateRangeLabel,
  }) async {
    final font = GoogleFonts.roboto();
    final fontBold = GoogleFonts.robotoBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
      ),
    );

    final r = report;
    final sales = (r['sales'] as List?) ?? [];
    final damages = (r['damages'] as List?) ?? [];
    final allProducts = (r['allProducts'] as Map?) ?? {};
    final productBreakdown = (r['productBreakdown'] as Map?) ?? {};
    final damageBreakdown = (r['damageBreakdown'] as Map?) ?? {};

    final totalRevenue = (r['totalRevenue'] ?? 0).toDouble();
    final totalProfit = (r['totalProfit'] ?? 0).toDouble();
    final totalDamageLoss = (r['totalDamageLoss'] ?? 0).toDouble();
    final netProfit = (r['netProfit'] ?? 0).toDouble();
    final totalSales = r['totalSales'] ?? 0;
    final totalDamageReports = r['totalDamageReports'] ?? 0;

    // Sort products: active first, then alphabetically
    final sortedProductKeys = allProducts.keys.toList()..sort((a, b) {
      final pa = allProducts[a] as Map;
      final pb = allProducts[b] as Map;
      final aActive = (pa['quantitySold'] ?? 0) > 0 || (pa['quantityDamaged'] ?? 0) > 0;
      final bActive = (pb['quantitySold'] ?? 0) > 0 || (pb['quantityDamaged'] ?? 0) > 0;
      if (aActive && !bActive) return -1;
      if (!aActive && bActive) return 1;
      return a.compareTo(b);
    });

    // ── Page 1: Cover + Summary ──
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => _header(dateRangeLabel),
      footer: (ctx) => _footer(ctx.pageNumber, ctx.pagesCount),
      build: (ctx) => [
        pw.SizedBox(height: 16),
        _summarySection(totalRevenue, totalProfit, totalDamageLoss, netProfit, totalSales, totalDamageReports),
        pw.SizedBox(height: 24),
        if (productBreakdown.isNotEmpty) ...[
          _sectionTitle('Sales by Product'),
          pw.SizedBox(height: 8),
          _productBreakdownTable(productBreakdown),
          pw.SizedBox(height: 24),
        ],
        if (damageBreakdown.isNotEmpty) ...[
          _sectionTitle('Damages by Product'),
          pw.SizedBox(height: 8),
          _damageBreakdownTable(damageBreakdown),
          pw.SizedBox(height: 24),
        ],
      ],
    ));

    // ── Page 2+: Product Details ──
    if (sortedProductKeys.isNotEmpty) {
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _header(dateRangeLabel),
        footer: (ctx) => _footer(ctx.pageNumber, ctx.pagesCount),
        build: (ctx) => [
          _sectionTitle('Product Details (${sortedProductKeys.length})'),
          pw.SizedBox(height: 8),
          ...sortedProductKeys.map((name) {
            final p = allProducts[name] as Map;
            return _productCard(name, p);
          }),
        ],
      ));
    }

    // ── Page 3+: Sales List ──
    if (sales.isNotEmpty) {
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _header(dateRangeLabel),
        footer: (ctx) => _footer(ctx.pageNumber, ctx.pagesCount),
        build: (ctx) => [
          _sectionTitle('Sales Transactions (${sales.length})'),
          pw.SizedBox(height: 8),
          _salesTable(sales),
        ],
      ));
    }

    // ── Page 4+: Damages List ──
    if (damages.isNotEmpty) {
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _header(dateRangeLabel),
        footer: (ctx) => _footer(ctx.pageNumber, ctx.pagesCount),
        build: (ctx) => [
          _sectionTitle('Damage Reports (${damages.length})'),
          pw.SizedBox(height: 8),
          _damagesTable(damages),
        ],
      ));
    }

    return pdf.save();
  }

  // ── Header ──
  static pw.Widget _header(String dateRange) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _primary, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('INVENTORY REPORT', style: pw.TextStyle(
                fontSize: 20, fontWeight: pw.FontWeight.bold, color: _primary)),
              pw.SizedBox(height: 4),
              pw.Text('Period: $dateRange', style: pw.TextStyle(
                fontSize: 11, color: _mutedText)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Generated', style: pw.TextStyle(fontSize: 9, color: _mutedText)),
              pw.Text(_dateTimeFmt.format(DateTime.now()), style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Footer ──
  static pw.Widget _footer(int page, int total) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 0.5)),
      ),
      child: pw.Text('Page $page of $total', style: pw.TextStyle(
        fontSize: 8, color: _mutedText)),
    );
  }

  // ── Section Title ──
  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _primary, width: 1.5)),
      ),
      child: pw.Text(title, style: pw.TextStyle(
        fontSize: 14, fontWeight: pw.FontWeight.bold, color: _primary)),
    );
  }

  // ── Summary Cards ──
  static pw.Widget _summarySection(
    double revenue, double profit, double loss, double net,
    int salesCount, int damageCount,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Summary', style: pw.TextStyle(
          fontSize: 16, fontWeight: pw.FontWeight.bold, color: _darkText)),
        pw.SizedBox(height: 12),
        pw.Row(
          children: [
            _summaryCard('Total Revenue', _fmt(revenue), _success),
            pw.SizedBox(width: 8),
            _summaryCard('Total Profit', _fmt(profit), _primary),
            pw.SizedBox(width: 8),
            _summaryCard('Damage Loss', '-${_fmt(loss)}', _danger),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            _summaryCard('Net Profit', _fmt(net), _success),
            pw.SizedBox(width: 8),
            _summaryCard('Total Sales', '$salesCount', _primary),
            pw.SizedBox(width: 8),
            _summaryCard('Damage Reports', '$damageCount', _warning),
          ],
        ),
      ],
    );
  }

  static pw.Widget _summaryCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _lightGray,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: _border, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _mutedText)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(
              fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // ── Product Breakdown Table ──
  static pw.Widget _productBreakdownTable(Map breakdown) {
    final entries = breakdown.entries.toList()
      ..sort((a, b) => (b.value['profit'] ?? 0).compareTo(a.value['profit'] ?? 0));

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: _primary),
      headerAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      cellHeight: 28,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _border, width: 0.5),
        top: pw.BorderSide(color: _border, width: 0.5),
        bottom: pw.BorderSide(color: _border, width: 0.5),
      ),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      headers: ['Product', 'Revenue', 'Profit', 'Qty'],
      data: entries.map((e) {
        final data = e.value as Map;
        return [
          e.key,
          _fmt((data['revenue'] ?? 0).toDouble()),
          _fmt((data['profit'] ?? 0).toDouble()),
          '${data['quantity'] ?? 0}',
        ];
      }).toList(),
    );
  }

  // ── Damage Breakdown Table ──
  static pw.Widget _damageBreakdownTable(Map breakdown) {
    final entries = breakdown.entries.toList()
      ..sort((a, b) => (b.value['loss'] ?? 0).compareTo(a.value['loss'] ?? 0));

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: _warning),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellHeight: 28,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
      },
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
      },
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _border, width: 0.5),
        top: pw.BorderSide(color: _border, width: 0.5),
        bottom: pw.BorderSide(color: _border, width: 0.5),
      ),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      headers: ['Product', 'Loss', 'Qty'],
      data: entries.map((e) {
        final data = e.value as Map;
        return [
          e.key,
          '-${_fmt((data['loss'] ?? 0).toDouble())}',
          '${data['quantity'] ?? 0}',
        ];
      }).toList(),
    );
  }

  // ── Product Detail Cards ──
  static pw.Widget _productCard(String name, Map p) {
    final qtySold = p['quantitySold'] ?? 0;
    final qtyDamaged = p['quantityDamaged'] ?? 0;
    final revenue = (p['revenue'] ?? 0).toDouble();
    final profit = (p['profit'] ?? 0).toDouble();
    final loss = (p['loss'] ?? 0).toDouble();
    final stock = p['currentStock'] ?? 0;
    final boxes = p['stockBoxes'] ?? 0;
    final totalStock = p['totalStockPieces'] ?? 0;
    final minStock = p['minimumStock'] ?? 0;
    final costPrice = (p['costPrice'] ?? 0).toDouble();
    final sellPrice = (p['sellingPrice'] ?? 0).toDouble();
    final costOfGoods = (p['costOfGoodsSold'] ?? 0).toDouble();
    final margin = revenue > 0 ? (profit / revenue * 100) : 0.0;
    final category = p['category'] ?? '';
    final unit = p['sellingUnit'] ?? 'piece';
    final upb = p['unitsPerBox'] ?? 1;
    final salesCount = p['salesCount'] ?? 0;
    final damageCount = p['damageCount'] ?? 0;

    final isLowStock = totalStock <= minStock && totalStock > 0;
    final statusColor = totalStock == 0 ? _danger : isLowStock ? _warning : _success;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Product header
          pw.Row(
            children: [
              pw.Container(
                width: 4, height: 24,
                decoration: pw.BoxDecoration(
                  color: statusColor,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(name, style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  if (category.isNotEmpty)
                    pw.Text(category, style: pw.TextStyle(
                      fontSize: 8, color: _mutedText)),
                ],
              )),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: _primary.withAlpha(25),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text('Stock: $totalStock', style: pw.TextStyle(
                  fontSize: 8, fontWeight: pw.FontWeight.bold, color: _primary)),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          // Quick stats
          pw.Row(
            children: [
              _miniStat('Stock', '$totalStock'),
              _miniStat('Sold', '$qtySold'),
              _miniStat('Damaged', '$qtyDamaged'),
              _miniStat('Revenue', _fmt(revenue)),
              _miniStat('Profit', _fmt(profit)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: _border, height: 1),
          pw.SizedBox(height: 6),
          // Detail grid
          pw.Row(
            children: [
              pw.Expanded(child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _detailRow('Cost Price', _fmtFull(costPrice)),
                  _detailRow('Selling Price', _fmtFull(sellPrice)),
                  if (unit == 'box') _detailRow('Unit Type', 'Box ($upb pcs/box)'),
                  _detailRow('Pieces in Stock', '$stock'),
                  _detailRow('Boxes in Stock', '$boxes'),
                  _detailRow('Minimum Stock', '$minStock'),
                ],
              )),
              pw.Expanded(child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _detailRow('Sales Revenue', _fmt(revenue)),
                  _detailRow('Cost of Goods', _fmt(costOfGoods)),
                  _detailRow('Sales Profit', _fmt(profit)),
                  _detailRow('Margin', '${margin.toStringAsFixed(1)}%'),
                  _detailRow('Damage Loss', '-${_fmt(loss)}'),
                  _detailRow('Transactions', '$salesCount sales, $damageCount damages'),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _miniStat(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.Text(label, style: pw.TextStyle(fontSize: 7, color: _mutedText)),
        ],
      ),
    );
  }

  static pw.Widget _detailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _mutedText)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Sales Table ──
  static pw.Widget _salesTable(List sales) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: _success),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellHeight: 26,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
      },
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
      },
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _border, width: 0.5),
        top: pw.BorderSide(color: _border, width: 0.5),
        bottom: pw.BorderSide(color: _border, width: 0.5),
      ),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      headers: ['Date', 'Product', 'Qty', 'Unit', 'Price', 'Total', 'Profit'],
      data: sales.map((s) {
        final date = s['saleDate'] != null
            ? _dateFmt.format(DateTime.parse(s['saleDate']))
            : '';
        return [
          date,
          '${s['productName'] ?? 'Unknown'}',
          '${s['quantity']}',
          '${s['saleUnit'] == 'box' ? 'Box' : 'Pc'}',
          _fmtFull((s['unitPrice'] ?? 0).toDouble()),
          _fmt((s['totalAmount'] ?? 0).toDouble()),
          _fmt((s['profit'] ?? 0).toDouble()),
        ];
      }).toList(),
    );
  }

  // ── Damages Table ──
  static pw.Widget _damagesTable(List damages) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: _danger),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellHeight: 26,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerLeft,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerLeft,
      },
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerLeft,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerLeft,
      },
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _border, width: 0.5),
        top: pw.BorderSide(color: _border, width: 0.5),
        bottom: pw.BorderSide(color: _border, width: 0.5),
      ),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      headers: ['Date', 'Product', 'Qty', 'Unit', 'Reason', 'Loss', 'Reported By'],
      data: damages.map((d) {
        final date = d['reportDate'] != null
            ? _dateFmt.format(DateTime.parse(d['reportDate']))
            : '';
        return [
          date,
          '${d['productName'] ?? 'Unknown'}',
          '${d['quantity']}',
          '${d['damageUnit'] == 'box' ? 'Box' : 'Pc'}',
          '${d['reason'] ?? ''}',
          '-${_fmt((d['estimatedLoss'] ?? 0).toDouble())}',
          '${d['reportedBy'] ?? ''}',
        ];
      }).toList(),
    );
  }

  // ── Helpers ──
  static String _fmt(double v) {
    if (v == v.roundToDouble() && v < 1000000) return v.toStringAsFixed(0);
    final nf = NumberFormat('#,##0', 'en_US');
    return nf.format(v);
  }

  static String _fmtFull(double v) {
    final nf = NumberFormat('#,##0.00', 'en_US');
    return nf.format(v);
  }
}
