enum MedicineBoxStatus { ready, active, maintenance, unknown }

extension MedicineBoxStatusX on MedicineBoxStatus {
  String get backendValue => switch (this) {
    MedicineBoxStatus.ready => "READY",
    MedicineBoxStatus.active => "ACTIVE",
    MedicineBoxStatus.maintenance => "MAINTENANCE",
    MedicineBoxStatus.unknown => "UNKNOWN",
  };

  String get displayLabel => switch (this) {
    MedicineBoxStatus.ready => "Ready",
    MedicineBoxStatus.active => "Active",
    MedicineBoxStatus.maintenance => "Maintenance",
    MedicineBoxStatus.unknown => "Unknown",
  };

  bool get isReady => this == MedicineBoxStatus.ready;
  bool get isActive => this == MedicineBoxStatus.active;
  bool get isMaintenance => this == MedicineBoxStatus.maintenance;
}

extension _MedicineBoxStatusParser on String {
  MedicineBoxStatus toMedicineBoxStatusOrUnknown() {
    final String s = trim().toUpperCase();
    switch (s) {
      case "READY":
      case "REGISTERED":
      case "PROVISIONED":
        return MedicineBoxStatus.ready;
      case "ACTIVE":
      case "OWNED":
        return MedicineBoxStatus.active;
      case "MAINTENANCE":
        return MedicineBoxStatus.maintenance;
    }
    if (s.isEmpty) return MedicineBoxStatus.unknown;
    return MedicineBoxStatus.unknown;
  }
}

enum DeviceStatus { active, offline, unknown }

extension DeviceStatusX on DeviceStatus {
  String get backendValue => switch (this) {
    DeviceStatus.active => "ACTIVE",
    DeviceStatus.offline => "OFFLINE",
    DeviceStatus.unknown => "UNKNOWN",
  };

  String get displayLabel => switch (this) {
    DeviceStatus.active => "Online",
    DeviceStatus.offline => "Offline",
    DeviceStatus.unknown => "Unknown",
  };

  bool get isOnline => this == DeviceStatus.active;
  bool get isOffline => this == DeviceStatus.offline;
}

extension _DeviceStatusParser on String {
  DeviceStatus toDeviceStatusOrUnknown() {
    final String s = trim().toUpperCase();
    switch (s) {
      case "ACTIVE":
        return DeviceStatus.active;
      case "ONLINE":
        return DeviceStatus.active;
      case "OFFLINE":
        return DeviceStatus.offline;
    }
    if (s.isEmpty) return DeviceStatus.unknown;
    return DeviceStatus.unknown;
  }
}

class MedicineBoxPaginationMeta {
  const MedicineBoxPaginationMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory MedicineBoxPaginationMeta.fromJson(Map<String, dynamic> json) {
    final num? p = json["page"] is num ? json["page"] as num : null;
    final num? l = json["limit"] is num ? json["limit"] as num : null;
    final num? t = json["total"] is num ? json["total"] as num : null;
    final num? tp = json["totalPages"] is num
        ? json["totalPages"] as num
        : null;
    return MedicineBoxPaginationMeta(
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

typedef MedicineBoxPageResult = ({
  List<MedicineBoxModel> items,
  MedicineBoxPaginationMeta meta,
});

class ActivateBoxRequest {
  const ActivateBoxRequest({required this.deviceId, required this.deviceToken});

  final String deviceId;
  final String deviceToken;

  Map<String, dynamic> toJson() => <String, dynamic>{
    "deviceId": deviceId.trim(),
    "deviceToken": deviceToken.trim(),
  };
}

class UpdateMedicineBoxNameRequest {
  const UpdateMedicineBoxNameRequest({required this.name});
  final String name;

  bool get isEmpty => name.trim().isEmpty;

  Map<String, dynamic> get body => <String, dynamic>{"name": name.trim()};
}

class MedicineBoxModel {
  const MedicineBoxModel({
    required this.id,
    required this.deviceId,
    required this.status,
    required this.deviceStatus,
    required this.name,
    required this.numberOfDrawers,
    required this.drawerCapacity,
    this.userId,
    this.createdAt,
    this.updatedAt,
    this.firmwareVersion,
    this.lastSeenAt,
  });

  factory MedicineBoxModel.fromJson(Map<String, dynamic> json) {
    final String? statusRaw = json["status"] as String?;
    final MedicineBoxStatus parsedStatus =
        statusRaw?.toMedicineBoxStatusOrUnknown() ?? MedicineBoxStatus.unknown;

    final String? deviceStatusRaw =
        (json["deviceStatus"] as String?) ?? (json["device_status"] as String?);
    final DeviceStatus parsedDeviceStatus =
        deviceStatusRaw?.toDeviceStatusOrUnknown() ?? DeviceStatus.unknown;

    DateTime? createdAt;
    DateTime? updatedAt;
    DateTime? lastSeenAt;

    if (json["createdAt"] != null) {
      createdAt = DateTime.tryParse(json["createdAt"].toString());
    }
    if (json["updatedAt"] != null) {
      updatedAt = DateTime.tryParse(json["updatedAt"].toString());
    }
    if (json["lastSeenAt"] != null) {
      lastSeenAt = DateTime.tryParse(json["lastSeenAt"].toString());
    }
    final num? nod = json["numberOfDrawers"] is num
        ? json["numberOfDrawers"] as num
        : null;
    final num? dc = json["drawerCapacity"] is num
        ? json["drawerCapacity"] as num
        : null;

    return MedicineBoxModel(
      id: (json["id"] as String?)?.trim() ?? "",
      deviceId: (json["deviceId"] as String?)?.trim() ?? "",
      status: parsedStatus,
      deviceStatus: parsedDeviceStatus,
      name: (json["name"] as String?)?.trim() ?? "Medicine Box",
      numberOfDrawers: nod?.toInt() ?? 0,
      drawerCapacity: dc?.toInt() ?? 0,
      userId: (json["userId"] as String?)?.trim(),
      firmwareVersion: (json["firmwareVersion"] as String?)?.trim(),
      lastSeenAt: lastSeenAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  final String id;
  final String deviceId;
  final MedicineBoxStatus status;
  final DeviceStatus deviceStatus;
  final String name;
  final int numberOfDrawers;
  final int drawerCapacity;
  final String? userId;
  final String? firmwareVersion;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get canUsePhysicalOperations => status.isActive && deviceStatus.isOnline;

  bool get canActivate => status.isReady;

  MedicineBoxModel copyWith({
    String? name,
    MedicineBoxStatus? status,
    DeviceStatus? deviceStatus,
    int? numberOfDrawers,
    int? drawerCapacity,
    Object? userId = _Sentinel._omit,
  }) {
    return MedicineBoxModel(
      id: id,
      deviceId: deviceId,
      status: status ?? this.status,
      deviceStatus: deviceStatus ?? this.deviceStatus,
      name: name ?? this.name,
      numberOfDrawers: numberOfDrawers ?? this.numberOfDrawers,
      drawerCapacity: drawerCapacity ?? this.drawerCapacity,
      userId: identical(userId, _Sentinel._omit)
          ? this.userId
          : userId as String?,
      firmwareVersion: firmwareVersion,
      lastSeenAt: lastSeenAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class _Sentinel {
  const _Sentinel._();
  static const Object _omit = _Sentinel._();
}
