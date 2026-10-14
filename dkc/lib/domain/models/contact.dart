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

  /// A Bangladeshi mobile number in any common form (01..., +8801..., 8801...,
  /// spaces or dashes, Bangla digits) as +8801XXXXXXXXX, or null if invalid.
  static String? normalizePhone(String input) {
    const banglaDigits = '০১২৩৪৫৬৭৮৯';
    final ascii = input.split('').map((c) {
      final i = banglaDigits.indexOf(c);
      return i >= 0 ? '$i' : c;
    }).join();
    final compact = ascii.replaceAll(RegExp(r'[\s\-().]'), '');
    final match = RegExp(r'^(?:\+88|0088|88)?(01[3-9]\d{8})$').firstMatch(compact);
    return match == null ? null : '+88${match.group(1)}';
  }

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
