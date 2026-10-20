class DrawerSensorState {
  const DrawerSensorState({
    required this.drawerId,
    required this.drawerIndex,
    this.medicineBoxId,
    this.temperature,
    this.humidity,
    required this.fireDetected,
    this.updatedAt,
  });

  factory DrawerSensorState.fromJson(Map<String, dynamic> json) {
    return _parseJson(json);
  }

  factory DrawerSensorState.fromSingleDrawerJson(Map<String, dynamic> json) {
    final DrawerSensorState state = _parseJson(json, fallbackIndex: 1);
    final String? medicineBoxId = (json["medicineBoxId"] as String?)?.trim() ??
        (json["medicine_box_id"] as String?)?.trim();
    final num? idx = json["drawerIndex"] is num
        ? json["drawerIndex"] as num
        : json["drawer_index"] is num
            ? json["drawer_index"] as num
            : json["drawerNumber"] is num
                ? json["drawerNumber"] as num
                : json["drawer_number"] is num
                    ? json["drawer_number"] as num
                    : null;
    final int drawerIndex = idx?.toInt() ?? state.drawerIndex;
    return DrawerSensorState(
      drawerId: state.drawerId,
      drawerIndex: drawerIndex,
      medicineBoxId: medicineBoxId ?? state.medicineBoxId,
      temperature: state.temperature,
      humidity: state.humidity,
      fireDetected: state.fireDetected,
      updatedAt: state.updatedAt,
    );
  }

  static DrawerSensorState _parseJson(
    Map<String, dynamic> json, {
    int fallbackIndex = 1,
  }) {
    final num? temp =
        json["temperature"] is num ? json["temperature"] as num : null;
    final num? hum =
        json["humidity"] is num ? json["humidity"] as num : null;
    final dynamic fireRaw = json["fireDetected"] ?? json["fire_detected"];
    final bool fire = fireRaw is bool ? fireRaw : false;
    DateTime? updatedAt;
    if (json["updatedAt"] != null) {
      updatedAt = DateTime.tryParse(json["updatedAt"].toString());
    } else if (json["updated_at"] != null) {
      updatedAt = DateTime.tryParse(json["updated_at"].toString());
    }
    final num? idx = json["drawerIndex"] is num
        ? json["drawerIndex"] as num
        : json["drawer_index"] is num
            ? json["drawer_index"] as num
            : json["drawerNumber"] is num
                ? json["drawerNumber"] as num
                : json["drawer_number"] is num
                    ? json["drawer_number"] as num
                    : null;
    final String? medicineBoxId =
        (json["medicineBoxId"] as String?)?.trim() ??
            (json["medicine_box_id"] as String?)?.trim();
    return DrawerSensorState(
      drawerId: (json["drawerId"] as String?)?.trim() ??
          (json["drawer_id"] as String?)?.trim() ??
          "",
      drawerIndex: idx?.toInt() ?? fallbackIndex,
      medicineBoxId: medicineBoxId,
      temperature: temp?.toDouble(),
      humidity: hum?.toDouble(),
      fireDetected: fire,
      updatedAt: updatedAt,
    );
  }

  final String drawerId;
  final int drawerIndex;
  final String? medicineBoxId;
  final double? temperature;
  final double? humidity;
  final bool fireDetected;
  final DateTime? updatedAt;
}

class MedicineBoxSensorStateResponse {
  const MedicineBoxSensorStateResponse({
    required this.medicineBoxId,
    required this.drawers,
  });

  factory MedicineBoxSensorStateResponse.fromJson(Map<String, dynamic> json) {
    final List<DrawerSensorState> drawers = <DrawerSensorState>[];
    final dynamic drawersRaw = json["drawers"];
    if (drawersRaw is List) {
      for (final dynamic d in drawersRaw) {
        if (d is Map<String, dynamic>) {
          drawers.add(DrawerSensorState.fromJson(d));
        }
      }
    }
    drawers.sort(
      (DrawerSensorState a, DrawerSensorState b) =>
          a.drawerIndex.compareTo(b.drawerIndex),
    );
    return MedicineBoxSensorStateResponse(
      medicineBoxId: (json["medicineBoxId"] as String?)?.trim() ??
          (json["medicine_box_id"] as String?)?.trim() ??
          "",
      drawers: List<DrawerSensorState>.unmodifiable(drawers),
    );
  }

  final String medicineBoxId;
  final List<DrawerSensorState> drawers;
}
