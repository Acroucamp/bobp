class Business {
  const Business({
    required this.id,
    required this.name,
    required this.ownerId,
    this.description,
  });

  final String id;
  final String name;
  final String ownerId;
  final String? description;

  factory Business.fromJson(Map<String, dynamic> j) => Business(
    id: j['id'] as String,
    name: j['name'] as String,
    ownerId: j['owner_id'] as String,
    description: j['description'] as String?,
  );
}

/// A business plus the current user's role in it ('owner' or 'staff').
class BusinessMembership {
  const BusinessMembership({required this.business, required this.role});

  final Business business;
  final String role;

  bool get isOwner => role == 'owner';
}
