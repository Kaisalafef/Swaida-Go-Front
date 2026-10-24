// lib/features/admin/data/models/admin_models.dart

enum PaymentStatus { paid, overdue, pending }

class DashboardStats {
  final int totalSubscribers;
  final double appFundBalance;
  final double charityFundBalance;
  final double thisMonthPayments;

  const DashboardStats({
    required this.totalSubscribers,
    required this.appFundBalance,
    required this.charityFundBalance,
    required this.thisMonthPayments,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalSubscribers: (json['total_subscribers'] as num).toInt(),
      appFundBalance: (json['app_fund_balance'] as num).toDouble(),
      charityFundBalance: (json['charity_fund_balance'] as num).toDouble(),
      thisMonthPayments: (json['this_month_payments'] as num).toDouble(),
    );
  }
}

class MonthPayment {
  final int monthNumber; // 1–12
  final PaymentStatus status;

  const MonthPayment({required this.monthNumber, required this.status});
}

class SubscriberReport {
  final int id;
  final String fullName;
  final String phone;
  final double annualAmount;
  final double monthlyAmount;
  final List<MonthPayment> months; // always 12 items
  /// المبلغ المدفوع الفعلي خلال السنة (مجموع مبالغ الدفعات المدفوعة)
  /// وليس عدد الأشهر × القسط الحالي، لأن القسط قد يتغيّر مع تعديل الباقة.
  final double paidTotal;

  const SubscriberReport({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.annualAmount,
    required this.monthlyAmount,
    required this.months,
    this.paidTotal = 0,
  });
}

class FundTransfer {
  final int id;
  final double amount;
  final String recipientName;
  final String receiptNumber;
  final String transferDate; // "YYYY-MM-DD"
  final String note;

  const FundTransfer({
    required this.id,
    required this.amount,
    required this.recipientName,
    required this.receiptNumber,
    required this.transferDate,
    required this.note,
  });

  factory FundTransfer.fromJson(Map<String, dynamic> json) {
    return FundTransfer(
      id: (json['id'] as num).toInt(),
      amount: (json['amount'] as num).toDouble(),
      recipientName: json['recipient_name'] as String,
      receiptNumber: json['receipt_number'] as String,
      transferDate: json['transfer_date'] as String,
      note: (json['note'] as String?) ?? '',
    );
  }
}

class FundSummary {
  final double totalReceivedThisMonth;
  final double totalTransferredThisMonth;
  final double appFundBalance;
  final double charityFundBalance;

  // تفصيل الوارد حسب المصدر
  final double receivedGateway; // دفع إلكتروني
  final double receivedManual; // تسجيل يدوي
  final double receivedHistorical; // قبل إطلاق التطبيق

  // الاستحقاق في الفترة
  final double expectedTotal;
  final double collectedTotal;
  final double overdueTotal;
  final int paidCount;
  final int overdueCount;
  final int pendingCount;

  const FundSummary({
    required this.totalReceivedThisMonth,
    required this.totalTransferredThisMonth,
    required this.appFundBalance,
    required this.charityFundBalance,
    this.receivedGateway = 0,
    this.receivedManual = 0,
    this.receivedHistorical = 0,
    this.expectedTotal = 0,
    this.collectedTotal = 0,
    this.overdueTotal = 0,
    this.paidCount = 0,
    this.overdueCount = 0,
    this.pendingCount = 0,
  });

  static double _d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
  static int _i(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);

  factory FundSummary.fromJson(Map<String, dynamic> json) {
    return FundSummary(
      totalReceivedThisMonth: _d(json['total_received_this_month']),
      totalTransferredThisMonth: _d(json['total_transferred_this_month']),
      appFundBalance: _d(json['app_fund_balance']),
      charityFundBalance: _d(json['charity_fund_balance']),
      receivedGateway: _d(json['received_gateway']),
      receivedManual: _d(json['received_manual']),
      receivedHistorical: _d(json['received_historical']),
      expectedTotal: _d(json['expected_total']),
      collectedTotal: _d(json['collected_total']),
      overdueTotal: _d(json['overdue_total']),
      paidCount: _i(json['paid_count']),
      overdueCount: _i(json['overdue_count']),
      pendingCount: _i(json['pending_count']),
    );
  }
}

/// صف شهر واحد في التقرير السنوي
class YearlyMonthRow {
  final int month; // 1–12
  final double expected;
  final double collected;
  final double overdue;
  final double receivedGateway;
  final double receivedManual;
  final double receivedHistorical;
  final double transferred;

  const YearlyMonthRow({
    required this.month,
    required this.expected,
    required this.collected,
    required this.overdue,
    required this.receivedGateway,
    required this.receivedManual,
    required this.receivedHistorical,
    required this.transferred,
  });

  double get receivedTotal => receivedGateway + receivedManual + receivedHistorical;

  factory YearlyMonthRow.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
    return YearlyMonthRow(
      month: (j['month'] as num).toInt(),
      expected: d(j['expected_total']),
      collected: d(j['collected_total']),
      overdue: d(j['overdue_total']),
      receivedGateway: d(j['received_gateway']),
      receivedManual: d(j['received_manual']),
      receivedHistorical: d(j['received_historical']),
      transferred: d(j['transferred']),
    );
  }
}

class YearlyReport {
  final int year;
  final List<YearlyMonthRow> months;
  final double totalExpected;
  final double totalCollected;
  final double totalReceivedGateway;
  final double totalReceivedManual;
  final double totalReceivedHistorical;
  final double totalTransferred;

  const YearlyReport({
    required this.year,
    required this.months,
    required this.totalExpected,
    required this.totalCollected,
    required this.totalReceivedGateway,
    required this.totalReceivedManual,
    required this.totalReceivedHistorical,
    required this.totalTransferred,
  });

  factory YearlyReport.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
    final t = (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    return YearlyReport(
      year: (j['year'] as num).toInt(),
      months: ((j['months'] as List?) ?? const [])
          .map((e) => YearlyMonthRow.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      totalExpected: d(t['expected_total']),
      totalCollected: d(t['collected_total']),
      totalReceivedGateway: d(t['received_gateway']),
      totalReceivedManual: d(t['received_manual']),
      totalReceivedHistorical: d(t['received_historical']),
      totalTransferred: d(t['transferred']),
    );
  }
}

// ── CommissionSetting ─────────────────────────────────────
// يُستخدم مع GET /api/settings/commission و POST /api/admin/settings/commission
class CommissionSetting {
  final double value; // نسبة العمولة 0–100

  const CommissionSetting({required this.value});

  factory CommissionSetting.fromJson(Map<String, dynamic> json) {
    // يقبل: { commission: x } أو { value: x } أو { data: { commission: x } }
    final data = json['data'];
    final raw = json['commission_percentage'] ??
        json['commission'] ??
        json['value'] ??
        (data is Map
            ? data['commission_percentage'] ?? data['commission'] ?? data['value']
            : null);
    // إذا رجع null أو string نحوّله بأمان
    if (raw == null) return const CommissionSetting(value: 0);
    if (raw is num) return CommissionSetting(value: raw.toDouble());
    final parsed = double.tryParse(raw.toString()) ?? 0.0;
    return CommissionSetting(value: parsed);
  }
}

// ── StaffMember (حسابات الإدارة) ─────────────────────────────
class StaffMember {
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final String role; // admin | accountant
  final bool isActive;

  const StaffMember({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
  });

  bool get isAdmin => role == 'admin';

  factory StaffMember.fromJson(Map<String, dynamic> j) {
    final active = j['is_active'];
    return StaffMember(
      id: (j['id'] as num).toInt(),
      fullName: (j['full_name'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      phone: (j['phone'] ?? '').toString(),
      role: (j['role'] ?? 'accountant').toString(),
      // null (خادم قديم) = مفعّل
      isActive: active == null ? true : (active == true || active == 1),
    );
  }
}
