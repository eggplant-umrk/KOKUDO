import 'package:flutter/material.dart';

import '../data/privacy_policy_text.dart';
import '../theme/app_colors.dart';

/// プライバシーポリシーの表示画面。設定シートから開く。
/// 本文は [privacyPolicySections] (data/privacy_policy_text.dart) にある。
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSurface,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('プライバシーポリシー', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const Text(
              privacyPolicyTitle,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              privacyPolicyRevised,
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            for (final section in privacyPolicySections) ...[
              const SizedBox(height: 20),
              Text(
                section.heading,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              for (final paragraph in section.paragraphs) ...[
                const SizedBox(height: 8),
                SelectableText(
                  paragraph,
                  style: const TextStyle(fontSize: 13, height: 1.6, color: AppColors.textSecondary),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
