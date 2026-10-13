import 'dart:async';

import 'package:flutter/material.dart';

import '../models/sacco.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'sacco_profile_screen.dart';

typedef SaccoSearchLoader = Future<List<SaccoRecord>> Function(String query);

class SaccoSearchScreen extends StatefulWidget {
  const SaccoSearchScreen({
    super.key,
    this.loader = ApiService.searchSaccos,
    this.accountName,
    this.onLogout,
  });

  final SaccoSearchLoader loader;
  final String? accountName;
  final VoidCallback? onLogout;

  @override
  State<SaccoSearchScreen> createState() => _SaccoSearchScreenState();
}

class _SaccoSearchScreenState extends State<SaccoSearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  late Future<List<SaccoRecord>> _results;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _results = widget.loader('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    setState(() => _query = value);
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _results = widget.loader(value.trim());
      });
    });
  }

  void _reload() {
    setState(() {
      _results = widget.loader(_query.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 24),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.charcoal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: AppColors.lime,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SACCOLens',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'PEARLS MONITOR',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh SACCOs',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  if (widget.onLogout != null)
                    IconButton(
                      tooltip: 'Sign out${widget.accountName == null ? '' : ' (${widget.accountName})'}',
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.logout_rounded),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Find a SACCO',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 18),
              child: Text(
                'Search the directory and explore financial health.',
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Name or SACCO',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.forest,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: FutureBuilder<List<SaccoRecord>>(
                future: _results,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.forest),
                    );
                  }
                  if (snapshot.hasError) {
                    return _SearchMessage(
                      icon: Icons.cloud_off_outlined,
                      title: 'Directory unavailable',
                      message: snapshot.error.toString(),
                      action: TextButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    );
                  }
                  final saccos = snapshot.data ?? const <SaccoRecord>[];
                  if (saccos.isEmpty) {
                    return _SearchMessage(
                      icon: Icons.search_off_rounded,
                      title: 'No SACCOs found',
                      message: 'Try another name or check your spelling.',
                    );
                  }
                  return ListView.separated(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: saccos.length + 1,
                    separatorBuilder: (context, index) => index == 0
                        ? const SizedBox(height: 4)
                        : const Divider(height: 1, indent: 84, endIndent: 20),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                          child: Row(
                            children: [
                              const Text(
                                'DIRECTORY',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${saccos.length} RESULTS',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final sacco = saccos[index - 1];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.limeSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.account_balance_outlined,
                            color: AppColors.forest,
                          ),
                        ),
                        title: Text(
                          sacco.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          sacco.county ?? 'County not listed',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: AppColors.muted,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SaccoProfileScreen(sacco: sacco),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
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
            Icon(icon, size: 36, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            if (action != null) ...[const SizedBox(height: 10), action!],
          ],
        ),
      ),
    );
  }
}