class ContactModel {
  final int id;
  final String name;
  final String phone;
  final String relationship;
  final bool isActive;

  ContactModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
    this.isActive = true,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      relationship: json['relationship'] ?? 'Family',
      isActive: json['isActive'] ?? json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'isActive': isActive,
    };
  }
}
