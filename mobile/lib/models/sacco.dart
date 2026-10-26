class SaccoRecord {
  const SaccoRecord({required this.id, required this.name, this.county});

  final int id;
  final String name;
  final String? county; // often missing in SASRA's directory

  factory SaccoRecord.fromJson(Map<String, dynamic> json) {
    return SaccoRecord(
      id: json['id'] as int,
      name: json['name'] as String,
      county: json['county'] as String?,
    );
  }
}

/// One SACCO's PEARLS-aligned score for one year, as returned by GET /saccos/{id}/score.
class SaccoScore {
  const SaccoScore({
    required this.year,
    required this.composite,
    required this.rating,
    required this.dimensions,
    this.dimensionsScored = 0,
    this.dimensionsTotal = 6,
    this.overrides = const [],
    this.flags = const [],
    this.sacco,
  });

  /// Which SACCO this score belongs to (sent by the API, used on Compare).
  final SaccoRecord? sacco;
  final int year;

  /// 0-100, or null when nothing could be scored.
  final num? composite;

  /// "Green", "Amber", "Red", or "Unrated" when the API sends null.
  final String rating;

  /// Always P, E, A, R, L, S in that order.
  final Map<String, PearlsDimension> dimensions;
  final int dimensionsScored;
  final int dimensionsTotal;

  /// Rules that changed the rating, e.g. "Capped at Amber: ...".
  final List<String> overrides;

  /// Data notes: "stale", "anomaly" or "limited".
  final List<String> flags;

  factory SaccoScore.fromJson(Map<String, dynamic> json) {
    final rawDimensions = json['dimensions'] as Map<String, dynamic>? ?? const {};
    return SaccoScore(
      year: json['year'] as int,
      composite: json['composite'] as num?,
      rating: json['rating'] as String? ?? 'Unrated',
      dimensions: rawDimensions.map(
        (code, value) => MapEntry(
          code,
          PearlsDimension.fromJson(Map<String, dynamic>.from(value as Map)),
        ),
      ),
      dimensionsScored: json['dimensions_scored'] as int? ?? 0,
      dimensionsTotal: json['dimensions_total'] as int? ?? 6,
      overrides: _strings(json['overrides']),
      flags: _strings(json['flags']),
      sacco: json['sacco'] == null
          ? null
          : SaccoRecord.fromJson(Map<String, dynamic>.from(json['sacco'] as Map)),
    );
  }
}

/// GET /compare: two or three scores for the same year, plus the API's best-first order.
class CompareResult {
  const CompareResult({required this.year, required this.results, required this.ranking});

  final int year;
  final List<SaccoScore> results; // in the order the SACCOs were picked
  final List<int> ranking; // SACCO ids, best composite first

  factory CompareResult.fromJson(Map<String, dynamic> json) {
    return CompareResult(
      year: json['year'] as int,
      results: (json['results'] as List<dynamic>? ?? const [])
          .map((item) => SaccoScore.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
      ranking: (json['ranking'] as List<dynamic>? ?? const []).cast<int>(),
    );
  }

  /// Rank of one result: 1 + how many others scored strictly higher, so equal
  /// composites share a rank ("Joint 1st"). Null when the SACCO is unrated.
  int? rankOf(SaccoScore score) {
    final mine = score.composite;
    if (mine == null) return null;
    return 1 + results.where((other) => (other.composite ?? -1) > mine).length;
  }

  bool isTied(SaccoScore score) {
    final mine = score.composite;
    return mine != null && results.where((other) => other.composite == mine).length > 1;
  }
}

class PearlsDimension {
  const PearlsDimension({
    required this.code,
    required this.name,
    required this.scored,
    required this.score,
    required this.reason,
    required this.indicators,
  });

  final String code;
  final String name;
  final bool scored;
  final num? score;

  /// Why the dimension is not scored (null when it is scored).
  final String? reason;
  final List<PearlsIndicator> indicators;

  factory PearlsDimension.fromJson(Map<String, dynamic> json) {
    final indicators = json['indicators'] as List<dynamic>? ?? const [];
    return PearlsDimension(
      code: json['code'] as String,
      name: json['name'] as String,
      scored: json['scored'] as bool? ?? false,
      score: json['score'] as num?,
      reason: json['reason'] as String?,
      indicators: indicators
          .map((item) => PearlsIndicator.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
    );
  }
}

class PearlsIndicator {
  const PearlsIndicator({
    required this.label,
    required this.value,
    required this.unit,
    required this.band,
    this.rule,
  });

  final String label;
  final num? value;
  final String? unit;

  /// "Green", "Amber", "Red", or null when the figure is missing.
  final String? band;

  /// How the band is decided, e.g. "SASRA minimum 10%; Green from 12.5%".
  final String? rule;

  factory PearlsIndicator.fromJson(Map<String, dynamic> json) {
    return PearlsIndicator(
      label: json['label'] as String,
      value: json['value'] as num?,
      unit: json['unit'] as String?,
      band: json['band'] as String?,
      rule: json['rule'] as String?,
    );
  }
}

/// One year of GET /saccos/{id}/trend: the score plus key figures.
class TrendPoint {
  const TrendPoint({
    required this.year,
    this.composite,
    this.rating,
    this.dimensionScores = const {},
    this.totalAssets,
    this.totalDeposits,
    this.grossLoans,
    this.cca,
    this.nplRatio,
    this.dataStale = false,
  });

  final int year;
  final num? composite;
  final String? rating;
  final Map<String, num?> dimensionScores; // E, A, R, S
  final num? totalAssets; // KES billions
  final num? totalDeposits;
  final num? grossLoans;
  final num? cca; // percent
  final num? nplRatio;
  final bool dataStale;

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    final scores = json['dimension_scores'] as Map<String, dynamic>? ?? const {};
    return TrendPoint(
      year: json['year'] as int,
      composite: json['composite'] as num?,
      rating: json['rating'] as String?,
      dimensionScores: scores.map((code, value) => MapEntry(code, value as num?)),
      totalAssets: json['total_assets'] as num?,
      totalDeposits: json['total_deposits'] as num?,
      grossLoans: json['gross_loans'] as num?,
      cca: json['cca'] as num?,
      nplRatio: json['npl_ratio'] as num?,
      dataStale: json['data_stale'] as bool? ?? false,
    );
  }
}

List<String> _strings(dynamic value) =>
    (value as List<dynamic>? ?? const []).map((item) => item.toString()).toList(growable: false);
