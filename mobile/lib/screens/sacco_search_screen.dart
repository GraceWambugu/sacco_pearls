import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/directory_request.dart';
import '../models/sacco.dart';
import '../providers/compare_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';
import 'sacco_profile_screen.dart';

typedef SaccoSearchLoader = Future<List<SaccoRecord>> Function(String query, {String? county});
typedef RankingsLoader = Future<List<RankedSacco>> Function();

Future<List<RankedSacco>> _allRankings() => ApiService.getRankings();

/// Health-rating choices in the filter. "Unrated" is for SACCOs with no score.
const _ratingChoices = ['Green', 'Amber', 'Red', 'Unrated'];

/// The Directory tab: search by name, filter by county, rating and NPL,
/// and see every SACCO's score with three headline figures.
class SaccoSearchScreen extends StatefulWidget {
  const SaccoSearchScreen({
    super.key,
    this.loader = ApiService.searchSaccos,
    this.rankingsLoader = _allRankings,
    this.request,
  });

  /// Where results and scores come from. Tests pass fakes instead of the real API.
  final SaccoSearchLoader loader;
  final RankingsLoader rankingsLoader;

  /// Filters sent from the Home screen (search bar and quick-filter chips).
  final ValueListenable<DirectoryRequest?>? request;

  @override
  State<SaccoSearchScreen> createState() => _SaccoSearchScreenState();
}

class _SaccoSearchScreenState extends State<SaccoSearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  late Future<List<SaccoRecord>> _results;
  String _query = '';
  String? _county; // null = all counties
  String? _rating; // null = all ratings
  bool _lowNplOnly = false;
  List<String> _counties = const [];
  Map<int, RankedSacco> _scores = const {}; // SACCO id -> its latest score
  int? _year;

  @override
  void initState() {
    super.initState();
    _results = _load();
    _loadScores();
    widget.request?.addListener(_applyRequest);
    _applyRequest();
  }

  @override
  void dispose() {
    widget.request?.removeListener(_applyRequest);
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Home sent us here with a search or a quick filter: show exactly that.
  void _applyRequest() {
    final request = widget.request?.value;
    if (request == null || !mounted) return;
    _debounce?.cancel();
    _searchController.text = request.query;
    setState(() {
      _query = request.query;
      _county = request.county;
      _rating = request.quickFilter == QuickFilter.topRated ? 'Green' : null;
      _lowNplOnly = request.quickFilter == QuickFilter.lowNpl;
      _results = _load();
    });
  }

  Future<void> _loadScores() async {
    try {
      final ranked = await widget.rankingsLoader();
      if (!mounted) return;
      setState(() {
        _scores = {for (final item in ranked) item.sacco.id: item};
        _year = ranked.isEmpty ? null : ranked.first.year;
      });
    } catch (_) {
      // Without scores the cards still list every SACCO, just marked "Not rated".
    }
  }

  Future<List<SaccoRecord>> _load() async {
    final saccos = await widget.loader(_query.trim(), county: _county);
    // The first full list (no name, no county) tells us which counties exist.
    if (_counties.isEmpty && _query.trim().isEmpty && _county == null) {
      final counties = saccos.map((s) => s.county).whereType<String>().toSet().toList()..sort();
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

  void _reset() {
    _searchController.clear();
    setState(() {
      _query = '';
      _county = null;
      _rating = null;
      _lowNplOnly = false;
      _results = _load();
    });
  }

  void _reload() {
    setState(() {
      _results = _load();
    });
    _loadScores();
  }

  /// Rating and NPL filters work on the scores we already have, so no extra API call.
  List<SaccoRecord> _applyScoreFilters(List<SaccoRecord> saccos) {
    return saccos.where((sacco) {
      final score = _scores[sacco.id];
      if (_rating == 'Unrated' && score != null) return false;
      if (_rating != null && _rating != 'Unrated' && score?.rating != _rating) return false;
      if (_lowNplOnly && !((score?.nplRatio ?? 999) <= 5)) return false;
      return true;
    }).toList();
  }

  void _toggleCompare(SaccoRecord sacco) {
    final picks = context.read<CompareProvider>();
    final String message;
    if (picks.contains(sacco.id)) {
      picks.remove(sacco.id);
      message = '${sacco.name} removed from compare';
    } else if (picks.add(sacco)) {
      message = '${sacco.name} added to compare (${picks.count} of ${CompareProvider.maxSaccos})';
    } else {
      message = 'Compare already has three SACCOs. Remove one first.';
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<SaccoRecord>>(
          future: _results,
          builder: (context, snapshot) {
            final header = <Widget>[
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SACCO directory', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        Text(
                          'Search deposit-taking SACCOs licensed by SASRA',
                          style: TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(tooltip: 'Refresh SACCOs', onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
                ],
              ),
              const SizedBox(height: 14),
              _FilterPanel(
                controller: _searchController,
                query: _query,
                onSearchChanged: _onSearchChanged,
                counties: _counties,
                county: _county,
                onCounty: _selectCounty,
                rating: _rating,
                onRating: (value) => setState(() => _rating = value),
                lowNplOnly: _lowNplOnly,
                onLowNpl: (value) => setState(() => _lowNplOnly = value),
                onReset: _reset,
              ),
              const SizedBox(height: 14),
            ];

            if (snapshot.connectionState == ConnectionState.waiting) {
              return _withHeader(header, const [
                Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
              ]);
            }
            if (snapshot.hasError) {
              final error = snapshot.error;
              final unreachable = error is ApiException && error.isUnreachable;
              return _withHeader(header, [
                _Message(
                  icon: unreachable ? Icons.wifi_off_rounded : Icons.cloud_off_outlined,
                  title: unreachable ? 'Could not reach the server' : 'Search failed',
                  message: unreachable ? 'Check your internet connection, then try again.' : error.toString(),
                  action: FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ),
              ]);
            }

            final saccos = _applyScoreFilters(snapshot.data ?? const <SaccoRecord>[]);
            header.add(Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Text.rich(TextSpan(
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    children: [
                      const TextSpan(text: 'Showing '),
                      TextSpan(
                        text: '${saccos.length}',
                        style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: saccos.length == 1 ? ' SACCO' : ' SACCOs'),
                    ],
                  )),
                  const Spacer(),
                  if (_year != null)
                    Text('Figures: $_year', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ));

            if (saccos.isEmpty) {
              return _withHeader(header, [
                _Message(
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppColors.amber,
                  title: 'No SACCOs match your search',
                  message: _query.trim().isEmpty
                      ? 'Try another county or rating, or reset the filters.'
                      : 'No SACCO names match "${_query.trim()}" with these filters. '
                          'Check the spelling or reset the filters.',
                  action: TextButton(onPressed: _reset, child: const Text('Reset filters')),
                ),
              ]);
            }

            return ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: header.length + saccos.length,
              itemBuilder: (context, index) {
                if (index < header.length) return header[index];
                final sacco = saccos[index - header.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SaccoCard(
                    sacco: sacco,
                    score: _scores[sacco.id],
                    onToggleCompare: () => _toggleCompare(sacco),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _withHeader(List<Widget> header, List<Widget> body) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [...header, ...body],
    );
  }
}

/// The search box with county and rating dropdowns, the Low NPL switch and Reset.
class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.controller,
    required this.query,
    required this.onSearchChanged,
    required this.counties,
    required this.county,
    required this.onCounty,
    required this.rating,
    required this.onRating,
    required this.lowNplOnly,
    required this.onLowNpl,
    required this.onReset,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onSearchChanged;
  final List<String> counties;
  final String? county;
  final ValueChanged<String?> onCounty;
  final String? rating;
  final ValueChanged<String?> onRating;
  final bool lowNplOnly;
  final ValueChanged<bool> onLowNpl;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    // A county chosen on Home may not be in the list yet while it loads; include it anyway.
    final countyOptions = {...counties, ?county}.toList()..sort();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search by SACCO name',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              fillColor: AppColors.paper,
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        controller.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Dropdown(
                  label: 'County',
                  value: county,
                  allLabel: 'All counties',
                  options: countyOptions,
                  onChanged: onCounty,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Dropdown(
                  label: 'Health rating',
                  value: rating,
                  allLabel: 'All ratings',
                  options: _ratingChoices,
                  optionLabel: (value) => switch (value) {
                    'Green' => 'Green (75–100)',
                    'Amber' => 'Amber (50–74.9)',
                    'Red' => 'Red (below 50)',
                    _ => 'Not rated',
                  },
                  onChanged: onRating,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: const Text('Low NPL (5% or less)'),
                selected: lowNplOnly,
                onSelected: onLowNpl,
              ),
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.allLabel,
    required this.options,
    required this.onChanged,
    this.optionLabel,
  });

  final String label;
  final String? value;
  final String allLabel;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String Function(String)? optionLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String?>(
          initialValue: value,
          key: ValueKey('$label:$value'), // rebuild when Home or Reset changes the value
          isExpanded: true,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.ink, fontSize: 13),
          decoration: const InputDecoration(
            isDense: true,
            fillColor: AppColors.paper,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(allLabel)),
            for (final option in options)
              DropdownMenuItem<String?>(
                value: option,
                child: Text(optionLabel?.call(option) ?? option, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// One SACCO: name, county, score badge, headline figures, and the two actions.
class _SaccoCard extends StatelessWidget {
  const _SaccoCard({required this.sacco, required this.score, required this.onToggleCompare});

  final SaccoRecord sacco;
  final RankedSacco? score;
  final VoidCallback onToggleCompare;

  @override
  Widget build(BuildContext context) {
    final picked = context.watch<CompareProvider>().contains(sacco.id);
    void openProfile() => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => SaccoProfileScreen(sacco: sacco)),
        );

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: openProfile,
        onLongPress: onToggleCompare, // long-press also adds to Compare
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sacco.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 13, color: AppColors.muted),
                            const SizedBox(width: 3),
                            Text(
                              sacco.county ?? 'County not listed',
                              style: const TextStyle(color: AppColors.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ScoreBadge(composite: score?.composite, rating: score?.rating),
                ],
              ),
              const SizedBox(height: 12),
              FigureStrip(figures: [
                Figure('Asset base', kesBillions(score?.totalAssets)),
                Figure('NPL ratio', percent(score?.nplRatio)),
                Figure('Core capital', percent(score?.cca), emphasis: true),
              ]),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: CompareToggle(picked: picked, onPressed: onToggleCompare)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: openProfile,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text('View profile', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12)),
                          ),
                          Icon(Icons.chevron_right_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.iconColor = AppColors.muted,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(icon, size: 40, color: iconColor),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}
