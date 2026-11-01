enum AccountType {
  customer,
  provider;

  static AccountType parse(String? s) =>
      s == 'provider' ? AccountType.provider : AccountType.customer;

  String get label => this == provider ? 'Service provider' : 'Customer';
}

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.accountType,
    this.email,
  });

  final String id;
  final String fullName;
  final String? email;
  final AccountType accountType;

  bool get isProvider => accountType == AccountType.provider;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: j['id'] as String,
    fullName: (j['full_name'] as String?) ?? '',
    email: j['email'] as String?,
    accountType: AccountType.parse(j['account_type'] as String?),
  );
}
