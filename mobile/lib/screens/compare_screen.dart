import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sacco.dart';
import '../providers/compare_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key, this.onBrowse});

  /// Opens the Search tab (used by the empty-state button).
  final VoidCallback? onBrowse;

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final _searchController = TextEditingController();
  late Future<List<SaccoRecord>> _directory;
  Timer? _debounce;
  Future<Map<String, dynamic>>? _comparison;
  String _comparedIds = ''; // which picks the result above belongs to

  @override
  void initState() {
    super.initState();
    _directory = ApiService.searchSaccos('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _directory = ApiService.searchSaccos(value.trim());
      });
    });
  }

  void _toggle(SaccoRecord sacco) {
    final picks = context.read<CompareProvider>();
    if (picks.contains(sacco.id)) {
      picks.remove(sacco.id);
    } else if (!picks.add(sacco)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compare up to three SACCOs at a time.')),
      );
    }
  }

  void _compare(List<int> ids) {
    setState(() {
      _comparedIds = ids.join(',');
      _comparison = ApiService.compareSaccos(ids);
    });
  }

  @override
  Widget build(BuildContext context) {
    final picks = context.watch<CompareProvider>();
    final ids = picks.selected.map((s) => s.id).toList();
    // A result only stays on screen while it matches the current picks.
    final showResult = _comparison != null && _comparedIds == ids.join(',');

    return Scaffold(
      appBar: AppBar(title: const Text('Compare SACCOs')),
      body: Column(
        children: [
          if (picks.count > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final sacco in picks.selected)
                    InputChip(
                      label: Text(sacco.name),
                      onDeleted: () => picks.remove(sacco.id),
                      deleteButtonTooltipMessage: 'Remove ${sacco.name}',
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Find SACCOs to compare',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<SaccoRecord>>(
              future: _directory,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${snapshot.error}', textAlign: TextAlign.center),
                        TextButton.icon(
                          onPressed: () => _search(_searchController.text),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  );
                }
                final saccos = snapshot.data ?? const <SaccoRecord>[];
                if (saccos.isEmpty) return const Center(child: Text('No SACCOs found.'));
                return ListView.builder(
                  itemCount: saccos.length,
                  itemBuilder: (context, index) {
                    final sacco = saccos[index];
                    return CheckboxListTile(
                      value: picks.contains(sacco.id),
                      activeColor: AppColors.forest,
                      title: Text(sacco.name),
                      subtitle: Text(sacco.county ?? 'County not listed'),
                      onChanged: (_) => _toggle(sacco),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showResult) _ComparisonResult(future: _comparison!),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: picks.canCompare ? () => _compare(ids) : null,
                      icon: const Icon(Icons.compare_arrows_rounded),
                      label: Text(picks.canCompare
                          ? 'Compare ${picks.count} SACCOs'
                          : 'Pick ${2 - picks.count} more to compare'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonResult extends StatelessWidget {
  const _ComparisonResult({required this.future});

  final Future<Map<String, dynamic>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(color: AppColors.forest),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              snapshot.error.toString(),
              style: const TextStyle(color: AppColors.red, fontSize: 12),
            ),
          );
        }
        final results = snapshot.data?['results'] as List<dynamic>? ?? const [];
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 190),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final item in results)
                ListTile(
                  dense: true,
                  title: Text(item['sacco']['name'] as String),
                  subtitle: Text('Composite ${item['composite'] ?? '—'}  ·  ${item['rating'] ?? 'Unrated'}'),
                  trailing: const Icon(Icons.check_circle_outline, color: AppColors.green),
                ),
            ],
          ),
        );
      },
    );
  }
}
