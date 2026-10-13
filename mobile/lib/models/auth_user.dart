class MemberAccount {
  const MemberAccount({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  final int id;
  final String email;
  final String fullName;
  final String role;

  factory MemberAccount.fromJson(Map<String, dynamic> json) {
    return MemberAccount(
      id: json['id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
    );
  }
}