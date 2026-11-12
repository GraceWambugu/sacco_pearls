import '../models/sacco.dart';
import 'rating.dart';

/// Short names for the four scored dimensions, as a member would say them.
const _plainNames = {'E': 'capital strength', 'A': 'loan quality', 'R': 'income', 'S': 'growth'};

/// A plain-language summary built only from the score the API returned.
/// Nothing here is invented: every word comes from a band or a figure in [score].
String plainSummary(String saccoName, SaccoScore score) {
  final composite = score.composite;
  if (composite == null) {
    return 'There are not enough published figures to rate $saccoName for ${score.year}.';
  }

  final strong = <String>[];
  final watch = <String>[];
  for (final code in const ['E', 'A', 'R', 'S']) {
    final dimension = score.dimensions[code];
    final value = dimension?.score;
    if (dimension == null || !dimension.scored || value == null) continue;
    if (value >= 75) {
      strong.add(_plainNames[code]!);
    } else {
      watch.add('${_plainNames[code]} is ${bandForScore(value)}${_keyFigure(dimension)}');
    }
  }

  final parts = <String>[
    '$saccoName is rated ${score.rating} (${composite.toDouble().toStringAsFixed(1)} out of 100) '
        'on ${score.year} figures.',
    if (strong.isNotEmpty) 'Strong on ${_joinAnd(strong)}.',
    if (watch.isNotEmpty) 'Watch: ${_joinAnd(watch)}.',
    if (score.overrides.isNotEmpty) 'The rating was adjusted by a safety rule (see below).',
  ];
  return parts.join(' ');
}

/// The figure that explains a weak dimension, e.g. " (NPL 8.3%)".
String _keyFigure(PearlsDimension dimension) {
  // The weakest indicator in the dimension is the one worth naming.
  final weak = dimension.indicators.where((i) => i.band == 'Red' || i.band == 'Amber').toList();
  if (weak.isEmpty || weak.first.value == null) return '';
  final indicator = weak.first;
  final label = _shortNames[indicator.key] ?? indicator.label.toLowerCase();
  return ' ($label ${formatNumber(indicator.value!)}${indicator.unit ?? ''})';
}

/// Short names that read well inside a sentence.
const _shortNames = {
  'npl_ratio': 'NPL',
  'cca': 'core capital/assets',
  'ccd': 'core capital/deposits',
  'ica': 'institutional capital/assets',
  'ext_borrowing': 'external borrowing',
  'income_yield': 'income/assets',
  'asset_growth': 'asset growth',
  'deposit_growth': 'deposit growth',
  'loan_growth': 'loan growth',
};

String _joinAnd(List<String> items) => items.length == 1
    ? items.single
    : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
