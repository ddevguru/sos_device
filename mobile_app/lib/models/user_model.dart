class UserModel {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String bloodGroup;
  final String medicalNotes;
  final String customSosMessage;
  final String smsSenderNumber;
  final int contactsCount;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.bloodGroup = '',
    this.medicalNotes = '',
    this.customSosMessage = '',
    this.smsSenderNumber = '',
    this.contactsCount = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      bloodGroup: json['bloodGroup'] ?? json['blood_group'] ?? '',
      medicalNotes: json['medicalNotes'] ?? json['medical_notes'] ?? '',
      customSosMessage: json['customSosMessage'] ?? json['custom_sos_message'] ?? '',
      smsSenderNumber: json['smsSenderNumber'] ?? json['sms_sender_number'] ?? '',
      contactsCount: json['contactsCount'] is int ? json['contactsCount'] : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'bloodGroup': bloodGroup,
      'medicalNotes': medicalNotes,
      'customSosMessage': customSosMessage,
      'smsSenderNumber': smsSenderNumber,
      'contactsCount': contactsCount,
    };
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? bloodGroup,
    String? medicalNotes,
    String? customSosMessage,
    String? smsSenderNumber,
    int? contactsCount,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      medicalNotes: medicalNotes ?? this.medicalNotes,
      customSosMessage: customSosMessage ?? this.customSosMessage,
      smsSenderNumber: smsSenderNumber ?? this.smsSenderNumber,
      contactsCount: contactsCount ?? this.contactsCount,
    );
  }
}
