// lib/features/subscriber/data/models/subscriber_models.dart

enum MonthStatus { paid, overdue, pending }

class SubscriptionInfo {
  final int id;
  final double annualAmount;
  final double monthlyAmount;
  final String startDate;
  final List<MonthPaymentInfo> months;

  const SubscriptionInfo({
    required this.id,
    required this.annualAmount,
    required this.monthlyAmount,
    required this.startDate,
    required this.months,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      id: json['id'] as int,
      annualAmount: (json['annual_amount'] as num).toDouble(),
      monthlyAmount: (json['monthly_amount'] as num).toDouble(),
      startDate: json['start_date'] as String,
      months: (json['months'] as List<dynamic>)
          .map((m) => MonthPaymentInfo.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MonthPaymentInfo {
  final int monthNumber;
  final String monthName;
  final MonthStatus status;
  final double amount;
  final String? paidAt;

  const MonthPaymentInfo({
    required this.monthNumber,
    required this.monthName,
    required this.status,
    required this.amount,
    this.paidAt,
  });

  factory MonthPaymentInfo.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String;
    MonthStatus status;
    switch (statusStr) {
      case 'paid':
        status = MonthStatus.paid;
        break;
      case 'overdue':
        status = MonthStatus.overdue;
        break;
      default:
        status = MonthStatus.pending;
    }
    return MonthPaymentInfo(
      monthNumber: json['month_number'] as int,
      monthName: json['month_name'] as String,
      status: status,
      amount: (json['amount'] as num).toDouble(),
      paidAt: json['paid_at'] as String?,
    );
  }
}

class PaymentSession {
  final String checkoutUrl;
  final List<int> months;
  final double totalAmount;

  const PaymentSession({
    required this.checkoutUrl,
    required this.months,
    required this.totalAmount,
  });

  factory PaymentSession.fromJson(Map<String, dynamic> json) {
    return PaymentSession(
      checkoutUrl: json['checkout_url'] as String,
      months: (json['months'] as List<dynamic>).map((e) => e as int).toList(),
      totalAmount: (json['total_amount'] as num).toDouble(),
    );
  }
}

class PaymentRecord {
  final int id;
  final List<int> months;
  final double amount;
  final String paidAt;
  final String receiptNumber;

  const PaymentRecord({
    required this.id,
    required this.months,
    required this.amount,
    required this.paidAt,
    required this.receiptNumber,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] as int,
      months: (json['months'] as List<dynamic>).map((e) => e as int).toList(),
      amount: (json['amount'] as num).toDouble(),
      paidAt: json['paid_at'] as String,
      receiptNumber: json['receipt_number'] as String,
    );
  }
}

class UserProfile {
  final int id;
  final String fullName;
  final String email;
  /// بريد جديد طُلب تغييره وينتظر التأكيد بالرابط (null = لا يوجد طلب)
  final String? pendingEmail;
  final String phone;
  final String joinedAt;
  final SubscriptionInfo? subscription;
  final List<PaymentRecord> paymentHistory;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.pendingEmail,
    required this.phone,
    required this.joinedAt,
    this.subscription,
    required this.paymentHistory,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      pendingEmail: json['pending_email'] as String?,
      phone: json['phone'] as String,
      joinedAt: json['joined_at'] as String,
      subscription: json['subscription'] != null
          ? SubscriptionInfo.fromJson(
          json['subscription'] as Map<String, dynamic>)
          : null,
      paymentHistory: (json['payment_history'] as List<dynamic>)
          .map((r) => PaymentRecord.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── معاينة / نتيجة تغيير الباقة ──────────────────────────────
class PackageChangePlan {
  final double currentAnnual;
  final double currentMonthly;
  final double newAnnual;
  final double newMonthly;
  final int effectiveMonth; // الشهر الذي يبدأ منه السريان
  final List<int> affectedMonths;
  final double remainingBefore;
  final double remainingAfter;
  final double difference;
  final String direction; // increase | decrease | same
  final bool canChange;
  final String? blockedReason;

  const PackageChangePlan({
    required this.currentAnnual,
    required this.currentMonthly,
    required this.newAnnual,
    required this.newMonthly,
    required this.effectiveMonth,
    required this.affectedMonths,
    required this.remainingBefore,
    required this.remainingAfter,
    required this.difference,
    required this.direction,
    required this.canChange,
    this.blockedReason,
  });

  int get affectedCount => affectedMonths.length;

  factory PackageChangePlan.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
    final cur = (j['current'] as Map).cast<String, dynamic>();
    final nw = (j['new'] as Map).cast<String, dynamic>();
    final eff = (j['effective_from'] as Map).cast<String, dynamic>();
    return PackageChangePlan(
      currentAnnual: d(cur['annual_amount']),
      currentMonthly: d(cur['monthly_amount']),
      newAnnual: d(nw['annual_amount']),
      newMonthly: d(nw['monthly_amount']),
      effectiveMonth: (eff['month'] as num).toInt(),
      affectedMonths: ((j['affected_months'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      remainingBefore: d(j['remaining_before']),
      remainingAfter: d(j['remaining_after']),
      difference: d(j['difference']),
      direction: (j['direction'] ?? 'same').toString(),
      canChange: j['can_change'] == true,
      blockedReason: j['blocked_reason'] as String?,
    );
  }
}

// ── بداية سنة جديدة: متأخرات إجبارية → تجديد / تغيير / إيقاف ─────
enum YearState { ok, mustPay, choose, stopped, noSubscription }

class OverdueItem {
  final int id;
  final int year;
  final int monthNumber;
  final double amount;

  const OverdueItem({
    required this.id,
    required this.year,
    required this.monthNumber,
    required this.amount,
  });

  factory OverdueItem.fromJson(Map<String, dynamic> j) {
    return OverdueItem(
      id: (j['id'] as num).toInt(),
      year: (j['year'] as num).toInt(),
      monthNumber: (j['month_number'] as num).toInt(),
      amount: (j['amount'] as num).toDouble(),
    );
  }
}

class YearStatus {
  final YearState state;
  final int currentYear;
  final double annualAmount;
  final double monthlyAmount;
  final double minAnnual;
  final double maxAnnual;
  final bool canStop;
  final List<OverdueItem> overdueItems;
  final double overdueTotal;

  const YearStatus({
    required this.state,
    required this.currentYear,
    required this.annualAmount,
    required this.monthlyAmount,
    required this.minAnnual,
    required this.maxAnnual,
    required this.canStop,
    required this.overdueItems,
    required this.overdueTotal,
  });

  List<int> get overdueIds => overdueItems.map((e) => e.id).toList();

  factory YearStatus.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);

    YearState state;
    switch ((j['state'] ?? '').toString()) {
      case 'must_pay':
        state = YearState.mustPay;
        break;
      case 'choose':
        state = YearState.choose;
        break;
      case 'stopped':
        state = YearState.stopped;
        break;
      case 'no_subscription':
        state = YearState.noSubscription;
        break;
      default:
        state = YearState.ok;
    }

    final overdue =
        (j['overdue'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    return YearStatus(
      state: state,
      currentYear: (j['current_year'] as num?)?.toInt() ?? DateTime.now().year,
      annualAmount: d(j['annual_amount']),
      monthlyAmount: d(j['monthly_amount']),
      minAnnual: j['min_annual'] == null ? 60 : d(j['min_annual']),
      maxAnnual: j['max_annual'] == null ? 1200 : d(j['max_annual']),
      canStop: j['can_stop'] == true,
      overdueItems: ((overdue['items'] as List?) ?? const [])
          .map((e) => OverdueItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      overdueTotal: d(overdue['total']),
    );
  }
}
