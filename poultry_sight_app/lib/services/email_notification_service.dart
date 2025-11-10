import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Service for sending email notifications via Supabase Edge Functions + Resend API
class EmailNotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // TEST MODE - Set to false once you verify a domain with Resend
  // While true, all emails go to the test email below
  static const bool _isTestMode = true;
  static const String _testRecipient = 'p.kihiu@alustudent.com';

  static const bool _emailNotificationsEnabled = true;

  /// Send environmental alert to current logged-in user
  Future<void> sendEnvironmentalAlert({
    required String alertType,
    required double currentValue,
    required double thresholdValue,
    required String severity,
  }) async {
    if (!_emailNotificationsEnabled) {
      debugPrint('ℹ️ Email notifications disabled');
      return;
    }

    try {
      // Get the logged-in user's email automatically
      final user = _supabase.auth.currentUser;
      if (user?.email == null) {
        debugPrint('⚠️ No user logged in or email not found');
        return;
      }

      debugPrint('📧 Sending alert to logged-in user: ${user!.email}');

      await _sendEmailViaEdgeFunction(
        to: user!.email!,
        subject: _getEmailSubject(alertType, severity),
        message: _buildAlertMessage(
          alertType: alertType,
          currentValue: currentValue,
          thresholdValue: thresholdValue,
          severity: severity,
        ),
        alertType: alertType,
        severity: severity,
      );

      debugPrint('✅ Email notification sent to ${user!.email}');
    } catch (e) {
      debugPrint('❌ Error sending email notification: $e');
    }
  }

  /// Send environmental alert to ALL registered users
  Future<void> sendEnvironmentalAlertToAllUsers({
    required String alertType,
    required double currentValue,
    required double thresholdValue,
    required String severity,
  }) async {
    if (!_emailNotificationsEnabled) {
      debugPrint('ℹ️ Email notifications disabled');
      return;
    }

    try {
      final emails = await _getAllUserEmails();

      if (emails.isEmpty) {
        debugPrint('⚠️ No user emails found');
        return;
      }

      final subject = _getEmailSubject(alertType, severity);
      final message = _buildAlertMessage(
        alertType: alertType,
        currentValue: currentValue,
        thresholdValue: thresholdValue,
        severity: severity,
      );

      debugPrint('📧 Sending alerts to ${emails.length} users');

      // Send to all users
      int successCount = 0;
      for (final email in emails) {
        try {
          await _sendEmailViaEdgeFunction(
            to: email,
            subject: subject,
            message: message,
            alertType: alertType,
            severity: severity,
          );
          successCount++;
        } catch (e) {
          debugPrint('⚠️ Failed to send email to $email: $e');
        }
      }

      debugPrint('✅ Successfully sent $successCount/${emails.length} emails');
    } catch (e) {
      debugPrint('❌ Error sending bulk email notification: $e');
    }
  }

  /// Send environmental alert to specific users
  Future<void> sendEnvironmentalAlertToUsers({
    required List<String> userEmails,
    required String alertType,
    required double currentValue,
    required double thresholdValue,
    required String severity,
  }) async {
    if (!_emailNotificationsEnabled) {
      debugPrint('ℹ️ Email notifications disabled');
      return;
    }

    try {
      final subject = _getEmailSubject(alertType, severity);
      final message = _buildAlertMessage(
        alertType: alertType,
        currentValue: currentValue,
        thresholdValue: thresholdValue,
        severity: severity,
      );

      int successCount = 0;
      for (final email in userEmails) {
        try {
          await _sendEmailViaEdgeFunction(
            to: email,
            subject: subject,
            message: message,
            alertType: alertType,
            severity: severity,
          );
          successCount++;
        } catch (e) {
          debugPrint('⚠️ Failed to send email to $email: $e');
        }
      }

      debugPrint(
        '✅ Successfully sent $successCount/${userEmails.length} emails',
      );
    } catch (e) {
      debugPrint('❌ Error sending email notification: $e');
    }
  }

  /// Send email via Supabase Edge Function
  Future<void> _sendEmailViaEdgeFunction({
    required String to,
    required String subject,
    required String message,
    required String alertType,
    required String severity,
  }) async {
    try {
      // In test mode, override recipient to avoid domain verification issues
      final actualRecipient = _isTestMode ? _testRecipient : to;
      final actualSubject = _isTestMode ? '[TEST] $subject' : subject;
      final actualMessage = _isTestMode
          ? '=== TEST MODE ===\nOriginal Recipient: $to\n\n$message'
          : message;

      if (_isTestMode) {
        debugPrint('🧪 TEST MODE: Redirecting email');
        debugPrint('   From: $to → To: $actualRecipient');
      }

      final response = await _supabase.functions
          .invoke(
            'send-email-notification',
            body: {
              'to': actualRecipient,
              'subject': actualSubject,
              'message': actualMessage,
              'alertType': alertType,
              'severity': severity,
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Email request timed out');
            },
          );

      if (response.status == 200) {
        debugPrint('✅ Email sent successfully');
        if (_isTestMode) {
          debugPrint('   📬 Check inbox: $actualRecipient');
        } else {
          debugPrint('   📬 Sent to: $to');
        }
      } else {
        debugPrint('⚠️ Email failed with status: ${response.status}');
        debugPrint('   Response: ${response.data}');
        throw Exception('Email send failed: ${response.status}');
      }
    } catch (e) {
      debugPrint('❌ Error calling edge function: $e');
      rethrow;
    }
  }

  /// Get all user emails from Supabase database
  Future<List<String>> _getAllUserEmails() async {
    try {
      // Try to get from users table
      final response = await _supabase
          .from('users')
          .select('email')
          .not('email', 'is', null);

      if (response is List && response.isNotEmpty) {
        final emails = response
            .map((user) => user['email'] as String)
            .where((email) => email.isNotEmpty)
            .toList();

        debugPrint('📋 Found ${emails.length} user emails in database');
        return emails;
      }

      // Fallback to current user only
      final user = _supabase.auth.currentUser;
      if (user?.email != null) {
        debugPrint('ℹ️ No users table found, using current user only');
        return [user!.email!];
      }

      return [];
    } catch (e) {
      debugPrint('❌ Error fetching user emails: $e');

      // Fallback to current user
      final user = _supabase.auth.currentUser;
      if (user?.email != null) {
        return [user!.email!];
      }

      return [];
    }
  }

  String _getEmailSubject(String alertType, String severity) {
    final severityEmoji = severity == 'critical' ? '🚨' : '⚠️';
    final typeMap = {
      'temperature': 'Temperature',
      'humidity': 'Humidity',
      'ammonia': 'Ammonia',
      'light': 'Light Intensity',
    };

    return '$severityEmoji PoultrySight Alert: ${typeMap[alertType]} Issue Detected';
  }

  String _buildAlertMessage({
    required String alertType,
    required double currentValue,
    required double thresholdValue,
    required String severity,
  }) {
    final typeMap = {
      'temperature': 'Temperature',
      'humidity': 'Humidity',
      'ammonia': 'Ammonia',
      'light': 'Light Intensity',
    };

    final unitMap = {
      'temperature': '°C',
      'humidity': '%',
      'ammonia': 'ppm',
      'light': 'lux',
    };

    final actionMap = {
      'temperature': _getTemperatureAction(severity),
      'humidity': _getHumidityAction(severity),
      'ammonia': _getAmmoniaAction(),
      'light': _getLightAction(),
    };

    return '''
🚨 ENVIRONMENTAL ALERT FROM POULTRYSIGHT

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Alert Type: ${typeMap[alertType]}
Current Value: $currentValue ${unitMap[alertType]}
Threshold: $thresholdValue ${unitMap[alertType]}
Severity Level: ${severity.toUpperCase()}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RECOMMENDED ACTIONS:
${actionMap[alertType]}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⏰ Alert Time: ${DateTime.now().toString().split('.')[0]}

This is an automated alert from your poultry farm monitoring system.
Please check your farm conditions immediately.

Need help? Contact support or check your dashboard for detailed metrics.
    ''';
  }

  String _getTemperatureAction(String severity) {
    if (severity == 'high') {
      return '''
• Turn on ventilation fans immediately
• Open windows and doors for airflow
• Check cooling systems functionality
• Monitor chicken behavior for heat stress
• Ensure water supply is adequate''';
    } else {
      return '''
• Turn on heating system
• Close windows to retain heat
• Check insulation for gaps
• Monitor chicken behavior for cold stress
• Ensure chickens have warm bedding''';
    }
  }

  String _getHumidityAction(String severity) {
    if (severity == 'high') {
      return '''
• Increase ventilation immediately
• Remove wet bedding materials
• Check for water leaks
• Consider using a dehumidifier
• Inspect roof for leaks''';
    } else {
      return '''
• Add moisture to environment
• Use humidifier if available
• Check ventilation settings
• Ensure water sources are functioning
• Monitor chicken respiratory health''';
    }
  }

  String _getAmmoniaAction() {
    return '''
• IMMEDIATELY increase ventilation
• Replace all soiled bedding NOW
• Check for drainage issues or leaks
• Add fresh air circulation
• Monitor chicken health closely
• Consider temporary relocation if critical
• Clean coop thoroughly''';
  }

  String _getLightAction() {
    return '''
• Increase artificial lighting
• Provide 14-16 hours of light daily
• Check and replace faulty light bulbs
• Ensure adequate brightness (300-600 lux)
• Maintain consistent lighting schedule
• Consider timer for automation''';
  }

  /// Send prediction alert to all users
  Future<void> sendPredictionAlertToAllUsers({
    required int predictedEggs,
    required String quality,
    required double chickenCount,
  }) async {
    if (!_emailNotificationsEnabled) {
      debugPrint('ℹ️ Email notifications disabled');
      return;
    }

    try {
      final emails = await _getAllUserEmails();

      if (emails.isEmpty) {
        debugPrint('⚠️ No user emails found');
        return;
      }

      final subject = '🥚 PoultrySight: Daily Egg Production Prediction';
      final message = _buildPredictionMessage(
        predictedEggs: predictedEggs,
        quality: quality,
        chickenCount: chickenCount,
      );

      int successCount = 0;
      for (final email in emails) {
        try {
          await _sendEmailViaEdgeFunction(
            to: email,
            subject: subject,
            message: message,
            alertType: 'prediction',
            severity: quality.toLowerCase(),
          );
          successCount++;
        } catch (e) {
          debugPrint('⚠️ Failed to send prediction email to $email: $e');
        }
      }

      debugPrint('✅ Prediction sent to $successCount/${emails.length} users');
    } catch (e) {
      debugPrint('❌ Error sending prediction notification: $e');
    }
  }

  /// Send prediction alert to current logged-in user only
  Future<void> sendPredictionAlert({
    required int predictedEggs,
    required String quality,
    required double chickenCount,
  }) async {
    if (!_emailNotificationsEnabled) {
      debugPrint('ℹ️ Email notifications disabled');
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user?.email == null) {
        debugPrint('⚠️ No user logged in');
        return;
      }

      await _sendEmailViaEdgeFunction(
        to: user!.email!,
        subject: '🥚 PoultrySight: Daily Egg Production Prediction',
        message: _buildPredictionMessage(
          predictedEggs: predictedEggs,
          quality: quality,
          chickenCount: chickenCount,
        ),
        alertType: 'prediction',
        severity: quality.toLowerCase(),
      );

      debugPrint('✅ Prediction notification sent to ${user!.email}');
    } catch (e) {
      debugPrint('❌ Error sending prediction notification: $e');
    }
  }

  String _buildPredictionMessage({
    required int predictedEggs,
    required String quality,
    required double chickenCount,
  }) {
    final qualityEmoji = quality == 'Excellent'
        ? '🌟'
        : quality == 'Good'
        ? '✅'
        : quality == 'Fair'
        ? '⚠️'
        : '❌';

    return '''
🥚 POULTRYSIGHT EGG PRODUCTION PREDICTION

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Today's Prediction: $predictedEggs eggs
Prediction Quality: $qualityEmoji $quality
Flock Size: ${chickenCount.toInt()} chickens
Prediction Date: ${DateTime.now().toString().split(' ')[0]}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This prediction is based on current environmental conditions:
• Temperature
• Humidity levels
• Ammonia concentration
• Light intensity

For optimal egg production, maintain environmental conditions 
within recommended ranges.

View detailed reports and real-time metrics in your dashboard.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

© 2025 PoultrySight - Smart Poultry Farm Management
    ''';
  }

  /// Send test email to verify configuration
  Future<bool> sendTestEmail({String? recipientEmail}) async {
    try {
      final email = recipientEmail ?? _supabase.auth.currentUser?.email;

      if (email == null) {
        debugPrint('⚠️ No user logged in or email provided');
        return false;
      }

      debugPrint('📧 Sending test email to: $email');

      await _sendEmailViaEdgeFunction(
        to: email,
        subject: '✅ PoultrySight Email Test',
        message:
            '''
Hello from PoultrySight!

This is a test email to verify that email notifications are working correctly.

Your account email: $email
Test time: ${DateTime.now()}

If you received this email, your notification system is configured properly.

Best regards,
PoultrySight Team
        ''',
        alertType: 'test',
        severity: 'info',
      );

      return true;
    } catch (e) {
      debugPrint('❌ Test email failed: $e');
      return false;
    }
  }

  /// Send test email to all registered users
  Future<bool> sendTestEmailToAllUsers() async {
    try {
      final emails = await _getAllUserEmails();

      if (emails.isEmpty) {
        debugPrint('⚠️ No user emails found');
        return false;
      }

      final subject = '✅ PoultrySight System Test';
      final message =
          '''
Hello from PoultrySight!

This is a system-wide test email to all registered users.

If you received this email, the bulk notification system is working correctly.

Time sent: ${DateTime.now()}
Total recipients: ${emails.length}

Best regards,
PoultrySight Team
        ''';

      int successCount = 0;
      for (final email in emails) {
        try {
          await _sendEmailViaEdgeFunction(
            to: email,
            subject: subject,
            message: message,
            alertType: 'test',
            severity: 'info',
          );
          successCount++;
        } catch (e) {
          debugPrint('⚠️ Failed to send test email to $email: $e');
        }
      }

      debugPrint('✅ Sent test email to $successCount/${emails.length} users');
      return successCount > 0;
    } catch (e) {
      debugPrint('❌ Bulk test email failed: $e');
      return false;
    }
  }
}
