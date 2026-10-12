// lib/features/admin/presentation/screens/admin_fund_transfer_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../data/repositories/admin_repository.dart';

class AdminFundTransferScreen extends StatefulWidget {
  const AdminFundTransferScreen({super.key});

  @override
  State<AdminFundTransferScreen> createState() =>
      _AdminFundTransferScreenState();
}

class _AdminFundTransferScreenState extends State<AdminFundTransferScreen> {
  final _repo = AdminRepository();
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _recipientController = TextEditingController();
  final _receiptController = TextEditingController();
  final _noteController = TextEditingController();

  double _appFundBalance = 0;
  bool _isLoadingBalance = true;
  bool _isLoading = false;
  bool _showPreview = false;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadBalance();
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _recipientController.dispose();
    _receiptController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    final val = double.tryParse(_amountController.text);
    final show = val != null && val > 0;
    if (show != _showPreview) setState(() => _showPreview = show);
  }

  Future<void> _loadBalance() async {
    try {
      final stats = await _repo.getDashboardStats();
      if (mounted) {
        setState(() {
          _appFundBalance = stats.appFundBalance;
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingBalance = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ar'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.white,
            onSurface: AppColors.textDark,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submitTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
        Text('يرجى اختيار تاريخ التحويل', style: GoogleFonts.cairo()),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _repo.transferFunds(
        amount: double.parse(_amountController.text),
        recipientName: _recipientController.text.trim(),
        receiptNumber: _receiptController.text.trim(),
        transferDate: _selectedDate!,
        note: _noteController.text.trim(),
      );

      if (!mounted) return;

      final amount = _amountController.text;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28)),
          elevation: 0,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E7D32), AppColors.success],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  'تم التحويل بنجاح',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: AppColors.accent,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'تم تحويل \$$amount\nإلى صندوق الجمعية',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: AppColors.textMuted,
                    height: 1.7,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.go('/admin/dashboard');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text('العودة للوحة الإدارة',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString(), style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F2),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 18),
                  _buildFormCard(),
                  const SizedBox(height: 14),
                  _buildPreview(),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'تأكيد التحويل',
                    isLoading: _isLoading,
                    onPressed: _submitTransfer,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          color: AppColors.textMuted.withOpacity(0.5),
                          size: 13),
                      const SizedBox(width: 6),
                      Text(
                        'هذه العملية لا يمكن التراجع عنها بعد التأكيد',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.textMuted.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: IconButton(
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
      ),
      title: Text(
        'تحويل الصناديق',
        style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
      ),
      centerTitle: true,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B6B44), AppColors.primary, Color(0xFF2ECC8B)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E42), AppColors.primary],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الرصيد المتاح',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF69F0AE),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('صندوق التطبيق',
                            style: GoogleFonts.cairo(
                                fontSize: 11, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _isLoadingBalance
                  ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
                  : Text(
                '\$${_appFundBalance.toStringAsFixed(2)}',
                style: GoogleFonts.cairo(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _FundChip(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'صندوق التطبيق',
                          sub: 'المصدر'),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward,
                          color: Colors.white, size: 16),
                    ),
                    Expanded(
                      child: _FundChip(
                          icon: Icons.volunteer_activism_rounded,
                          label: 'صندوق الفريق التطوعي',
                          sub: 'الوجهة'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FormSectionTitle(
                icon: Icons.edit_note_rounded, title: 'تفاصيل التحويل'),
            const SizedBox(height: 20),
            AppTextField(
              label: 'المبلغ (USD)',
              hint: '0.00',
              controller: _amountController,
              prefixIcon: Icons.attach_money_rounded,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              validator: (value) {
                if (value == null || value.trim().isEmpty)
                  return 'المبلغ مطلوب';
                final v = double.tryParse(value.trim());
                if (v == null) return 'أدخل رقماً صحيحاً';
                if (v <= 0) return 'يجب أن يكون المبلغ أكبر من صفر';
                if (v > _appFundBalance) return 'المبلغ يتجاوز الرصيد المتاح';
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'اسم المستلم',
              hint: 'اسم ممثل الجمعية',
              controller: _recipientController,
              prefixIcon: Icons.person_outline_rounded,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'اسم المستلم مطلوب'
                  : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'رقم الإيصال',
              hint: 'REC-XXX',
              controller: _receiptController,
              prefixIcon: Icons.receipt_long_rounded,
              textDirection: TextDirection.ltr,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'رقم الإيصال مطلوب'
                  : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            // Date picker
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedDate != null
                        ? AppColors.primary.withOpacity(0.4)
                        : AppColors.border,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      color: _selectedDate != null
                          ? AppColors.primary
                          : AppColors.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDate != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            : 'اختر تاريخ التحويل',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: _selectedDate != null
                              ? AppColors.textDark
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'ملاحظة (اختياري)',
              hint: 'أضف ملاحظة...',
              controller: _noteController,
              prefixIcon: Icons.notes_rounded,
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      crossFadeState: _showPreview
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      firstChild: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.summarize_rounded,
                      color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: 8),
                Text('ملخص التحويل',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    )),
              ],
            ),
            const SizedBox(height: 14),
            _PreviewRow(label: 'من', value: 'صندوق التطبيق'),
            _PreviewRow(label: 'إلى', value: 'صندوق الجمعية'),
            _PreviewRow(
                label: 'المبلغ',
                value: '\$${_amountController.text}',
                highlight: true),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(
                  color: AppColors.primary.withOpacity(0.15), height: 1),
            ),
            _PreviewRow(
              label: 'الرصيد المتبقي',
              value:
              '\$${(_appFundBalance - (double.tryParse(_amountController.text) ?? 0)).toStringAsFixed(2)}',
            ),
          ],
        ),
      ),
      secondChild: const SizedBox.shrink(),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════

class _FundChip extends StatelessWidget {
  const _FundChip(
      {required this.icon, required this.label, required this.sub});
  final IconData icon;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white.withOpacity(0.9), size: 18),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: GoogleFonts.cairo(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
        Text(sub,
            style: GoogleFonts.cairo(
                fontSize: 10, color: Colors.white.withOpacity(0.6)),
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _FormSectionTitle extends StatelessWidget {
  const _FormSectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF2ECC8B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow(
      {required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.cairo(
                  fontSize: 13, color: AppColors.textMuted)),
          Container(
            padding: highlight
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
                : EdgeInsets.zero,
            decoration: highlight
                ? BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            )
                : null,
            child: Text(value,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight:
                  highlight ? FontWeight.w800 : FontWeight.bold,
                  color: highlight ? AppColors.primary : AppColors.accent,
                )),
          ),
        ],
      ),
    );
  }
}