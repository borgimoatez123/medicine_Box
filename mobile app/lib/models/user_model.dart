class UserModel {
  const UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.username,
    this.phone,
    this.role,
    this.gender,
    this.birthDate,
    this.profileImage,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? username;
  final String? phone;
  final String? role;
  final String? gender;
  final DateTime? birthDate;
  final String? profileImage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get fullName => "${firstName.trim()} ${lastName.trim()}".trim();

  String get firstname => firstName;
  String get lastname => lastName;

  UserModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? username,
    String? phone,
    String? role,
    String? gender,
    DateTime? birthDate,
    String? profileImage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final dynamic id = json["id"] ?? json["_id"];
    final dynamic firstName =
        json["firstName"] ?? json["firstname"] ?? json["first_name"];
    final dynamic lastName =
        json["lastName"] ?? json["lastname"] ?? json["last_name"];

    return UserModel(
      id: id == null ? "" : id.toString(),
      firstName: firstName == null ? "" : firstName.toString(),
      lastName: lastName == null ? "" : lastName.toString(),
      email: (json["email"] ?? "").toString(),
      username: json["username"]?.toString(),
      phone: (json["phone"] ?? json["phoneNumber"] ?? json["mobile"])
          ?.toString(),
      role: json["role"]?.toString(),
      gender: json["gender"]?.toString(),
      birthDate: parseDate(
        json["birthDate"] ?? json["dateOfBirth"] ?? json["dob"],
      ),
      profileImage: (json["profileImage"] ?? json["avatar"] ?? json["photoUrl"])
          ?.toString(),
      createdAt: parseDate(json["createdAt"]),
      updatedAt: parseDate(json["updatedAt"]),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id.trim().isNotEmpty) "id": id,
      "firstName": firstName,
      "lastName": lastName,
      "email": email,
      if (username != null && username!.trim().isNotEmpty)
        "username": username,
      if (phone != null && phone!.trim().isNotEmpty) "phone": phone!.trim(),
      if (role != null && role!.trim().isNotEmpty) "role": role!.trim(),
      if (gender != null) "gender": gender,
      if (birthDate != null) "birthDate": birthDate!.toIso8601String(),
      if (profileImage != null) "profileImage": profileImage,
      if (createdAt != null) "createdAt": createdAt!.toIso8601String(),
      if (updatedAt != null) "updatedAt": updatedAt!.toIso8601String(),
    };
  }
}
