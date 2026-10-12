// lib/features/subscriber/presentation/screens/payment_webview_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/constants/app_colors.dart';
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

  static const String _successUrlPattern = '/payment/success';
  static const String _cancelUrlPattern  = '/payment/cancel';

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
          onWebResourceError: (_) {
            // لا نفعل شيئاً — نتركه للـ onNavigationRequest
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

  Future<void> _handlePaymentSuccess(String url) async {
    if (_isVerifying || _isCancelled) return;
    if (mounted) setState(() => _isVerifying = true);

    // ✅ انتظر ثانيتين حتى يصل Webhook ويسجل الدفع
    await Future.delayed(const Duration(seconds: 2));

    try {
      final uri = Uri.tryParse(url);
      final sessionId = uri?.queryParameters['session_id'] ?? '';

      final verified = await _repo.verifyPayment(sessionId: sessionId);
      if (!mounted || _isCancelled) return;

      if (verified) {
        context.go('/confirmation', extra: widget.session);
      } else {
        // ✅ الدفع فشل أو لم يُسجَّل بعد
        _showError('لم يتم تأكيد الدفع. يرجى التحقق أو التواصل مع الدعم.');
        if (mounted) setState(() => _isVerifying = false);
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
        setState(() => _isVerifying = false);
      }
    }
  }

  void _handlePaymentCancel() {
    _isCancelled = true;
    if (mounted) context.go('/home');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.cairo()),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<bool> _onWillPop() async {
    if (_isVerifying) return false;

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
          appBar: AppBar(
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accent, AppColors.primary],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: GestureDetector(
              onTap: () async {
                final shouldPop = await _onWillPop();
                if (shouldPop && mounted) context.go('/home');
              },
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_forward_rounded, color: AppColors.white, size: 20),
              ),
            ),
            title: Column(
              children: [
                Text(
                  _isMockCheckout ? 'دفع تجريبي' : 'إتمام الدفع',  // ← label مختلف للـ Mock
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '\$${widget.session.totalAmount.toStringAsFixed(2)} — ${widget.session.months.length} ${widget.session.months.length == 1 ? "شهر" : "أشهر"}',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppColors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
            centerTitle: true,
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
                            'يرجى الانتظار لحظة',
                            style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textMuted),
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