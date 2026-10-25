import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sacco.dart';
import '../providers/auth_provider.dart';
import '../providers/saved_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'app_shell.dart';
import 'sacco_profile_screen.dart';

/// The Saved tab. It reads the shared [SavedProvider], so a SACCO saved on
/// its Profile appears here straight away, with no manual refresh.
class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key, this.onBrowse});

  final VoidCallback? onBrowse;

  Future<void> _remove(BuildContext context, SaccoRecord sacco) async {
    try {
      await context.read<SavedProvider>().toggle(sacco);
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<AuthProvider>().isSignedIn;
    final saved = context.watch<SavedProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved SACCOs'),
        actions: [
          if (signedIn)
            IconButton(
              tooltip: 'Refresh saved SACCOs',
              onPressed: saved.load,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: Builder(builder: (context) {
        if (!signedIn) {
          return _SavedMessage(
            icon: Icons.lock_outline_rounded,
            title: 'Sign in to save SACCOs',
            message: 'You can search and compare without an account. '
                'Sign in to keep a shortlist of up to three SACCOs.',
            action: FilledButton.icon(
              onPressed: () => openAccount(context),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Sign in'),
            ),
          );
        }
        if (saved.loading && saved.saccos.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppColors.forest));
        }
        if (saved.error != null) {
          return _SavedMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Saved list unavailable',
            message: saved.error!,
            action: TextButton.icon(
              onPressed: saved.load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          );
        }
        if (saved.saccos.isEmpty) {
          return _SavedMessage(
            icon: Icons.bookmark_border_rounded,
            title: 'Your shortlist starts here',
            message: 'Open any SACCO and tap "Save SACCO" to keep it here. '
                'You can keep up to three.',
            action: onBrowse == null
                ? null
                : FilledButton.icon(
                    onPressed: onBrowse,
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Find a SACCO'),
                  ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Text(
                '${saved.saccos.length} OF 3 SAVED',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final sacco in saved.saccos)
              ListTile(
                leading: const Icon(Icons.account_balance_outlined, color: AppColors.forest),
                title: Text(sacco.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(sacco.county ?? 'County not listed'),
                trailing: IconButton(
                  tooltip: 'Remove ${sacco.name} from saved',
                  onPressed: () => _remove(context, sacco),
                  icon: const Icon(Icons.bookmark_remove_outlined),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SaccoProfileScreen(sacco: sacco),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _SavedMessage extends StatelessWidget {
  const _SavedMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
