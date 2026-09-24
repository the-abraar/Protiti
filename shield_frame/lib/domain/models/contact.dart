class TrustedContact {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String relationship;
  final bool isEmergency;

  TrustedContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.relationship,
    required this.isEmergency,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'relationship': relationship,
      'isEmergency': isEmergency ? 1 : 0,
    };
  }

  factory TrustedContact.fromMap(Map<String, dynamic> map) {
    return TrustedContact(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      email: map['email'] as String? ?? '',
      relationship: map['relationship'] as String? ?? 'Contact',
      isEmergency: (map['isEmergency'] as int? ?? 0) == 1,
    );
  }
}
