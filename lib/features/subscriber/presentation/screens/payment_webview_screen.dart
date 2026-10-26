// lib/features/subscriber/presentation/screens/payment_webview_screen.dart
//
// تغييرات هذه النسخة (الدفعة 1):
//   • خطأ تحميل صفحة الدفع → لوحة «تعذّر التحميل» مع إعادة المحاولة
//     (كان onWebResourceError فارغاً فتبقى صفحة بيضاء بلا مخرج).
//   • التحقق من الدفع: 4 محاولات متدرجة بدل محاولة واحدة بعد ثانيتين، وعند
//     الفشل لوحة تغطي الـ WebView فلا يعود المستخدم لإدخال بطاقته مرة ثانية،
//     مع «إعادة التحقق» و«العودة للرئيسية».

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/blue_app_bar.dart';
import '../../../../core/theme/brand_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/models/subscriber_models.dart';
import '../../data/repositories/subscriber_repository.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final PaymentSession session;

  const PaymentWebViewScreen({super.key, required this.session});

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  final _repo = SubscriberRepository();
  late WebViewController _webController;
  bool _isLoading = true;
  bool _isVerifying = false;
  bool _isCancelled = false;

  // ── حالات الفشل ───────────────────────────────────────────
  bool _loadFailed = false; // تعذّر تحميل صفحة الدفع نفسها
  bool _verifyFailed = false; // لم نستطع تأكيد الدفع بعد كل المحاولات
  String? _verifyError; // آخر رسالة خطأ شبكة (إن وُجدت)
  int _verifyAttempt = 0;
  String _pendingSessionId = '';

  static const String _successUrlPattern = '/payment/success';
  static const String _cancelUrlPattern  = '/payment/cancel';

  /// الانتظار قبل كل محاولة تحقق (يمنح الـ Webhook وقتاً ليسجّل الدفع).
  static const List<Duration> _verifyDelays = [
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 4),
    Duration(seconds: 5),
  ];

  // ── نكتشف إن كان الـ URL هو Mock (محلي) أم Paddle حقيقي ──
  bool get _isMockCheckout =>
      widget.session.checkoutUrl.contains('/api/payment/mock-success') ||
          widget.session.checkoutUrl.contains('mock-success');

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            // أخطاء الموارد الفرعية (صور/تتبّع) لا تعني فشل الصفحة.
            // (isForMainFrame يتطلب webview_flutter 4.2+؛ احذف السطر إن لم يُعرَّف.)
            if (error.isForMainFrame == false) return;
            if (mounted) {
              setState(() {
                _loadFailed = true;
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_isCancelled) return NavigationDecision.prevent;

            final url = request.url.toLowerCase();

            // ── منع فتح أي رابط Paddle خارجي في بيئة Mock ──
            // هذا يمنع ظهور نموذج إدخال بيانات البطاقة
            if (_isMockCheckout &&
                (url.contains('paddle.com') ||
                    url.contains('checkout.paddle') ||
                    url.contains('sandbox-checkout'))) {
              return NavigationDecision.prevent;
            }

            // ── Success ──────────────────────────────────────
            if (url.contains(_successUrlPattern) ||
                url.contains('payment_status=success')) {
              _handlePaymentSuccess(request.url);
              return NavigationDecision.prevent;
            }

            // ── Cancel ───────────────────────────────────────
            if (url.contains(_cancelUrlPattern) ||
                url.contains('payment_status=cancel')) {
              _handlePaymentCancel();
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.session.checkoutUrl));
  }

  void _retryLoad() {
    setState(() {
      _loadFailed = false;
      _isLoading = true;
    });
    _webController.loadRequest(Uri.parse(widget.session.checkoutUrl));
  }

  // ── التحقق من الدفع ───────────────────────────────────────
  Future<void> _handlePaymentSuccess(String url) async {
    if (_isVerifying || _isCancelled) return;
    _pendingSessionId = Uri.tryParse(url)?.queryParameters['session_id'] ?? '';
    await _verifyWithRetries();
  }

  /// يحاول التحقق عدة مرات (الـ Webhook قد يتأخر). عند النجاح → /confirmation،
  /// وعند استنفاد المحاولات تظهر لوحة الفشل بدل إعادة المستخدم لصفحة الدفع.
  Future<void> _verifyWithRetries() async {
    if (!mounted) return;
    setState(() {
      _isVerifying = true;
      _verifyFailed = false;
      _verifyError = null;
      _verifyAttempt = 0;
    });

    Object? lastError;
    for (var i = 0; i < _verifyDelays.length; i++) {
      await Future<void>.delayed(_verifyDelays[i]);
      if (!mounted || _isCancelled) return;
      setState(() => _verifyAttempt = i + 1);

      try {
        final verified =
        await _repo.verifyPayment(sessionId: _pendingSessionId);
        if (!mounted || _isCancelled) return;
        if (verified) {
          context.go('/confirmation', extra: widget.session);
          return;
        }
        lastError = null;
      } catch (e) {
        lastError = e;
      }
    }

    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _verifyFailed = true;
      _verifyError = lastError?.toString();
    });
  }

  void _handlePaymentCancel() {
    _isCancelled = true;
    if (mounted) context.go('/home');
  }

  void _goHome() {
    _isCancelled = true;
    if (mounted) context.go('/home');
  }

  Future<bool> _onWillPop() async {
    if (_isVerifying) return false;

    // لوحات الفشل: لا حاجة لتأكيد، الرجوع يعني العودة للرئيسية.
    if (_verifyFailed || _loadFailed) {
      _isCancelled = true;
      return true;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'إلغاء الدفع',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.accent),
          ),
          content: Text(
            'هل تريد إلغاء عملية الدفع والعودة؟',
            style: GoogleFonts.cairo(color: AppColors.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('لا، أكمل',
                  style: GoogleFonts.cairo(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('نعم، إلغاء',
                  style: GoogleFonts.cairo(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      _isCancelled = true;
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) context.go('/home');
        return false;
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: BlueAppBar(
            title: _isMockCheckout ? 'دفع تجريبي' : 'إتمام الدفع',
            subtitle:
            '${Fmt.money2(widget.session.totalAmount)} — ${Fmt.months(widget.session.months.length)}',
            onBack: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) context.go('/home');
            },
          ),
          body: Stack(
            children: [
              WebViewWidget(controller: _webController),

              if (_isLoading)
                const LinearProgressIndicator(
                  backgroundColor: AppColors.primarySoft,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),

              if (_isVerifying)
                Container(
                  color: Colors.black.withOpacity(0.4),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: AppColors.primary),
                          const SizedBox(height: 16),
                          Text(
                            'جارٍ التحقق من الدفعة...',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _verifyAttempt > 1
                                ? 'المحاولة $_verifyAttempt من ${_verifyDelays.length}'
                                : 'يرجى الانتظار لحظة',
                            style: GoogleFonts.cairo(fontSize: 13, color: Brand.bodyOnLight),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── شارة "بيئة تجريبية" فوق الـ WebView في Mock Mode ──
              if (_isMockCheckout && !_isVerifying)
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '⚠️ بيئة تطوير محلية',
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

              // ── تعذّر تحميل صفحة الدفع ──────────────────────
              if (_loadFailed && !_isVerifying && !_verifyFailed)
                Positioned.fill(
                  child: _StatusPanel(
                    icon: Icons.wifi_off_rounded,
                    color: AppColors.error,
                    soft: AppColors.errorLight,
                    title: 'تعذّر تحميل صفحة الدفع',
                    message:
                    'تحقق من اتصالك بالإنترنت ثم أعد المحاولة. لم يُخصم أي مبلغ.',
                    primaryLabel: 'إعادة المحاولة',
                    onPrimary: _retryLoad,
                    secondaryLabel: 'العودة للرئيسية',
                    onSecondary: _goHome,
                  ),
                ),

              // ── لم نستطع تأكيد الدفع (تغطي الـ WebView كلياً) ──
              if (_verifyFailed && !_isVerifying)
                Positioned.fill(
                  child: _StatusPanel(
                    icon: Icons.schedule_rounded,
                    color: AppColors.primary,
                    soft: AppColors.primarySoft,
                    title: 'لم نتمكّن من تأكيد الدفع بعد',
                    message:
                    'إن كان المبلغ قد خُصم من بطاقتك فلا تُعد الدفع: سيظهر في اشتراكك تلقائياً خلال دقائق. '
                        'يمكنك إعادة التحقق الآن أو العودة للرئيسية.'
                        '${_verifyError != null ? '\n\n$_verifyError' : ''}',
                    primaryLabel: 'إعادة التحقق',
                    onPrimary: _verifyWithRetries,
                    secondaryLabel: 'العودة للرئيسية',
                    onSecondary: _goHome,
                  ),
                ),
            ],
          ),
          bottomNavigationBar: Container(
            height: 44,
            color: AppColors.secondary,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isMockCheckout ? Icons.science_rounded : Icons.lock_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  _isMockCheckout
                      ? 'وضع الاختبار — لا تُدخل بيانات حقيقية'
                      : 'اتصال آمن ومشفر — بيانات بطاقتك محمية',
                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  لوحة حالة بملء الشاشة (خطأ تحميل / فشل تأكيد)
// ─────────────────────────────────────────────────────────
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.color,
    required this.soft,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final IconData icon;
  final Color color;
  final Color soft;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.secondary,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 36),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 13.5,
                    height: 1.7,
                    color: Brand.bodyOnLight,
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(label: primaryLabel, onPressed: onPrimary),
                const SizedBox(height: 12),
                AppButton(
                  label: secondaryLabel,
                  onPressed: onSecondary,
                  outlined: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
