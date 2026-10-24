// lib/features/admin/presentation/screens/admin_staff_screen.dart
//
// إدارة حسابات الموظفين (محاسب = قراءة فقط) — للأدمن فقط.
//   • قائمة الحسابات مع الدور والحالة
//   • إنشاء حساب جديد
//   • تعديل الاسم والدور، تعطيل/تفعيل، وإعادة تعيين كلمة المرور
//
// تنسيق فقط من admin_ui.dart — لا ألوان أو أنماط جديدة هنا.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:swida_go/core/auth/staff_role.dart';
import 'package:swida_go/features/admin/presentation/screens/widgets/admin_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';

class AdminStaffScreen extends StatefulWidget {
  const AdminStaffScreen({super.key});

  @override
  State<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends State<AdminStaffScreen> {
  final _repo = AdminRepository();

  List<StaffMember> _staff = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _repo.getStaff();
      if (mounted) setState(() => _staff = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openForm({StaffMember? member}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StaffFormSheet(
        member: member,
        onSubmit: (v) async {
          if (member == null) {
            await _repo.createStaff(
              fullName: v.fullName,
              email: v.email,
              phone: v.phone,
              password: v.password,
              role: v.role,
            );
          } else {
            await _repo.updateStaff(
              member.id,
              fullName: v.fullName,
              role: v.role,
              isActive: v.isActive,
              password: v.password.isEmpty ? null : v.password,
            );
          }
          if (!mounted) return;
          showAdminSnack(
            context,
            member == null ? 'تم إنشاء الحساب بنجاح' : 'تم تحديث الحساب بنجاح',
            error: false,
          );
          _load();
        },
      ),
    );
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
            title: 'إدارة الحسابات',
            subtitle: 'حسابات المحاسبين',
            onBack: () => context.go('/admin/dashboard'),
            trailing: _staff.isEmpty
                ? null
                : AdminHeaderBadge('${_staff.length} حساب'),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      // زر الإضافة في أسفل الشاشة: في متناول الإبهام
      bottomNavigationBar: ColoredBox(
        color: AdminTokens.bg,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: AdminButton(
              label: 'إضافة حساب',
              icon: Icons.person_add_alt_1_rounded,
              onPressed: () => _openForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final Widget content;

    if (_isLoading && _staff.isEmpty) {
      content = const _StaffSkeleton();
    } else if (_error != null && _staff.isEmpty) {
      content = SizedBox(
        height: 360,
        child: AdminEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'تعذر تحميل الحسابات',
          message: '$_error\nاسحب للأسفل لإعادة المحاولة',
        ),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _RolesLegend(),
          const SizedBox(height: 16),
          for (final m in _staff)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StaffCard(
                member: m,
                onTap: m.isAdmin ? null : () => _openForm(member: m),
              ),
            ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      backgroundColor: Colors.white,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [content],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ROLE STYLE
// ═══════════════════════════════════════════════════════════

Color _roleColor(String role) {
  switch (role) {
    case StaffRole.admin:
      return AdminTokens.purple;
    default:
      return AdminTokens.blue;
  }
}

IconData _roleIcon(String role) {
  switch (role) {
    case StaffRole.admin:
      return Icons.admin_panel_settings_rounded;
    default:
      return Icons.calculate_rounded;
  }
}

// ═══════════════════════════════════════════════════════════
// LEGEND
// ═══════════════════════════════════════════════════════════

class _RolesLegend extends StatelessWidget {
  const _RolesLegend();

  @override
  Widget build(BuildContext context) {
    Widget row(String role, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_roleIcon(role), size: 18, color: _roleColor(role)),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '${StaffRole.label(role)}: ',
                    style: AdminText.captionBold),
                TextSpan(text: text, style: AdminText.caption),
              ]),
            ),
          ),
        ],
      ),
    );

    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionTitle(title: 'صلاحيات الأدوار'),
          const SizedBox(height: 10),
          row(StaffRole.admin, 'كل شيء، بما فيه العمولة وإدارة الحسابات'),
          row(StaffRole.accountant, 'عرض اللوحة والتقارير فقط، بلا أي عملية مالية'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// STAFF CARD
// ═══════════════════════════════════════════════════════════

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.member, required this.onTap});

  final StaffMember member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(member.role);
    final initial =
    member.fullName.trim().isEmpty ? '؟' : member.fullName.trim()[0];

    return Opacity(
      opacity: member.isActive ? 1 : 0.6,
      child: AdminCard(
        onTap: onTap,
        splashColor: color,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Text(initial,
                  style: AdminText.title.copyWith(color: color, fontSize: 18)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.fullName,
                      style: AdminText.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(member.email,
                      style: AdminText.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      AdminPill(
                        label: StaffRole.label(member.role),
                        color: color,
                        icon: _roleIcon(member.role),
                      ),
                      if (!member.isActive)
                        const AdminPill(
                          label: 'معطّل',
                          color: AppColors.error,
                          icon: Icons.block_rounded,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.edit_rounded,
                  size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _StaffSkeleton extends StatelessWidget {
  const _StaffSkeleton();

  @override
  Widget build(BuildContext context) {
    return AdminPulse(
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: AdminCard(
                child: Row(
                  children: [
                    AdminSkeleton(width: 48, height: 48, radius: 24),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AdminSkeleton(width: 140, height: 16),
                          SizedBox(height: 8),
                          AdminSkeleton(width: 190, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// FORM SHEET  (إنشاء / تعديل)
// ═══════════════════════════════════════════════════════════

class _StaffValues {
  final String fullName;
  final String email;
  final String phone;
  final String password;
  final String role;
  final bool isActive;

  const _StaffValues({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
    required this.isActive,
  });
}

class _StaffFormSheet extends StatefulWidget {
  const _StaffFormSheet({required this.member, required this.onSubmit});

  /// null = إنشاء حساب جديد
  final StaffMember? member;
  final Future<void> Function(_StaffValues values) onSubmit;

  @override
  State<_StaffFormSheet> createState() => _StaffFormSheetState();
}

class _StaffFormSheetState extends State<_StaffFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  final _password = TextEditingController();

  // دور واحد فقط يُنشأ من هنا: المحاسب (قراءة فقط)
  static const String _role = StaffRole.accountant;
  late bool _active;
  bool _hidePassword = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.member != null;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _name = TextEditingController(text: m?.fullName ?? '');
    _email = TextEditingController(text: m?.email ?? '');
    _phone = TextEditingController(text: m?.phone ?? '');
    _active = m?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_StaffValues(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
        role: _role,
        isActive: _active,
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // الخطأ يظهر داخل النافذة نفسها (الـ SnackBar يختفي خلفها)
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    const roleHint = 'يرى اللوحة والتقارير فقط، بلا أي عملية مالية';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(AdminTokens.rXl)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + inset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(_isEdit ? 'تعديل الحساب' : 'حساب جديد',
                  style: AdminText.headline),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                style: AdminText.body,
                decoration: adminInputDecoration(
                    label: 'الاسم الكامل', prefixIcon: Icons.person_rounded),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
              ),
              const SizedBox(height: 12),
              if (_isEdit) ...[
                // البريد والهاتف لا يتغيران من هنا
                Text('${widget.member!.email}  ·  ${widget.member!.phone}',
                    style: AdminText.caption,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.start),
              ] else ...[
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.next,
                  style: AdminText.body,
                  decoration: adminInputDecoration(
                      label: 'البريد الإلكتروني',
                      prefixIcon: Icons.alternate_email_rounded),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'البريد مطلوب';
                    if (!t.contains('@') || !t.contains('.')) {
                      return 'صيغة البريد غير صحيحة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.next,
                  style: AdminText.body,
                  decoration: adminInputDecoration(
                      label: 'رقم الهاتف', prefixIcon: Icons.phone_rounded),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'الهاتف مطلوب';
                    if (t.length < 7) return 'رقم الهاتف قصير';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _hidePassword,
                textDirection: TextDirection.ltr,
                style: AdminText.body,
                decoration: adminInputDecoration(
                  label: _isEdit
                      ? 'كلمة مرور جديدة (اختياري)'
                      : 'كلمة المرور (8 أحرف على الأقل)',
                  prefixIcon: Icons.lock_rounded,
                  suffixIcon: IconButton(
                    tooltip: _hidePassword ? 'إظهار' : 'إخفاء',
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                  ),
                ),
                validator: (v) {
                  final t = v ?? '';
                  if (_isEdit && t.isEmpty) return null;
                  if (t.length < 8) return 'كلمة المرور 8 أحرف على الأقل';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('الدور: ${StaffRole.label(_role)}', style: AdminText.label),
              const SizedBox(height: 8),
              Text(roleHint, style: AdminText.caption),
              if (_isEdit) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  title: Text('الحساب مفعّل', style: AdminText.label),
                  subtitle: Text(
                    'عند التعطيل يُسجَّل خروجه فوراً ولا يستطيع الدخول',
                    style: AdminText.caption,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(AdminTokens.rSm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 18, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: AdminText.caption
                                .copyWith(color: AppColors.error)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              AdminButton(
                label: _isEdit ? 'حفظ التعديلات' : 'إنشاء الحساب',
                loading: _saving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
