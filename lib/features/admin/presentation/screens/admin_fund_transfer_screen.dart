// lib/features/admin/presentation/screens/admin_fund_transfer_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:swida_go/features/admin/presentation/screens/widgets/admin_ui.dart';

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
      showAdminSnack(context, 'يرجى اختيار تاريخ التحويل');
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
      await showAdminSuccessDialog(
        context,
        title: 'تم التحويل بنجاح',
        message: 'تم تحويل \$$amount\nإلى صندوق الجمعية',
        buttonLabel: 'العودة للوحة الإدارة',
        onConfirm: () {
          if (mounted) context.go('/admin/dashboard');
        },
      );
    } catch (e) {
      if (mounted) showAdminSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTokens.bg,
      body: Column(
        children: [
          AdminHeaderBar(
            title: 'تحويل الصناديق',
            subtitle: 'من صندوق التطبيق إلى الجمعية',
            onBack: () => context.go('/admin/dashboard'),
          ),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                  16, 20, 16, 32 + MediaQuery.of(context).padding.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 16),
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
                      const Icon(Icons.lock_outline_rounded,
                          color: AppColors.textMuted, size: 14),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'هذه العملية لا يمكن التراجع عنها بعد التأكيد',
                          style: AdminText.caption,
                          textAlign: TextAlign.center,
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

  // ── Balance ──────────────────────────────────────────────
  Widget _buildBalanceCard() {
    return AdminHeroCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الرصيد المتاح', style: AdminText.onBrandCaption),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AdminTokens.onBrand15,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AdminTokens.onBrand10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AdminLiveDot(),
                    const SizedBox(width: 6),
                    Text('صندوق التطبيق',
                        style: AdminText.captionBold
                            .copyWith(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _isLoadingBalance
              ? const AdminPulse(
            child: AdminSkeleton(
              width: 170,
              height: 44,
              radius: 12,
              color: AdminTokens.onBrand20,
            ),
          )
              : FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              AdminFmt.money(_appFundBalance, decimals: 2),
              style: AdminText.heroNumber,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AdminTokens.onBrand10,
              borderRadius: BorderRadius.circular(AdminTokens.rMd),
              border: Border.all(color: AdminTokens.onBrand10),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: _FundChip(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'صندوق التطبيق',
                    sub: 'المصدر',
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AdminTokens.onBrand15,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward,
                      color: Colors.white, size: 16),
                ),
                const Expanded(
                  child: _FundChip(
                    icon: Icons.volunteer_activism_rounded,
                    label: 'صندوق الفريق التطوعي',
                    sub: 'الوجهة',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Form ─────────────────────────────────────────────────
  Widget _buildFormCard() {
    return AdminCard(
      radius: AdminTokens.rXl,
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AdminSectionTitle(
              title: 'تفاصيل التحويل',
              icon: Icons.edit_note_rounded,
            ),
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
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            _buildDateField(),
            const SizedBox(height: 16),
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

  Widget _buildDateField() {
    final d = _selectedDate;
    final has = d != null;
    final dateText = d != null ? '${d.day}/${d.month}/${d.year}' : null;

    return Semantics(
      button: true,
      label: 'تاريخ التحويل',
      value: dateText ?? 'غير محدد',
      child: Material(
        color: AppColors.primarySoft,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminTokens.rField),
          side: BorderSide(
            color: has ? AppColors.primary.withOpacity(0.45) : AppColors.border,
            width: 1.2,
          ),
        ),
        child: InkWell(
          onTap: _pickDate,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 22,
                  color: has ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تاريخ التحويل', style: AdminText.caption),
                      Text(
                        dateText ?? 'اختر التاريخ',
                        style: has ? AdminText.label : AdminText.bodyMuted,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textMuted, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Live preview ─────────────────────────────────────────
  Widget _buildPreview() {
    final entered = double.tryParse(_amountController.text) ?? 0;
    final remaining = _appFundBalance - entered;

    return AnimatedCrossFade(
      duration: AdminTokens.base,
      sizeCurve: AdminTokens.curve,
      crossFadeState:
      _showPreview ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AdminTokens.rLg),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.summarize_rounded,
                      color: AppColors.primary, size: 17),
                ),
                const SizedBox(width: 10),
                Text('ملخص التحويل',
                    style: AdminText.label.copyWith(color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 14),
            const _PreviewRow(label: 'من', value: 'صندوق التطبيق'),
            const _PreviewRow(label: 'إلى', value: 'صندوق الجمعية'),
            _PreviewRow(
              label: 'المبلغ',
              value: '\$${_amountController.text}',
              highlight: true,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                  color: AppColors.primary.withOpacity(0.15), height: 1),
            ),
            _PreviewRow(
              label: 'الرصيد المتبقي',
              value: '\$${remaining.toStringAsFixed(2)}',
              danger: remaining < 0,
            ),
          ],
        ),
      ),
      secondChild: const SizedBox(width: double.infinity),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AdminTokens.onBrand15,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AdminText.captionBold.copyWith(color: Colors.white),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text(sub,
            style: AdminText.caption.copyWith(color: AdminTokens.onBrand85),
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.danger = false,
  });
  final String label;
  final String value;
  final bool highlight;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final valueColor = danger
        ? AppColors.error
        : (highlight ? AppColors.primary : AppColors.accent);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AdminText.bodyMuted),
          Flexible(
            child: Container(
              padding: highlight
                  ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
                  : EdgeInsets.zero,
              decoration: highlight
                  ? BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              )
                  : null,
              child: Text(
                value,
                style: AdminText.label.copyWith(
                  color: valueColor,
                  fontWeight: highlight ? FontWeight.w800 : FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}