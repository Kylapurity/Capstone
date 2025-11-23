import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Terms and Conditions',
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Image.asset(
                'lib/assets/images/poultry_app_logo.png',
                width: 80,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'PoultrySight',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4CAF50),
                    ),
              ),
            ),
            const SizedBox(height: 32),

            // Introduction
            _buildSection(
              context,
              title: '1. Introduction',
              content:
                  'Welcome to PoultrySight ("we," "our," or "us"). These Terms and Conditions ("Terms") govern your use of the PoultrySight mobile application ("App"), which provides AI-powered egg production prediction, environmental monitoring, and farm management services for poultry farmers.',
            ),

            // Acceptance
            _buildSection(
              context,
              title: '2. Acceptance of Terms',
              content:
                  'By downloading, installing, accessing, or using the PoultrySight App, you agree to be bound by these Terms. If you do not agree to these Terms, please do not use the App. We reserve the right to modify these Terms at any time, and such modifications shall be effective immediately upon posting.',
            ),

            // Services
            _buildSection(
              context,
              title: '3. Description of Services',
              content:
                  'PoultrySight provides the following services:\n\n'
                  '• AI-Powered Predictions: Egg production forecasting using machine learning models based on environmental data (temperature, humidity, ammonia, light intensity, noise levels, and feeding amounts).\n\n'
                  '• Environmental Monitoring: Real-time and historical tracking of environmental conditions in poultry facilities.\n\n'
                  '• Audio Analysis: Noise level recording and analysis for stress detection in poultry.\n\n'
                  '• Data Storage: Cloud synchronization of your farm data via Supabase, with offline functionality using local storage.\n\n'
                  '• Profit Analytics: Financial tracking and profit calculations based on production predictions.',
            ),

            // User Account
            _buildSection(
              context,
              title: '4. User Accounts and Registration',
              content:
                  'To use certain features of the App, you must create an account. You agree to:\n\n'
                  '• Provide accurate, current, and complete information during registration.\n\n'
                  '• Maintain and update your account information to keep it accurate.\n\n'
                  '• Keep your account credentials secure and confidential.\n\n'
                  '• Notify us immediately of any unauthorized use of your account.\n\n'
                  '• Accept responsibility for all activities that occur under your account.',
            ),

            // Data Collection
            _buildSection(
              context,
              title: '5. Data Collection and Privacy',
              content:
                  'The App collects and processes the following types of data:\n\n'
                  '• Personal Information: Email address, username, chicken count, and profile information.\n\n'
                  '• Environmental Data: Temperature, humidity, ammonia levels, light intensity, and sensor readings.\n\n'
                  '• Production Data: Egg production predictions, historical production records, and farm performance metrics.\n\n'
                  '• Audio Data: Recordings for noise level analysis (processed locally and may be uploaded to cloud for analysis).\n\n'
                  '• Usage Data: App usage patterns, prediction history, and interaction data.\n\n'
                  'Your data is stored securely using Supabase cloud services and may be synchronized across devices when you are logged in. Please refer to our Privacy Policy for detailed information about how we handle your data.',
            ),

            // ML Predictions Disclaimer
            _buildSection(
              context,
              title: '6. Machine Learning Predictions Disclaimer',
              content:
                  'IMPORTANT: The egg production predictions provided by PoultrySight are generated using machine learning models trained on historical data. These predictions are estimates and should not be considered as guaranteed outcomes.\n\n'
                  '• Prediction Accuracy: While our models achieve high accuracy (R² >0.94), actual results may vary due to numerous factors including but not limited to: disease outbreaks, feed quality variations, genetic factors, seasonal changes, and unforeseen environmental events.\n\n'
                  '• No Guarantees: We make no warranties or guarantees regarding the accuracy, reliability, or suitability of any predictions for your specific farming operations.\n\n'
                  '• Professional Judgment: Always use your professional judgment and consult with veterinary or agricultural experts before making critical farm management decisions based on our predictions.\n\n'
                  '• Continuous Monitoring: Regularly validate predictions against actual production results and adjust your farm management practices accordingly.',
            ),

            // User Responsibilities
            _buildSection(
              context,
              title: '7. User Responsibilities',
              content:
                  'You are responsible for:\n\n'
                  '• Providing Accurate Data: Ensuring all environmental and farm data entered into the App is accurate and up-to-date.\n\n'
                  '• Maintaining Equipment: Properly maintaining and calibrating any sensors or equipment used to collect data for the App.\n\n'
                  '• Animal Welfare: Ensuring the health and welfare of your poultry in accordance with applicable animal welfare laws and regulations.\n\n'
                  '• Compliance: Complying with all applicable local, state, and federal laws and regulations related to poultry farming and data protection.\n\n'
                  '• Appropriate Use: Using the App only for lawful purposes and in accordance with these Terms.',
            ),

            // Intellectual Property
            _buildSection(
              context,
              title: '8. Intellectual Property Rights',
              content:
                  '• App Ownership: The App, including all content, features, functionality, machine learning models, and technology, is owned by PoultrySight or its licensors and is protected by copyright, trademark, and other intellectual property laws.\n\n'
                  '• Limited License: We grant you a limited, non-exclusive, non-transferable, revocable license to use the App for your personal or commercial farming purposes.\n\n'
                  '• Restrictions: You may not:\n'
                  '  - Copy, modify, or distribute the App\n'
                  '  - Reverse engineer or attempt to extract the source code\n'
                  '  - Remove any copyright or proprietary notices\n'
                  '  - Use the App for any illegal or unauthorized purpose\n\n'
                  '• User Data: You retain ownership of data you input into the App, and grant us a license to use such data to provide and improve our services.',
            ),

            // Service Availability
            _buildSection(
              context,
              title: '9. Service Availability and Modifications',
              content:
                  '• Availability: We strive to provide reliable service but do not guarantee uninterrupted, secure, or error-free operation. The App may be unavailable due to maintenance, updates, or technical issues.\n\n'
                  '• Offline Functionality: The App includes offline capabilities using TensorFlow Lite for predictions, but cloud synchronization and real-time features require internet connectivity.\n\n'
                  '• Modifications: We reserve the right to modify, suspend, or discontinue any part of the App at any time with or without notice.\n\n'
                  '• Updates: We may release updates to improve functionality, security, or compliance. Updates may require your acceptance of modified Terms.',
            ),

            // Third-Party Services
            _buildSection(
              context,
              title: '10. Third-Party Services',
              content:
                  'The App integrates with third-party services:\n\n'
                  '• Supabase: Used for authentication, cloud storage, and real-time data synchronization.\n\n'
                  '• Google Sign-In: Optional authentication method subject to Google\'s Terms of Service.\n\n'
                  '• TensorFlow Lite: Machine learning framework used for offline predictions.\n\n'
                  'Your use of third-party services is subject to their respective terms and conditions and privacy policies. We are not responsible for the practices or content of third-party services.',
            ),

            // Termination
            _buildSection(
              context,
              title: '11. Termination',
              content:
                  '• Your Rights: You may stop using the App and delete your account at any time.\n\n'
                  '• Our Rights: We may suspend or terminate your access to the App immediately, without prior notice, for:\n'
                  '  - Violation of these Terms\n'
                  '  - Fraudulent, harmful, or illegal activity\n'
                  '  - Extended periods of inactivity\n\n'
                  '• Effect of Termination: Upon termination, your right to use the App ceases immediately. We may delete your account and associated data, subject to our data retention policies and applicable law.',
            ),

            // Indemnification
            _buildSection(
              context,
              title: '12. Indemnification',
              content:
                  'You agree to indemnify, defend, and hold harmless PoultrySight, its affiliates, officers, directors, employees, and agents from and against any and all claims, damages, obligations, losses, liabilities, costs, or expenses (including attorney\'s fees) arising from:\n\n'
                  '• Your use of the App\n'
                  '• Your violation of these Terms\n'
                  '• Your violation of any third-party rights\n'
                  '• Farm management decisions made based on App predictions or recommendations',
            ),

            // Dispute Resolution
            _buildSection(
              context,
              title: '13. Dispute Resolution',
              content:
                  '• Governing Law: These Terms shall be governed by and construed in accordance with the laws of [Your Jurisdiction], without regard to its conflict of law provisions.\n\n'
                  '• Dispute Resolution: Any disputes arising out of or relating to these Terms or the App shall be resolved through binding arbitration in accordance with the rules of [Arbitration Organization], except where prohibited by law.\n\n'
                  '• Class Action Waiver: You agree that disputes will be resolved individually and waive any right to participate in class actions or consolidated proceedings.',
            ),

            // Acknowledgment
            _buildSection(
              context,
              title: '14. Acknowledgment',
              content:
                  'BY USING POULTRYSIGHT, YOU ACKNOWLEDGE THAT:\n\n'
                  '• You have read and understood these Terms and Conditions\n'
                  '• You agree to be bound by these Terms\n'
                  '• You understand that egg production predictions are estimates and not guarantees\n'
                  '• You will use professional judgment in farm management decisions\n'
                  '• You will use the App responsibly and in accordance with all applicable laws\n\n'
                  'If you do not agree with any part of these Terms, please discontinue use of the App immediately.',
            ),

            const SizedBox(height: 40),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Questions about our Terms?',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Contact us at: p.kihiu@alustudent.com',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Lexend',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: const TextStyle(
            fontFamily: 'Lexend',
            fontSize: 14,
            height: 1.6,
            color: Color(0xFF3A3A3A),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}