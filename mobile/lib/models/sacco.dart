class SaccoRecord {
  const SaccoRecord({required this.id, required this.name, this.county});

  final int id;
  final String name;
  final String? county;

  factory SaccoRecord.fromJson(Map<String, dynamic> json) {
    return SaccoRecord(
      id: json['id'] as int,
      name: json['name'] as String,
      county: json['county'] as String?,
    );
  }
}

class SaccoScore {
  const SaccoScore({
    required this.year,
    required this.composite,
    required this.rating,
    required this.dimensions,
  });

  final int year;
  final num? composite;
  final String rating;
  final Map<String, PearlsDimension> dimensions;

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
    );
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
  });

  final String label;
  final num? value;
  final String? unit;
  final String? band;

  factory PearlsIndicator.fromJson(Map<String, dynamic> json) {
    return PearlsIndicator(
      label: json['label'] as String,
      value: json['value'] as num?,
      unit: json['unit'] as String?,
      band: json['band'] as String?,
    );
  }
}