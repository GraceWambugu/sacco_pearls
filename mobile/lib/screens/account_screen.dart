import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../theme/app_colors.dart';

/// The signed-in member's details and the sign-out button.
class MemberAccountScreen extends StatelessWidget {
  const MemberAccountScreen({super.key, required this.account, required this.onLogout});

  final MemberAccount account;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.accentSoft,
            child: Text(
              account.fullName.isEmpty ? 'M' : account.fullName[0].toUpperCase(),
              style: const TextStyle(color: AppColors.highlight, fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            account.fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.ink, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(account.email, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 30),
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_user_outlined, color: AppColors.highlight),
              title: const Text('Member account'),
              subtitle: Text('Role: ${account.role}'),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
