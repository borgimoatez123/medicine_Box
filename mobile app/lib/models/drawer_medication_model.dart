class DrawerMedicationModel {
  const DrawerMedicationModel({
    required this.id,
    required this.drawerId,
    required this.medicationId,
    required this.assignedAt,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.quantity,
    this.missingQuantity,
  });

  final String id;
  final String drawerId;
  final String medicationId;
  final DateTime assignedAt;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? quantity;
  final int? missingQuantity;

  factory DrawerMedicationModel.fromJson(Map<String, dynamic> json) {
    final String? assignedAtRaw = json["assignedAt"]?.toString();
    final String? createdAtRaw = json["createdAt"]?.toString();
    final String? updatedAtRaw = json["updatedAt"]?.toString();

    final DateTime assignedAt =
        assignedAtRaw != null && assignedAtRaw.isNotEmpty
        ? DateTime.tryParse(assignedAtRaw) ?? DateTime.now()
        : DateTime.now();

    final int? quantity = _readInt(json, const <String>{
      "quantity",
      "quantity_assigned",
      "assignedQuantity",
    });
    final int? missingQuantity = _readInt(json, const <String>{
      "missingQuantity",
      "missing_quantity",
      "remainingQuantity",
      "remaining_quantity",
      "overflowQuantity",
    });

    return DrawerMedicationModel(
      id: (json["id"] as String?)?.toString() ?? "",
      drawerId:
          (json["drawerId"] ?? json["drawer_id"])?.toString().trim() ?? "",
      medicationId:
          (json["medicationId"] ?? json["medication_id"])?.toString().trim() ??
          "",
      assignedAt: assignedAt,
      isActive: json["isActive"] == true || json["is_active"] == true,
      createdAt: createdAtRaw != null && createdAtRaw.isNotEmpty
          ? DateTime.tryParse(createdAtRaw)
          : null,
      updatedAt: updatedAtRaw != null && updatedAtRaw.isNotEmpty
          ? DateTime.tryParse(updatedAtRaw)
          : null,
      quantity: quantity,
      missingQuantity: missingQuantity,
    );
  }

  static int? _readInt(Map<String, dynamic> json, Set<String> keys) {
    for (final String k in keys) {
      final dynamic v = json[k];
      if (v == null) continue;
      if (v is int) return v;
      if (v is num) return v.toInt();
      final int? parsed = int.tryParse(v.toString().trim());
      if (parsed != null) return parsed;
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "drawerId": drawerId,
      "medicationId": medicationId,
      "assignedAt": assignedAt.toIso8601String(),
      "isActive": isActive,
      if (createdAt != null) "createdAt": createdAt!.toIso8601String(),
      if (updatedAt != null) "updatedAt": updatedAt!.toIso8601String(),
      if (quantity != null) "quantity": quantity,
      if (missingQuantity != null) "missingQuantity": missingQuantity,
    };
  }

  DrawerMedicationModel copyWith({
    String? id,
    bool? isActive,
    DateTime? assignedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? quantity,
    int? missingQuantity,
  }) {
    return DrawerMedicationModel(
      id: id ?? this.id,
      drawerId: drawerId,
      medicationId: medicationId,
      assignedAt: assignedAt ?? this.assignedAt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      quantity: quantity ?? this.quantity,
      missingQuantity: missingQuantity ?? this.missingQuantity,
    );
  }
}

class CreateDrawerMedicationRequest {
  const CreateDrawerMedicationRequest({
    required this.drawerId,
    required this.medicationId,
    required this.quantity,
    required this.missingQuantity,
  });

  final String drawerId;
  final String medicationId;
  final int quantity;
  final int missingQuantity;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "drawerId": drawerId.trim(),
      "medicationId": medicationId.trim(),
      "quantity": quantity,
      "missingQuantity": missingQuantity,
    };
  }
}

class UpdateDrawerMedicationRequest {
  const UpdateDrawerMedicationRequest({this.isActive});

  final bool? isActive;

  bool get isEmpty => isActive == null;

  Map<String, dynamic> get body {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (isActive != null) data["isActive"] = isActive!;
    return data;
  }
}
