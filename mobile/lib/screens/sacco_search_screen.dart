import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sacco.dart';
import '../providers/compare_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'sacco_profile_screen.dart';

typedef SaccoSearchLoader = Future<List<SaccoRecord>> Function(
  String query, {
  String? county,
});

/// The Search tab: find a SACCO by name, optionally within one county,
/// open its Profile, or add it to Compare straight from the list.
class SaccoSearchScreen extends StatefulWidget {
  const SaccoSearchScreen({super.key, this.loader = ApiService.searchSaccos});

  /// Where results come from. Tests pass a fake loader instead of the real API.
  final SaccoSearchLoader loader;

  @override
  State<SaccoSearchScreen> createState() => _SaccoSearchScreenState();
}

class _SaccoSearchScreenState extends State<SaccoSearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  late Future<List<SaccoRecord>> _results;
  String _query = '';
  String? _county; // null means all counties
  List<String> _counties = const [];

  @override
  void initState() {
    super.initState();
    _results = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<SaccoRecord>> _load() async {
    final saccos = await widget.loader(_query.trim(), county: _county);
    // The first full list (no name, no county) tells us which counties exist.
    if (_counties.isEmpty && _query.trim().isEmpty && _county == null) {
      final counties =
          saccos.map((s) => s.county).whereType<String>().toSet().toList()
            ..sort();
      if (mounted) setState(() => _counties = counties);
    }
    return saccos;
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    setState(() => _query = value);
    // Wait until the user stops typing for 300 ms, so we do not call the API on every key.
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _results = _load();
      });
    });
  }

  void _selectCounty(String? county) {
    setState(() {
      _county = county;
      _results = _load();
    });
  }

  void _reload() {
    setState(() {
      _results = _load();
    });
  }

  void _toggleCompare(SaccoRecord sacco) {
    final picks = context.read<CompareProvider>();
    final String message;
    if (picks.contains(sacco.id)) {
      picks.remove(sacco.id);
      message = '${sacco.name} removed from compare';
    } else if (picks.add(sacco)) {
      message =
          '${sacco.name} added to compare (${picks.count} of ${CompareProvider.maxSaccos})';
    } else {
      message = 'Compare already has three SACCOs. Remove one first.';
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Find a SACCO',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh SACCOs',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Text(
                'Tap a SACCO to see its health score. Tap + to add it to Compare.',
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
                  hintText: 'Search by SACCO name',
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
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.forest,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            if (_counties.isNotEmpty)
              _CountyFilter(
                counties: _counties,
                selected: _county,
                onSelected: _selectCounty,
              ),
            const SizedBox(height: 6),
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
                    final error = snapshot.error;
                    final unreachable =
                        error is ApiException && error.isUnreachable;
                    return _SearchMessage(
                      icon: unreachable
                          ? Icons.wifi_off_rounded
                          : Icons.cloud_off_outlined,
                      title: unreachable
                          ? 'Could not reach the server'
                          : 'Search failed',
                      message: unreachable
                          ? 'Check your internet connection, then try again.'
                          : error.toString(),
                      action: FilledButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    );
                  }
                  final saccos = snapshot.data ?? const <SaccoRecord>[];
                  if (saccos.isEmpty) {
                    final where = _county == null ? '' : ' in $_county';
                    return _SearchMessage(
                      icon: Icons.search_off_rounded,
                      title: 'No SACCOs found',
                      message: _query.trim().isEmpty
                          ? 'No SACCOs are listed$where.'
                          : 'No SACCO names match "${_query.trim()}"$where. '
                                'Check the spelling or try a shorter word.',
                    );
                  }
                  return _ResultList(
                    saccos: saccos,
                    onToggleCompare: _toggleCompare,
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

class _CountyFilter extends StatelessWidget {
  const _CountyFilter({
    required this.counties,
    required this.selected,
    required this.onSelected,
  });

  final List<String> counties;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        children: [
          for (final county in <String?>[null, ...counties])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(county ?? 'All counties'),
                selected: selected == county,
                onSelected: (_) => onSelected(county),
                selectedColor: AppColors.accent,
                side: const BorderSide(color: AppColors.line),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({required this.saccos, required this.onToggleCompare});

  final List<SaccoRecord> saccos;
  final ValueChanged<SaccoRecord> onToggleCompare;

  @override
  Widget build(BuildContext context) {
    final picks = context.watch<CompareProvider>();
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: saccos.length + 1,
      separatorBuilder: (context, index) => index == 0
          ? const SizedBox.shrink()
          : const Divider(height: 1, indent: 84, endIndent: 20),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
            child: Text(
              '${saccos.length} ${saccos.length == 1 ? 'SACCO' : 'SACCOS'}',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }
        final sacco = saccos[index - 1];
        final picked = picks.contains(sacco.id);
        return ListTile(
          contentPadding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
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
            style: const TextStyle(color: AppColors.muted),
          ),
          // + adds to Compare and turns into a tick. Long-press does the same.
          trailing: IconButton(
            tooltip: picked
                ? 'Remove ${sacco.name} from compare'
                : 'Add ${sacco.name} to compare',
            onPressed: () => onToggleCompare(sacco),
            icon: Icon(
              picked
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              color: picked ? AppColors.forest : AppColors.muted,
              size: 28,
            ),
          ),
          onLongPress: () => onToggleCompare(sacco),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SaccoProfileScreen(sacco: sacco),
            ),
          ),
        );
      },
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
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}
