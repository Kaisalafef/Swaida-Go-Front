// lib/features/subscriber/presentation/screens/edit_profile_screen.dart
//
// تعديل الملف الشخصي:
//   1) الاسم والهاتف          → حفظ مباشر
//   2) البريد الإلكتروني      → يحتاج كلمة المرور + تأكيد برابط يصل للبريد الجديد
//   3) كلمة المرور            → تتطلب الحالية، وتُنهي الجلسات الأخرى

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_cards.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/models/subscriber_models.dart';
import '../../data/repositories/subscriber_repository.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static final RegExp _phoneRe = RegExp(r'^[0-9+\-\s()]{7,20}$');

  final _repo = SubscriberRepository();
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  UserProfile? _profile;
  bool _loading = true;
  String? _loadError;

  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _name.addListener(_refresh);
    _phone.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  // ── Load ────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final p = await _repo.getUserProfile();
      if (!mounted) return;
      _profile = p;
      _name.text = p.fullName;
      _phone.text = p.phone;
    } catch (e) {
      if (mounted) _loadError = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Dirty tracking (الحفظ يُفعَّل فقط عند وجود تغيير) ────
  bool get _nameChanged =>
      _profile != null && _name.text.trim() != _profile!.fullName;
  bool get _phoneChanged =>
      _profile != null && _phone.text.trim() != _profile!.phone;
  bool get _dirty => _nameChanged || _phoneChanged;

  // ── Save name / phone ───────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_dirty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await _repo.updateProfile(
        fullName: _nameChanged ? _name.text.trim() : null,
        phone: _phoneChanged ? _phone.text.trim() : null,
      );
      // نعيد القراءة ليتطابق ما نعرضه مع ما حفظه الخادم
      final p = await _repo.getUserProfile();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _name.text = p.fullName;
        _phone.text = p.phone;
      });
      _snack('تم حفظ بياناتك بنجاح');
    } catch (e) {
      if (mounted) setState(() => _saveError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text, style: GoogleFonts.cairo()),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  // ── Sheets ──────────────────────────────────────────────
  void _openPasswordSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PasswordSheet(
        onSubmit: (current, next) =>
            _repo.changePassword(currentPassword: current, newPassword: next),
        onDone: () => _snack('تم تغيير كلمة المرور. أُنهيت الجلسات على الأجهزة الأخرى.'),
      ),
    );
  }

  void _openEmailSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmailSheet(
        currentEmail: _profile?.email ?? '',
        onSubmit: (email, password) => _repo.requestEmailChange(
            newEmail: email, currentPassword: password),
        onDone: (email) async {
          await _load(); // يُظهر شريط «بانتظار التأكيد»
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (ctx) => Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: Text('تحقق من بريدك الجديد',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                content: Text(
                  'أرسلنا رابط التأكيد إلى:\n$email\n\n'
                      'اضغط الرابط خلال 60 دقيقة. بعد التأكيد يتغيّر بريد الدخول '
                      'وتُنهى جلساتك، فسجّل الدخول بالبريد الجديد.',
                  style: GoogleFonts.cairo(height: 1.6),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('حسناً',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: const IconThemeData(color: AppColors.accent),
          title: Text('تعديل الملف الشخصي',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.accent)),
          leading: IconButton(
            tooltip: 'رجوع',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () =>
            context.canPop() ? context.pop() : context.go('/profile'),
          ),
        ),
        body: _loading
            ? const Center(
            child: CircularProgressIndicator(color: AppColors.primary))
            : _loadError != null
            ? _buildLoadError()
            : _buildBody(),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_loadError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _load,
              child: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final p = _profile!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        // ── 1) الاسم والهاتف ───────────────────────────
        _card(
          title: 'البيانات الأساسية',
          icon: Icons.person_outline_rounded,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.cairo(fontSize: 15),
                  decoration: _dec('الاسم الكامل', Icons.badge_outlined),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'الاسم مطلوب';
                    if (t.length < 2) return 'الاسم قصير جداً';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  style: GoogleFonts.cairo(fontSize: 15),
                  decoration: _dec('رقم الهاتف', Icons.phone_outlined),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'رقم الهاتف مطلوب';
                    if (!_phoneRe.hasMatch(t)) return 'صيغة رقم الهاتف غير صحيحة';
                    return null;
                  },
                ),
                if (_saveError != null) ...[
                  const SizedBox(height: 12),
                  _notice(_saveError!, AppColors.error, AppColors.errorLight,
                      Icons.error_outline_rounded),
                ],
                const SizedBox(height: 16),
                AppButton(
                  label: 'حفظ التغييرات',
                  isLoading: _saving,
                  onPressed: _dirty && !_saving ? _save : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── 2) البريد الإلكتروني ───────────────────────
        _card(
          title: 'البريد الإلكتروني',
          icon: Icons.alternate_email_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(p.email,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.start,
                        style: GoogleFonts.cairo(
                            fontSize: 15, color: AppColors.textDark)),
                  ),
                  const Icon(Icons.verified_rounded,
                      size: 18, color: AppColors.success),
                ],
              ),
              if (p.pendingEmail != null) ...[
                const SizedBox(height: 12),
                _notice(
                  'بانتظار تأكيدك: ${p.pendingEmail}\n'
                      'اضغط الرابط الذي أرسلناه إلى هذا البريد. يمكنك طلب بريد آخر لاستبداله.',
                  AppColors.warningText,
                  AppColors.warningLight,
                  Icons.mark_email_unread_rounded,
                ),
              ],
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _openEmailSheet,
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text('تغيير البريد الإلكتروني',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                style: _outlined(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 3) كلمة المرور ─────────────────────────────
        _card(
          title: 'كلمة المرور',
          icon: Icons.lock_outline_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'عند تغييرها تُنهى جلساتك على الأجهزة الأخرى.',
                style: GoogleFonts.cairo(
                    fontSize: 12, color: AppColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openPasswordSheet,
                icon: const Icon(Icons.key_rounded, size: 18),
                label: Text('تغيير كلمة المرور',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                style: _outlined(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── UI helpers ──────────────────────────────────────────
  ButtonStyle _outlined() => OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    side: const BorderSide(color: AppColors.border),
    minimumSize: const Size.fromHeight(48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  Widget _card(
      {required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _notice(String text, Color fg, Color bg, IconData icon) =>
      AppNotice(text: text, fg: fg, bg: bg, icon: icon);
}

// ═══════════════════════════════════════════════════════════
// SHARED FIELD STYLE
// ═══════════════════════════════════════════════════════════

InputDecoration _dec(String label, IconData icon, {Widget? suffix}) {
  OutlineInputBorder border(Color c, [double w = 1.2]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.cairo(fontSize: 13, color: AppColors.textMuted),
    errorStyle: GoogleFonts.cairo(fontSize: 12),
    prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
    suffixIcon: suffix,
    filled: true,
    fillColor: AppColors.primarySoft,
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
    border: border(AppColors.border),
    enabledBorder: border(AppColors.border),
    focusedBorder: border(AppColors.primary, 2),
    errorBorder: border(AppColors.error),
    focusedErrorBorder: border(AppColors.error, 2),
  );
}

Widget _sheetShell({required BuildContext context, required List<Widget> children}) {
  final inset = MediaQuery.of(context).viewInsets.bottom;
  return Directionality(
    textDirection: TextDirection.rtl,
    child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + inset),
      child: SingleChildScrollView(
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
            ...children,
          ],
        ),
      ),
    ),
  );
}

Widget _sheetError(String text) => Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: AppColors.errorLight,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    children: [
      const Icon(Icons.error_outline_rounded,
          size: 18, color: AppColors.error),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text,
            style: GoogleFonts.cairo(fontSize: 12.5, color: AppColors.error)),
      ),
    ],
  ),
);

// ═══════════════════════════════════════════════════════════
// PASSWORD SHEET
// ═══════════════════════════════════════════════════════════

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet({required this.onSubmit, required this.onDone});

  final Future<void> Function(String current, String next) onSubmit;
  final VoidCallback onDone;

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _hideCurrent = true;
  bool _hideNext = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Widget _eye(bool hidden, VoidCallback onTap) => IconButton(
    tooltip: hidden ? 'إظهار' : 'إخفاء',
    icon: Icon(
        hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        size: 20,
        color: AppColors.textMuted),
    onPressed: onTap,
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_current.text, _next.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDone();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _sheetShell(
      context: context,
      children: [
        Text('تغيير كلمة المرور',
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.accent)),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _current,
                obscureText: _hideCurrent,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.next,
                style: GoogleFonts.cairo(fontSize: 15),
                decoration: _dec('كلمة المرور الحالية', Icons.lock_outline_rounded,
                    suffix: _eye(_hideCurrent,
                            () => setState(() => _hideCurrent = !_hideCurrent))),
                validator: (v) =>
                (v == null || v.isEmpty) ? 'كلمة المرور الحالية مطلوبة' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _next,
                obscureText: _hideNext,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.next,
                style: GoogleFonts.cairo(fontSize: 15),
                decoration: _dec('كلمة المرور الجديدة (8 أحرف على الأقل)',
                    Icons.key_rounded,
                    suffix: _eye(
                        _hideNext, () => setState(() => _hideNext = !_hideNext))),
                validator: (v) {
                  final t = v ?? '';
                  if (t.length < 8) return 'كلمة المرور 8 أحرف على الأقل';
                  if (t == _current.text) return 'يجب أن تختلف عن الحالية';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                obscureText: _hideNext,
                textDirection: TextDirection.ltr,
                style: GoogleFonts.cairo(fontSize: 15),
                decoration:
                _dec('تأكيد كلمة المرور الجديدة', Icons.key_rounded),
                validator: (v) =>
                v != _next.text ? 'كلمتا المرور غير متطابقتين' : null,
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _sheetError(_error!),
        ],
        const SizedBox(height: 20),
        AppButton(
          label: 'تغيير كلمة المرور',
          isLoading: _saving,
          onPressed: _saving ? null : _submit,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// EMAIL SHEET
// ═══════════════════════════════════════════════════════════

class _EmailSheet extends StatefulWidget {
  const _EmailSheet({
    required this.currentEmail,
    required this.onSubmit,
    required this.onDone,
  });

  final String currentEmail;
  final Future<String> Function(String email, String password) onSubmit;
  final Future<void> Function(String email) onDone;

  @override
  State<_EmailSheet> createState() => _EmailSheetState();
}

class _EmailSheetState extends State<_EmailSheet> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hide = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(email, _password.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onDone(email);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _sheetShell(
      context: context,
      children: [
        Text('تغيير البريد الإلكتروني',
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.accent)),
        const SizedBox(height: 6),
        Text(
          'سنرسل رابط تأكيد إلى البريد الجديد. لا يتغيّر بريد الدخول إلا بعد الضغط عليه.',
          style: GoogleFonts.cairo(
              fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.next,
                style: GoogleFonts.cairo(fontSize: 15),
                decoration:
                _dec('البريد الجديد', Icons.alternate_email_rounded),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'البريد مطلوب';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                    return 'صيغة البريد غير صحيحة';
                  }
                  if (t.toLowerCase() == widget.currentEmail.toLowerCase()) {
                    return 'هذا هو بريدك الحالي';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _hide,
                textDirection: TextDirection.ltr,
                style: GoogleFonts.cairo(fontSize: 15),
                decoration: _dec('كلمة المرور الحالية', Icons.lock_outline_rounded,
                    suffix: IconButton(
                      tooltip: _hide ? 'إظهار' : 'إخفاء',
                      icon: Icon(
                          _hide
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 20,
                          color: AppColors.textMuted),
                      onPressed: () => setState(() => _hide = !_hide),
                    )),
                validator: (v) =>
                (v == null || v.isEmpty) ? 'كلمة المرور مطلوبة للتأكيد' : null,
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _sheetError(_error!),
        ],
        const SizedBox(height: 20),
        AppButton(
          label: 'إرسال رابط التأكيد',
          isLoading: _saving,
          onPressed: _saving ? null : _submit,
        ),
      ],
    );
  }
}
