import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PhoneHelper {
  /// Launches native phone dialer with pre-filled number.
  /// Does not place automatic background calls.
  static Future<bool> callNumber(BuildContext context, String rawPhoneNumber) async {
    final cleaned = rawPhoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number unavailable or invalid.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return false;
    }

    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      } else {
        // Fallback attempt to launch anyway as some Android versions return false for canLaunchUrl
        await launchUrl(uri);
        return true;
      }
    } catch (e) {
      debugPrint('[PHONE HELPER] Could not launch dialer for $cleaned: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open phone dialer for $rawPhoneNumber'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return false;
    }
  }

  /// Formats raw phone strings nicely for display
  static String formatDisplayNumber(String? phone) {
    if (phone == null || phone.trim().isEmpty) return 'Phone unavailable';
    final trimmed = phone.trim();
    return trimmed;
  }
}
