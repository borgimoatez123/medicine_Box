class User {
  const User({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    this.phone,
    this.role = "USER",
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String? phone;
  final String? role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? password,
    String? phone,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      password: password ?? this.password,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
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
    final dynamic phone =
        json["phone"] ?? json["phoneNumber"] ?? json["mobile"];

    return User(
      id: id == null ? null : id.toString(),
      firstName: firstName == null ? "" : firstName.toString(),
      lastName: lastName == null ? "" : lastName.toString(),
      email: (json["email"] ?? "").toString(),
      password: (json["password"] ?? "").toString(),
      phone: phone?.toString(),
      role: json["role"]?.toString() ?? "USER",
      createdAt: parseDate(json["createdAt"]),
      updatedAt: parseDate(json["updatedAt"]),
    );
  }

  Map<String, dynamic> toJson() {
    final String? trimmedPhone = (phone == null)
        ? null
        : (phone!.trim().isEmpty ? null : phone!.trim());

    return <String, dynamic>{
      if (id != null && id!.trim().isNotEmpty) "id": id!.trim(),
      "firstName": firstName.trim(),
      "lastName": lastName.trim(),
      "email": email.trim(),
      if (password.isNotEmpty) "password": password,
      if (trimmedPhone != null) "phone": trimmedPhone,
      if (role != null && role!.trim().isNotEmpty) "role": role!.trim(),
    };
  }
}
