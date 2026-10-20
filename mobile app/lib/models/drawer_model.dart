enum DrawerStatus { empty, loaded, locked, dispensing, error }

extension DrawerStatusX on DrawerStatus {
  String get backendValue => switch (this) {
    DrawerStatus.empty => "EMPTY",
    DrawerStatus.loaded => "LOADED",
    DrawerStatus.locked => "LOCKED",
    DrawerStatus.dispensing => "DISPENSING",
    DrawerStatus.error => "ERROR",
  };

  String get displayLabel => switch (this) {
    DrawerStatus.empty => "Empty",
    DrawerStatus.loaded => "Loaded",
    DrawerStatus.locked => "Locked",
    DrawerStatus.dispensing => "Dispensing",
    DrawerStatus.error => "Error",
  };
}

extension _DrawerStatusParser on String {
  DrawerStatus? toDrawerStatusOrNull() {
    final String s = trim().toUpperCase();
    switch (s) {
      case "EMPTY":
        return DrawerStatus.empty;
      case "LOADED":
        return DrawerStatus.loaded;
      case "LOCKED":
        return DrawerStatus.locked;
      case "DISPENSING":
        return DrawerStatus.dispensing;
      case "ERROR":
        return DrawerStatus.error;
    }
    return null;
  }
}

class DrawerPaginationMeta {
  const DrawerPaginationMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory DrawerPaginationMeta.fromJson(Map<String, dynamic> json) {
    final num? p = json["page"] is num ? json["page"] as num : null;
    final num? l = json["limit"] is num ? json["limit"] as num : null;
    final num? t = json["total"] is num ? json["total"] as num : null;
    final num? tp =
        json["totalPages"] is num ? json["totalPages"] as num : null;
    return DrawerPaginationMeta(
      page: p?.toInt() ?? 1,
      limit: l?.toInt() ?? 20,
      total: t?.toInt() ?? 0,
      totalPages: tp?.toInt() ?? 0,
    );
  }

  final int page;
  final int limit;
  final int total;
  final int totalPages;
}

typedef DrawerPageResult = ({
  List<DrawerModel> items,
  DrawerPaginationMeta meta,
});

class DrawerModel {
  const DrawerModel({
    required this.id,
    required this.medicineBoxId,
    required this.drawerNumber,
    required this.status,
    this.medicationId,
    this.lastDispensedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory DrawerModel.fromJson(Map<String, dynamic> json) {
    final String? statusRaw = json["status"] as String?;
    final DrawerStatus parsed = (statusRaw == null
        ? null
        : statusRaw.toDrawerStatusOrNull()) ??
        DrawerStatus.empty;

    DateTime? createdAt;
    DateTime? updatedAt;
    DateTime? lastDispensedAt;

    if (json["createdAt"] != null) {
      createdAt = DateTime.tryParse(json["createdAt"].toString());
    }
    if (json["updatedAt"] != null) {
      updatedAt = DateTime.tryParse(json["updatedAt"].toString());
    }
    if (json["lastDispensedAt"] != null) {
      lastDispensedAt =
          DateTime.tryParse(json["lastDispensedAt"].toString());
    }

    final num? dn =
        json["drawerNumber"] is num ? json["drawerNumber"] as num : null;

    return DrawerModel(
      id: (json["id"] as String?)?.trim() ?? "",
      medicineBoxId: (json["medicineBoxId"] as String?)?.trim() ?? "",
      drawerNumber: dn?.toInt() ?? 1,
      status: parsed,
      medicationId: (json["medicationId"] as String?)?.trim(),
      lastDispensedAt: lastDispensedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  final String id;
  final String medicineBoxId;
  final int drawerNumber;
  final DrawerStatus status;
  final String? medicationId;
  final DateTime? lastDispensedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DrawerModel copyWith({
    DrawerStatus? status,
    String? medicationId,
    DateTime? lastDispensedAt,
  }) {
    return DrawerModel(
      id: id,
      medicineBoxId: medicineBoxId,
      drawerNumber: drawerNumber,
      status: status ?? this.status,
      medicationId: medicationId ?? this.medicationId,
      lastDispensedAt: lastDispensedAt ?? this.lastDispensedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class UpdateDrawerStatusRequest {
  const UpdateDrawerStatusRequest({required this.status});
  final DrawerStatus status;

  bool get isEmpty => false;

  Map<String, dynamic> get body => <String, dynamic>{
    "status": status.backendValue,
  };
}
