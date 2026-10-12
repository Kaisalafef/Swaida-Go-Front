// دالة لفتح سياسة الخصوصية
import 'package:url_launcher/url_launcher.dart';

Future<void> launchPrivacyPolicy() async {
  final Uri url = Uri.parse('https://doc-hosting.flycricket.io/close-friend-privacy-policy/52431ca9-60ea-4933-861a-115bf788820d/privacy');
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    throw Exception('Could not launch $url');
  }
}

// دالة لفتح شروط الاستخدام
Future<void> launchTermsOfUse() async {
  final Uri url = Uri.parse('https://doc-hosting.flycricket.io/close-friend-terms-of-use/d6daff33-8d9a-4bb3-acea-71eb518f0bad/terms'); // ضع رابط الشروط هنا
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    throw Exception('Could not launch $url');
  }
}