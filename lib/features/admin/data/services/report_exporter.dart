// lib/features/admin/data/services/report_exporter.dart
//
// خدمة موحّدة لتصدير التقارير (PDF + Excel) لشاشتي:
//   - تقرير المشتركين
//   - تقرير الصناديق
//
// أسباب مشاكل الـ PDF القديمة وكيف عُولجت:
//  1) pw.Page لا يقسّم المحتوى على صفحات → أي جدول أطول من الصفحة يختفي
//     (لهذا ظهر العنوان فقط)         → استُبدل بـ pw.MultiPage مع تكرار رأس الجدول.
//  2) رموز ✓ ✗ غير موجودة في خط Cairo → تظهر فارغة/مربعات → استُبدلت بخلايا ملوّنة.
//  3) الخط كان يُحمَّل من الإنترنت فقط  → يفشل بلا اتصال → يُحمَّل من assets أولاً
//     ثم يرجع للإنترنت كاحتياط.
//  4) ترتيب أعمدة الجدول مع RTL غير مضمون → نبني الأعمدة بترتيب بصري صريح
//     (أول عمود منطقي = أقصى اليمين).
//  5) حفظ Excel في /storage/emulated/0/Download يفشل في أندرويد 11+ → الآن يُنشأ
//     الملف مؤقتاً ويُشارَك (حفظ في الملفات/Drive/واتساب...).

import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart'
    show
    Excel,
    Sheet,
    CellIndex,
    CellStyle,
    CellValue,
    TextCellValue,
    DoubleCellValue,
    IntCellValue,
    ExcelColor,
    HorizontalAlign;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/admin_models.dart';

class ReportExporter {
  ReportExporter._();

  static const _brand = PdfColor.fromInt(0xFF1B5E42);
  static const _paidColor = PdfColor.fromInt(0xFF43A047);
  static const _overdueColor = PdfColor.fromInt(0xFFE53935);
  static const _pendingColor = PdfColor.fromInt(0xFFBDBDBD);
  static const _zebra = PdfColor.fromInt(0xFFF4F7F5);

  static const _monthNames = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  // ───────────────────────────── الخطوط ─────────────────────────────
  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<void> _ensureFonts() async {
    if (_regular != null && _bold != null) return;
    try {
      // ضع الملفين في assets/fonts/ وعرّفهما في pubspec.yaml (اختياري لكن موصى به)
      final r = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final b = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      _regular = pw.Font.ttf(r);
      _bold = pw.Font.ttf(b);
    } catch (_) {
      _regular = await PdfGoogleFonts.cairoRegular();
      _bold = await PdfGoogleFonts.cairoBold();
    }
  }

  static pw.ThemeData get _theme =>
      pw.ThemeData.withFont(base: _regular!, bold: _bold!);

  // ───────────────────────────── تنسيق ─────────────────────────────
  static String _num(double v) {
    final neg = v < 0;
    final a = v.abs();
    final isInt = a == a.roundToDouble();
    final s = a.toStringAsFixed(isInt ? 0 : 2);
    final parts = s.split('.');
    final intPart = parts[0]
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return '${neg ? '-' : ''}$intPart${parts.length > 1 ? '.${parts[1]}' : ''}';
  }

  static String _money(double v) => '\$${_num(v)}';

  // ───────────────────────── عناصر PDF مشتركة ─────────────────────────
  static pw.Widget _t(
      String text, {
        double size = 9,
        bool bold = false,
        PdfColor? color,
        pw.TextAlign align = pw.TextAlign.right,
        bool ltr = false,
      }) {
    return pw.Text(
      text,
      textDirection: ltr ? pw.TextDirection.ltr : pw.TextDirection.rtl,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      ),
    );
  }

  /// خلية نص عادية (وسط). الأرقام/المبالغ ltr حتى لا تنقلب.
  static pw.Widget _c(String text,
      {bool bold = false,
        PdfColor? color,
        bool ltr = false,
        pw.TextAlign align = pw.TextAlign.center,
        double size = 9}) =>
      _t(text,
          size: size, bold: bold, color: color, ltr: ltr, align: align);

  static pw.Widget _colorCell(PdfColor color) => pw.Container(
    height: 12,
    decoration: pw.BoxDecoration(
      color: color,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
    ),
  );

  /// جدول بترتيب منطقي RTL: العنصر الأول في [headers] هو أقصى اليمين.
  /// نعكس القوائم داخلياً ونعرض الجدول LTR لنضمن الترتيب في كل إصدارات المكتبة.
  static pw.Widget _table({
    required List<String> headers,
    required List<List<pw.Widget>> rows,
    required List<double> flex,
    Set<int> boldRows = const {},
  }) {
    List<T> rev<T>(List<T> l) => l.reversed.toList();
    final f = rev(flex);

    pw.Widget pad(pw.Widget w) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: w,
    );

    return pw.Directionality(
      textDirection: pw.TextDirection.ltr,
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        columnWidths: {
          for (var i = 0; i < f.length; i++) i: pw.FlexColumnWidth(f[i]),
        },
        children: [
          pw.TableRow(
            repeat: true, // يتكرر رأس الجدول في كل صفحة
            decoration: const pw.BoxDecoration(color: _brand),
            children: rev(headers)
                .map((h) => pad(_c(h, bold: true, color: PdfColors.white, size: 8)))
                .toList(),
          ),
          for (var i = 0; i < rows.length; i++)
            pw.TableRow(
              decoration: boldRows.contains(i)
                  ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE3EFE8))
                  : (i.isOdd ? const pw.BoxDecoration(color: _zebra) : null),
              children: rev(rows[i]).map(pad).toList(),
            ),
        ],
      ),
    );
  }

  static pw.Widget _title(String title, String subtitle) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(12),
    decoration: const pw.BoxDecoration(
      color: _brand,
      borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _t(title, size: 16, bold: true, color: PdfColors.white),
        pw.SizedBox(height: 3),
        _t(subtitle, size: 10, color: PdfColors.white),
      ],
    ),
  );

  static pw.Widget _section(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
    child: pw.Align(
      alignment: pw.Alignment.centerRight,
      child: _t(title, size: 12, bold: true, color: _brand),
    ),
  );

  static pw.Widget _footer(pw.Context ctx) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 8),
    child: pw.Align(
      alignment: pw.Alignment.center,
      child: _t('صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
          size: 8, color: PdfColors.grey700, align: pw.TextAlign.center),
    ),
  );

  static pw.Widget _legendItem(String label, PdfColor color) => pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      _t(label, size: 8),
      pw.SizedBox(width: 4),
      pw.Container(width: 10, height: 10, color: color),
      pw.SizedBox(width: 14),
    ],
  );

  // ═════════════════════════════════════════════════════════════════
  // تقرير المشتركين — PDF
  // ═════════════════════════════════════════════════════════════════
  static Future<Uint8List> subscribersPdf({
    required List<SubscriberReport> report,
    required int month,
    required int year,
    required int fullyPaid,
    required int overdue,
  }) async {
    await _ensureFonts();
    final doc = pw.Document(theme: _theme);
    final monthName = _monthNames[month - 1];

    final rows = <List<pw.Widget>>[
      for (final s in report)
        [
          _c(s.fullName, align: pw.TextAlign.right),
          _c(s.phone, ltr: true),
          for (final m in s.months)
            _colorCell(m.status == PaymentStatus.paid
                ? _paidColor
                : m.status == PaymentStatus.overdue
                ? _overdueColor
                : _pendingColor),
          _c(_money(s.paidTotal), bold: true, color: _brand, ltr: true),
        ],
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        footer: _footer,
        build: (ctx) => [
          _title('تقرير المشتركين', '$monthName $year'),
          pw.SizedBox(height: 8),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: _t(
              'الإجمالي: ${report.length}   |   مدفوع بالكامل: $fullyPaid   |   متأخر: $overdue',
              size: 10,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Directionality(
            textDirection: pw.TextDirection.ltr,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                // ترتيب بصري من اليسار لليمين
                _legendItem('لم يحن بعد', _pendingColor),
                _legendItem('متأخر', _overdueColor),
                _legendItem('مدفوع', _paidColor),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          if (report.isEmpty)
            pw.Center(child: _t('لا توجد بيانات', size: 12))
          else
            _table(
              headers: [
                'الاسم',
                'الهاتف',
                ..._monthNames,
                'المدفوع',
              ],
              flex: [3.2, 2.3, ...List.filled(12, 1.0), 1.9],
              rows: rows,
            ),
        ],
      ),
    );

    return doc.save();
  }

  // ═════════════════════════════════════════════════════════════════
  // تقرير الصناديق — PDF
  // ═════════════════════════════════════════════════════════════════
  static Future<Uint8List> fundReportPdf({
    required FundSummary summary,
    required List<FundTransfer> transfers,
    required YearlyReport? yearly,
    required String periodLabel,
    required bool isMonthly,
  }) async {
    await _ensureFonts();
    final doc = pw.Document(theme: _theme);
    final s = summary;

    pw.Widget kv(List<List<String>> items) => _table(
      headers: const ['البند', 'القيمة'],
      flex: const [3, 2],
      rows: [
        for (final it in items) [_c(it[0], align: pw.TextAlign.right), _c(it[1], ltr: true, bold: true)],
      ],
    );

    final transfersTotal = transfers.fold<double>(0, (a, t) => a + t.amount);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: _footer,
        build: (ctx) => [
          _title('تقرير الصناديق', periodLabel),
          _section('ملخص الفترة'),
          kv([
            ['إجمالي المقبوضات', _money(s.totalReceivedThisMonth)],
            ['إجمالي المحوّل', _money(s.totalTransferredThisMonth)],
            ['رصيد صندوق التطبيق', _money(s.appFundBalance)],
            ['رصيد صندوق الفريق التطوعي', _money(s.charityFundBalance)],
          ]),
          _section('مصدر الوارد في الفترة'),
          kv([
            ['دفع إلكتروني', _money(s.receivedGateway)],
            ['تسجيل يدوي', _money(s.receivedManual)],
            ['دفعات قبل إطلاق التطبيق', _money(s.receivedHistorical)],
          ]),
          _section(isMonthly ? 'المستحق لهذا الشهر' : 'المستحق لهذه السنة'),
          kv([
            ['المطلوب', _money(s.expectedTotal)],
            ['المحصّل', _money(s.collectedTotal)],
            ['المتأخر', _money(s.overdueTotal)],
            ['عدد الدفعات المدفوعة', '${s.paidCount}'],
            ['عدد الدفعات المتأخرة', '${s.overdueCount}'],
            ['عدد الدفعات التي لم يحن موعدها', '${s.pendingCount}'],
          ]),
          if (!isMonthly && yearly != null) ...[
            _section('التقرير السنوي ${yearly.year}'),
            _table(
              headers: const [
                'الشهر', 'المطلوب', 'المحصّل', 'إلكتروني',
                'يدوي', 'قبل التطبيق', 'المحوّل',
              ],
              flex: const [1.6, 1.4, 1.4, 1.4, 1.2, 1.4, 1.4],
              boldRows: {yearly.months.length},
              rows: [
                for (final r in yearly.months)
                  [
                    _c(_monthNames[r.month - 1], align: pw.TextAlign.right),
                    _c(_money(r.expected), ltr: true),
                    _c(_money(r.collected), ltr: true),
                    _c(_money(r.receivedGateway), ltr: true),
                    _c(_money(r.receivedManual), ltr: true),
                    _c(_money(r.receivedHistorical), ltr: true),
                    _c(_money(r.transferred), ltr: true),
                  ],
                [
                  _c('الإجمالي', bold: true, align: pw.TextAlign.right),
                  _c(_money(yearly.totalExpected), ltr: true, bold: true),
                  _c(_money(yearly.totalCollected), ltr: true, bold: true),
                  _c(_money(yearly.totalReceivedGateway), ltr: true, bold: true),
                  _c(_money(yearly.totalReceivedManual), ltr: true, bold: true),
                  _c(_money(yearly.totalReceivedHistorical), ltr: true, bold: true),
                  _c(_money(yearly.totalTransferred), ltr: true, bold: true),
                ],
              ],
            ),
          ],
          _section('سجل التحويلات (${transfers.length})'),
          if (transfers.isEmpty)
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: _t('لا توجد تحويلات مسجّلة في هذه الفترة', size: 10),
            )
          else
            _table(
              headers: const [
                'التاريخ', 'المستلم', 'رقم الإيصال', 'المبلغ', 'الملاحظة',
              ],
              flex: const [1.5, 2.2, 1.8, 1.4, 2.6],
              boldRows: {transfers.length},
              rows: [
                for (final t in transfers)
                  [
                    _c(t.transferDate, ltr: true),
                    _c(t.recipientName, align: pw.TextAlign.right),
                    _c(t.receiptNumber, ltr: true),
                    _c(_money(t.amount), ltr: true, bold: true),
                    _c(t.note.isEmpty ? '—' : t.note, align: pw.TextAlign.right),
                  ],
                [
                  _c('الإجمالي', bold: true),
                  _c(''),
                  _c(''),
                  _c(_money(transfersTotal), ltr: true, bold: true),
                  _c(''),
                ],
              ],
            ),
        ],
      ),
    );

    return doc.save();
  }

  // ═════════════════════════════════════════════════════════════════
  // Excel
  // ═════════════════════════════════════════════════════════════════
  static CellStyle get _xHeader => CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.fromHexString('#1B5E42'),
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    horizontalAlign: HorizontalAlign.Center,
  );

  static CellStyle get _xTotal => CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.fromHexString('#E3EFE8'),
  );

  static void _xPut(Sheet sh, int col, int row, CellValue v, [CellStyle? st]) {
    final cell =
    sh.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = v;
    if (st != null) cell.cellStyle = st;
  }

  static void _xHeaders(Sheet sh, int row, List<String> headers) {
    for (var i = 0; i < headers.length; i++) {
      _xPut(sh, i, row, TextCellValue(headers[i]), _xHeader);
    }
  }

  static void _xWidths(Sheet sh, List<double> widths) {
    for (var i = 0; i < widths.length; i++) {
      sh.setColumnWidth(i, widths[i]);
    }
  }

  static void _xDropDefault(Excel excel, String keep) {
    try {
      excel.setDefaultSheet(keep);
      if (keep != 'Sheet1') excel.delete('Sheet1');
    } catch (_) {}
  }

  static Uint8List _xSave(Excel excel) {
    final bytes = excel.save();
    if (bytes == null) throw Exception('تعذر إنشاء ملف Excel');
    return Uint8List.fromList(bytes);
  }

  // ── تقرير المشتركين ───────────────────────────────────────────────
  static Uint8List subscribersExcel({
    required List<SubscriberReport> report,
    required int month,
    required int year,
  }) {
    const sheetName = 'تقرير المشتركين';
    final excel = Excel.createExcel();
    final sh = excel[sheetName];
    _xDropDefault(excel, sheetName);

    _xPut(sh, 0, 0, TextCellValue('تقرير المشتركين - ${_monthNames[month - 1]} $year'),
        CellStyle(bold: true, fontSize: 14));

    _xHeaders(sh, 2, [
      'الاسم', 'الهاتف', ..._monthNames, 'المجموع المدفوع', 'الاشتراك السنوي',
    ]);
    _xWidths(sh, [26, 16, ...List.filled(12, 10), 16, 16]);

    for (var r = 0; r < report.length; r++) {
      final s = report[r];
      final row = r + 3;
      _xPut(sh, 0, row, TextCellValue(s.fullName));
      _xPut(sh, 1, row, TextCellValue(s.phone));
      for (var m = 0; m < s.months.length && m < 12; m++) {
        final st = s.months[m].status;
        final paid = st == PaymentStatus.paid;
        final over = st == PaymentStatus.overdue;
        _xPut(
          sh,
          m + 2,
          row,
          TextCellValue(paid ? '✓' : (over ? '✗' : '–')),
          CellStyle(
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: ExcelColor.fromHexString(
                paid ? '#C8E6C9' : (over ? '#FFCDD2' : '#F5F5F5')),
            fontColorHex: ExcelColor.fromHexString(
                paid ? '#1B5E20' : (over ? '#B71C1C' : '#9E9E9E')),
          ),
        );
      }
      _xPut(sh, 14, row, DoubleCellValue(s.paidTotal));
      _xPut(sh, 15, row, DoubleCellValue(s.annualAmount));
    }

    final totalRow = report.length + 3;
    _xPut(sh, 0, totalRow, TextCellValue('الإجمالي'), _xTotal);
    _xPut(sh, 14, totalRow,
        DoubleCellValue(report.fold<double>(0, (a, s) => a + s.paidTotal)), _xTotal);
    _xPut(sh, 15, totalRow,
        DoubleCellValue(report.fold<double>(0, (a, s) => a + s.annualAmount)), _xTotal);

    return _xSave(excel);
  }

  // ── تقرير الصناديق ────────────────────────────────────────────────
  static Uint8List fundReportExcel({
    required FundSummary summary,
    required List<FundTransfer> transfers,
    required YearlyReport? yearly,
    required String periodLabel,
    required bool isMonthly,
  }) {
    const sSummary = 'الملخص';
    const sYearly = 'التقرير السنوي';
    const sTransfers = 'التحويلات';

    final excel = Excel.createExcel();
    final s = summary;

    // 1) الملخص
    final sh1 = excel[sSummary];
    _xPut(sh1, 0, 0, TextCellValue('تقرير الصناديق - $periodLabel'),
        CellStyle(bold: true, fontSize: 14));
    _xHeaders(sh1, 2, ['البند', 'القيمة']);
    _xWidths(sh1, [38, 18]);

    final items = <List<Object>>[
      ['إجمالي المقبوضات', s.totalReceivedThisMonth],
      ['إجمالي المحوّل', s.totalTransferredThisMonth],
      ['رصيد صندوق التطبيق', s.appFundBalance],
      ['رصيد صندوق الفريق التطوعي', s.charityFundBalance],
      ['— مصدر الوارد —', ''],
      ['دفع إلكتروني', s.receivedGateway],
      ['تسجيل يدوي', s.receivedManual],
      ['دفعات قبل إطلاق التطبيق', s.receivedHistorical],
      [isMonthly ? '— المستحق لهذا الشهر —' : '— المستحق لهذه السنة —', ''],
      ['المطلوب', s.expectedTotal],
      ['المحصّل', s.collectedTotal],
      ['المتأخر', s.overdueTotal],
      ['عدد الدفعات المدفوعة', s.paidCount],
      ['عدد الدفعات المتأخرة', s.overdueCount],
      ['عدد الدفعات التي لم يحن موعدها', s.pendingCount],
    ];
    for (var i = 0; i < items.length; i++) {
      final label = items[i][0] as String;
      final v = items[i][1];
      final isSep = v is String;
      _xPut(sh1, 0, i + 3, TextCellValue(label), isSep ? _xTotal : null);
      if (v is double) {
        _xPut(sh1, 1, i + 3, DoubleCellValue(v));
      } else if (v is int) {
        _xPut(sh1, 1, i + 3, IntCellValue(v));
      } else if (isSep) {
        _xPut(sh1, 1, i + 3, TextCellValue(''), _xTotal);
      }
    }

    // 2) التقرير السنوي
    if (!isMonthly && yearly != null) {
      final sh2 = excel[sYearly];
      _xHeaders(sh2, 0, [
        'الشهر', 'المطلوب', 'المحصّل', 'المتأخر',
        'إلكتروني', 'يدوي', 'قبل التطبيق', 'المحوّل',
      ]);
      _xWidths(sh2, [16, 14, 14, 14, 14, 14, 14, 14]);
      for (var i = 0; i < yearly.months.length; i++) {
        final r = yearly.months[i];
        final row = i + 1;
        _xPut(sh2, 0, row, TextCellValue(_monthNames[r.month - 1]));
        _xPut(sh2, 1, row, DoubleCellValue(r.expected));
        _xPut(sh2, 2, row, DoubleCellValue(r.collected));
        _xPut(sh2, 3, row, DoubleCellValue(r.overdue));
        _xPut(sh2, 4, row, DoubleCellValue(r.receivedGateway));
        _xPut(sh2, 5, row, DoubleCellValue(r.receivedManual));
        _xPut(sh2, 6, row, DoubleCellValue(r.receivedHistorical));
        _xPut(sh2, 7, row, DoubleCellValue(r.transferred));
      }
      final tr = yearly.months.length + 1;
      _xPut(sh2, 0, tr, TextCellValue('الإجمالي'), _xTotal);
      _xPut(sh2, 1, tr, DoubleCellValue(yearly.totalExpected), _xTotal);
      _xPut(sh2, 2, tr, DoubleCellValue(yearly.totalCollected), _xTotal);
      _xPut(sh2, 3, tr, TextCellValue(''), _xTotal);
      _xPut(sh2, 4, tr, DoubleCellValue(yearly.totalReceivedGateway), _xTotal);
      _xPut(sh2, 5, tr, DoubleCellValue(yearly.totalReceivedManual), _xTotal);
      _xPut(sh2, 6, tr, DoubleCellValue(yearly.totalReceivedHistorical), _xTotal);
      _xPut(sh2, 7, tr, DoubleCellValue(yearly.totalTransferred), _xTotal);
    }

    // 3) التحويلات
    final sh3 = excel[sTransfers];
    _xHeaders(sh3, 0, ['التاريخ', 'المستلم', 'رقم الإيصال', 'المبلغ', 'الملاحظة']);
    _xWidths(sh3, [14, 26, 18, 14, 36]);
    for (var i = 0; i < transfers.length; i++) {
      final t = transfers[i];
      final row = i + 1;
      _xPut(sh3, 0, row, TextCellValue(t.transferDate));
      _xPut(sh3, 1, row, TextCellValue(t.recipientName));
      _xPut(sh3, 2, row, TextCellValue(t.receiptNumber));
      _xPut(sh3, 3, row, DoubleCellValue(t.amount));
      _xPut(sh3, 4, row, TextCellValue(t.note));
    }
    final tRow = transfers.length + 1;
    _xPut(sh3, 0, tRow, TextCellValue('الإجمالي'), _xTotal);
    _xPut(sh3, 1, tRow, TextCellValue(''), _xTotal);
    _xPut(sh3, 2, tRow, TextCellValue(''), _xTotal);
    _xPut(sh3, 3, tRow,
        DoubleCellValue(transfers.fold<double>(0, (a, t) => a + t.amount)), _xTotal);
    _xPut(sh3, 4, tRow, TextCellValue(''), _xTotal);

    _xDropDefault(excel, sSummary);
    return _xSave(excel);
  }

  // ═════════════════════════════════════════════════════════════════
  // المشاركة / الحفظ
  // ═════════════════════════════════════════════════════════════════
  /// يفتح قائمة المشاركة (حفظ في الملفات، Drive، واتساب، طباعة...).
  static Future<void> sharePdf(Uint8List bytes, String fileName) =>
      Printing.sharePdf(bytes: bytes, filename: fileName);

  static Future<void> shareExcel(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          name: fileName,
        ),
      ],
      subject: fileName,
    );
  }
}