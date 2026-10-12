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
  final String phone;
  final String joinedAt;
  final SubscriptionInfo? subscription;
  final List<PaymentRecord> paymentHistory;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
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
