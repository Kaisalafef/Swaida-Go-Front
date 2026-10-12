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

  const SubscriberReport({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.annualAmount,
    required this.monthlyAmount,
    required this.months,
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

  const FundSummary({
    required this.totalReceivedThisMonth,
    required this.totalTransferredThisMonth,
    required this.appFundBalance,
    required this.charityFundBalance,
  });

  factory FundSummary.fromJson(Map<String, dynamic> json) {
    return FundSummary(
      totalReceivedThisMonth:
      (json['total_received_this_month'] as num).toDouble(),
      totalTransferredThisMonth:
      (json['total_transferred_this_month'] as num).toDouble(),
      appFundBalance: (json['app_fund_balance'] as num).toDouble(),
      charityFundBalance: (json['charity_fund_balance'] as num).toDouble(),
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