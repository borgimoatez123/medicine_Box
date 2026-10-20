class DrawerCommandResponse {
  const DrawerCommandResponse({
    required this.commandId,
    required this.drawerId,
    required this.deviceId,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  factory DrawerCommandResponse.fromJson(Map<String, dynamic> json) {
    final dynamic ts =
        json["createdAt"] ?? json["created_at"];
    DateTime? createdAt;
    if (ts != null) createdAt = DateTime.tryParse(ts.toString());
    return DrawerCommandResponse(
      commandId: (json["commandId"] as String?)?.trim() ??
          (json["command_id"] as String?)?.trim() ??
          "",
      drawerId: (json["drawerId"] as String?)?.trim() ??
          (json["drawer_id"] as String?)?.trim() ??
          "",
      deviceId: (json["deviceId"] as String?)?.trim() ??
          (json["device_id"] as String?)?.trim() ??
          "",
      type: (json["type"] as String?)?.trim() ?? "",
      status: (json["status"] as String?)?.trim() ?? "",
      createdAt: createdAt ?? DateTime.now().toUtc(),
    );
  }

  final String commandId;
  final String drawerId;
  final String deviceId;
  final String type;
  final String status;
  final DateTime createdAt;

  bool get isPending => status.toUpperCase() == "PENDING";
  bool get isOpenDrawerCommand => type.toUpperCase() == "OPEN_DRAWER";
  bool get isCloseDrawerCommand => type.toUpperCase() == "CLOSE_DRAWER";
}
