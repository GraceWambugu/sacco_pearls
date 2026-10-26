/// Quick filters the Home screen can ask the Directory to apply.
enum QuickFilter { none, topRated, lowNpl }

/// What the Directory should show when Home sends the member there,
/// e.g. after typing in Home's search bar or tapping a quick-filter chip.
class DirectoryRequest {
  const DirectoryRequest({this.query = '', this.county, this.quickFilter = QuickFilter.none});

  final String query;
  final String? county;
  final QuickFilter quickFilter;
}
