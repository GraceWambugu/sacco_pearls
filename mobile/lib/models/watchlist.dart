import 'sacco.dart';

class MemberWatchlist {
  const MemberWatchlist({
    required this.id,
    required this.name,
    required this.saccos,
  });

  final int id;
  final String name;
  final List<SaccoRecord> saccos;

  factory MemberWatchlist.fromJson(Map<String, dynamic> json) {
    final items = json['saccos'] as List<dynamic>? ?? const [];
    return MemberWatchlist(
      id: json['id'] as int,
      name: json['name'] as String,
      saccos: items
          .map((item) => SaccoRecord.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
    );
  }
}