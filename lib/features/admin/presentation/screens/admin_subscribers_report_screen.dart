// lib/features/admin/presentation/screens/admin_subscribers_report_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';
// import 'package:permission_handler/permission_handler.dart';
class AdminSubscribersReportScreen extends StatefulWidget {
  const AdminSubscribersReportScreen({super.key});

  @override
  State<AdminSubscribersReportScreen> createState() =>
      _AdminSubscribersReportScreenState();
}

class _AdminSubscribersReportScreenState
    extends State<AdminSubscribersReportScreen> {
  final _repo = AdminRepository();

  List<SubscriberReport> _report = [];
  bool _isLoading = true;

  late int _selectedMonth;
  late int _selectedYear;

  static const _arabicMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  static const _monthAbbrev = [
    'ي', 'ف', 'م', 'أ', 'م', 'ي', 'ي', 'أ', 'س', 'أ', 'ن', 'د',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repo.getSubscribersReport(
        month: _selectedMonth,
        year: _selectedYear,
      );
      if (mounted) setState(() => _report = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString(), style: GoogleFonts.cairo()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _fullyPaidCount {
    return _report.where((s) {
      final past =
      s.months.where((m) => m.monthNumber <= _selectedMonth).toList();
      return past.isNotEmpty &&
          past.every((m) => m.status == PaymentStatus.paid);
    }).length;
  }

  int get _overdueCount => _report
      .where((s) => s.months.any((m) => m.status == PaymentStatus.overdue))
      .length;

  double _calcPaid(SubscriberReport s) =>
      s.months.where((m) => m.status == PaymentStatus.paid).length *
          s.monthlyAmount;
  Future<void> _exportPdf() async {
    final doc = pw.Document();

    // تحميل خط Cairo لدعم اللغة العربية من الإنترنت مباشرة أو يمكنك استبداله بخط محلي
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final monthName = _arabicMonths[_selectedMonth - 1];

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ),
        build: (pw.Context ctx) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl, // دعم اللغة العربية
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'تقرير المشتركين - $monthName $_selectedYear',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 16),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    for (int i = 1; i <= 12; i++) i: const pw.FlexColumnWidth(1),
                    13: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    // رأس الجدول
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.green800),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('الاسم', style: pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                        ),
                        for (final a in _monthAbbrev)
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(a, textAlign: pw.TextAlign.center, style: pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                          ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('المجموع', textAlign: pw.TextAlign.center, style: pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                        ),
                      ],
                    ),
                    // بيانات المشتركين
                    ..._report.map((s) {
                      final paid = _calcPaid(s);
                      return pw.TableRow(children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(s.fullName, style: const pw.TextStyle(fontSize: 9)),
                        ),
                        for (final m in s.months)
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              m.status == PaymentStatus.paid ? '✓' : (m.status == PaymentStatus.overdue ? '✗' : '-'),
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: m.status == PaymentStatus.paid ? PdfColors.green700 : (m.status == PaymentStatus.overdue ? PdfColors.red700 : PdfColors.grey500),
                              ),
                            ),
                          ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            '\$${paid.toStringAsFixed(0)}',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                          ),
                        ),
                      ]);
                    }),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'الإجمالي: ${_report.length} | مدفوع: $_fullyPaidCount | متأخر: $_overdueCount',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'subscribers_${_selectedYear}_$_selectedMonth.pdf',
    );
  }
  Future<void> _exportExcel() async {
    // 1. طلب صلاحيات التخزين للأندرويد
    // if (Platform.isAndroid) {
    //   var status = await Permission.storage.status;
    //   if (!status.isGranted) {
    //     status = await Permission.storage.request();
    //     if (!status.isGranted) {
    //       if (mounted) {
    //         ScaffoldMessenger.of(context).showSnackBar(
    //           const SnackBar(content: Text('يجب الموافقة على صلاحيات التخزين لحفظ الملف')),
    //         );
    //       }
    //       return;
    //     }
    //   }
    // }

    final excel = Excel.createExcel();
    final sheet = excel['تقرير المشتركين'];
    excel.setDefaultSheet('تقرير المشتركين');

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1B5E42'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );

    final headers = [
      'الاسم', 'الهاتف',
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
      'المجموع المدفوع', 'الاشتراك السنوي',
    ];

    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // إضافة البيانات
    for (int r = 0; r < _report.length; r++) {
      final s = _report[r];
      final rowIdx = r + 1;
      final paidCount = s.months.where((m) => m.status == PaymentStatus.paid).length;
      final totalPaid = paidCount * s.monthlyAmount;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx)).value = TextCellValue(s.fullName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx)).value = TextCellValue(s.phone);

      for (int m = 0; m < 12; m++) {
        final status = s.months[m].status;
        final symbol = status == PaymentStatus.paid ? '✓' : (status == PaymentStatus.overdue ? '✗' : '–');

        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: m + 2, rowIndex: rowIdx));
        cell.value = TextCellValue(symbol);
        cell.cellStyle = CellStyle(
          horizontalAlign: HorizontalAlign.Center,
          backgroundColorHex: ExcelColor.fromHexString(status == PaymentStatus.paid ? '#C8E6C9' : (status == PaymentStatus.overdue ? '#FFCDD2' : '#F5F5F5')),
          fontColorHex: ExcelColor.fromHexString(status == PaymentStatus.paid ? '#1B5E20' : (status == PaymentStatus.overdue ? '#B71C1C' : '#9E9E9E')),
          bold: true,
        );
      }

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: rowIdx)).value = DoubleCellValue(totalPaid);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: rowIdx)).value = DoubleCellValue(s.annualAmount);
    }

    final fileBytes = excel.save();
    if (fileBytes == null) return;

    // تحديد مسار الحفظ
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download/SwidaGo');
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    if (!await dir.exists()) await dir.create(recursive: true);

    final fileName = 'subscribers_${_selectedYear}_$_selectedMonth.xlsx';
    final file = File('${dir.path}/$fileName');

    try {
      await file.writeAsBytes(fileBytes);
      if (mounted) _showSuccessDialog(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الحفظ: ${e.toString()}')),
        );
      }
    }
  }
  void _showSuccessDialog(String path) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تم الحفظ بنجاح',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 60),
            const SizedBox(height: 16),
            Text('تم حفظ التقرير في المسار التالي:',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(path,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('حسناً', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F2),
      body: Column(
        children: [
          _buildHeader(),
          _FilterBar(
            selectedMonth: _selectedMonth,
            selectedYear: _selectedYear,
            arabicMonths: _arabicMonths,
            onMonthChanged: (v) {
              setState(() => _selectedMonth = v);
              _loadReport();
            },
            onYearChanged: (v) {
              setState(() => _selectedYear = v);
              _loadReport();
            },
            onExportPdf: _exportPdf,
            onExportExcel: _exportExcel,
          ),
          _SummaryStrip(
            total: _report.length,
            fullyPaid: _fullyPaidCount,
            overdue: _overdueCount,
          ),
          _ColumnHeaders(monthAbbrev: _monthAbbrev),
          Expanded(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
                : _report.isEmpty
                ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.people_outline_rounded,
                          size: 36, color: AppColors.primary),
                    ),
                    const SizedBox(height: 14),
                    Text('لا توجد بيانات',
                        style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent)),
                    const SizedBox(height: 6),
                    Text('لا يوجد مشتركون في هذه الفترة',
                        style: GoogleFonts.cairo(
                            color: AppColors.textMuted, fontSize: 13)),
                  ],
                ))
                : ListView.builder(
              itemCount: _report.length,
              itemBuilder: (ctx, i) => _SubscriberRow(
                report: _report[i],
                index: i,
                paidAmount: _calcPaid(_report[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B6B44), AppColors.primary, Color(0xFF2ECC8B)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 20, 14),
          child: Row(
            children: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_rounded,
                      color: Colors.white, size: 16),
                ),
                onPressed: () => context.go('/admin/dashboard'),
              ),
              const SizedBox(width: 4),
              Text(
                'تقرير المشتركين',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_report.length} مشترك',
                  style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// EXTRACTED WIDGETS
// ═══════════════════════════════════════════════════════════

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedMonth,
    required this.selectedYear,
    required this.arabicMonths,
    required this.onMonthChanged,
    required this.onYearChanged,
    required this.onExportPdf,
    required this.onExportExcel,
  });

  final int selectedMonth;
  final int selectedYear;
  final List<String> arabicMonths;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onYearChanged;
  final VoidCallback onExportPdf;
  final VoidCallback onExportExcel;

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle:
    GoogleFonts.cairo(fontSize: 13, color: AppColors.textMuted),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    filled: true,
    fillColor: AppColors.primarySoft,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: selectedMonth,
                    isExpanded: true,
                    decoration: _dec('الشهر'),
                    items: List.generate(
                      12,
                          (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(arabicMonths[i],
                            style: GoogleFonts.cairo(fontSize: 13)),
                      ),
                    ),
                    onChanged: (v) {
                      if (v != null) onMonthChanged(v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<int>(
                    value: selectedYear,
                    isExpanded: true,
                    decoration: _dec('السنة'),
                    items: [2024, 2025, 2026]
                        .map((y) => DropdownMenuItem(
                      value: y,
                      child: Text('$y',
                          style: GoogleFonts.cairo(fontSize: 13)),
                    ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onYearChanged(v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 64,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      label: Text(
                        'تصدير PDF',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onExportPdf,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 64,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.table_chart_rounded, size: 16),
                      label: Text(
                        'تصدير Excel',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D6F42),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onExportExcel,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.total,
    required this.fullyPaid,
    required this.overdue,
  });
  final int total;
  final int fullyPaid;
  final int overdue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.border.withOpacity(0.5)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SummaryChip(
            label: 'المشتركين',
            value: '$total',
            color: AppColors.primary,
            icon: Icons.people_rounded,
          ),
          _Divider(),
          _SummaryChip(
            label: 'مدفوعون',
            value: '$fullyPaid',
            color: AppColors.success,
            icon: Icons.check_circle_rounded,
          ),
          _Divider(),
          _SummaryChip(
            label: 'متأخرون',
            value: '$overdue',
            color: AppColors.error,
            icon: Icons.warning_rounded,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.border.withOpacity(0.5),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color.withOpacity(0.7)),
            const SizedBox(width: 4),
            Text(value,
                style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
        Text(label,
            style: GoogleFonts.cairo(
                fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}

class _ColumnHeaders extends StatelessWidget {
  const _ColumnHeaders({required this.monthAbbrev});
  final List<String> monthAbbrev;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E42), AppColors.primary],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const nameW = 90.0;
          const totalW = 44.0;
          const spacing = 4.0;
          final monthsW =
              constraints.maxWidth - nameW - totalW - spacing * 2;

          return Row(
            children: [
              SizedBox(
                width: nameW,
                child: Text('المشترك',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
              const SizedBox(width: spacing),
              SizedBox(
                width: monthsW,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: monthAbbrev
                      .map((a) => SizedBox(
                    width: (monthsW / 12).clamp(10.0, 20.0),
                    child: Text(a,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.9))),
                  ))
                      .toList(),
                ),
              ),
              const SizedBox(width: spacing),
              SizedBox(
                width: totalW,
                child: Text('المجموع',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SubscriberRow extends StatelessWidget {
  const _SubscriberRow({
    required this.report,
    required this.index,
    required this.paidAmount,
  });

  final SubscriberReport report;
  final int index;
  final double paidAmount;

  Color _bg(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:
        return const Color(0xFFB9F6CA);
      case PaymentStatus.overdue:
        return const Color(0xFFFFCDD2);
      case PaymentStatus.pending:
        return const Color(0xFFECEFF1);
    }
  }

  Color _fg(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:
        return const Color(0xFF1B5E20);
      case PaymentStatus.overdue:
        return AppColors.error;
      case PaymentStatus.pending:
        return AppColors.textMuted;
    }
  }

  String _sym(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:
        return '✓';
      case PaymentStatus.overdue:
        return '✗';
      case PaymentStatus.pending:
        return '–';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: index.isEven ? Colors.white : const Color(0xFFF7FAF8),
          border: Border(
            bottom: BorderSide(
                color: AppColors.border.withOpacity(0.3), width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const nameW = 90.0;
            const totalW = 44.0;
            const spacing = 4.0;
            final monthsW =
                constraints.maxWidth - nameW - totalW - spacing * 2;
            final cellSize = (monthsW / 12).clamp(10.0, 20.0);

            return Row(
              children: [
                SizedBox(
                  width: nameW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        report.fullName,
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w600,
                            fontSize: 10.5,
                            color: AppColors.textDark),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        '\$${report.annualAmount.toStringAsFixed(0)}/سنة',
                        style: GoogleFonts.cairo(
                            fontSize: 9.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: spacing),
                SizedBox(
                  width: monthsW,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: report.months.map((m) {
                      return Container(
                        width: cellSize,
                        height: cellSize,
                        decoration: BoxDecoration(
                          color: _bg(m.status),
                          borderRadius:
                          BorderRadius.circular(cellSize * 0.3),
                        ),
                        child: Center(
                          child: Text(
                            _sym(m.status),
                            style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: cellSize * 0.55,
                                color: _fg(m.status)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: spacing),
                SizedBox(
                  width: totalW,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '\$${paidAmount.toStringAsFixed(0)}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ), // Container
    ); // SizedBox
  }
}