import 'package:flutter/material.dart';

import '../models/sacco.dart';
import '../models/watchlist.dart';
import '../services/api_service.dart';
import 'sacco_profile_screen.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key, this.onBrowse});

  final VoidCallback? onBrowse;

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  late Future<List<MemberWatchlist>> _watchlists;

  @override
  void initState() {
    super.initState();
    _watchlists = ApiService.getWatchlists();
  }

  void _reload() {
    setState(() {
      _watchlists = ApiService.getWatchlists();
    });
  }

  Future<void> _remove(SaccoRecord sacco) async {
    try {
      await ApiService.setSaccoSaved(sacco, saved: false);
      if (mounted) _reload();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved SACCOs'),
        actions: [
          IconButton(
            tooltip: 'Refresh saved SACCOs',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<MemberWatchlist>>(
        future: _watchlists,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF126B5B)),
            );
          }
          if (snapshot.hasError) {
            return _SavedMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Saved list unavailable',
              message: snapshot.error.toString(),
              action: TextButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            );
          }
          final lists = snapshot.data ?? const <MemberWatchlist>[];
          final saccos = lists.expand((list) => list.saccos).toList();
          if (saccos.isEmpty) {
            return _SavedMessage(
              icon: Icons.bookmark_border_rounded,
              title: 'Your shortlist starts here',
              message: 'Save a SACCO from its profile. You can keep up to three.',
              action: widget.onBrowse == null
                  ? null
                  : FilledButton.icon(
                      onPressed: widget.onBrowse,
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Browse directory'),
                    ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Text(
                  '${saccos.length} OF 3 SAVED',
                  style: const TextStyle(
                    color: Color(0xFF638078),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              for (final sacco in saccos)
                ListTile(
                  leading: const Icon(
                    Icons.account_balance_outlined,
                    color: Color(0xFF126B5B),
                  ),
                  title: Text(sacco.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(sacco.county ?? 'County not listed'),
                  trailing: IconButton(
                    tooltip: 'Remove ${sacco.name} from saved',
                    onPressed: () => _remove(sacco),
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
        },
      ),
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
            Icon(icon, size: 38, color: const Color(0xFF638078)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF638078)),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}