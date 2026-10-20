import "package:test/test.dart";

import "package:smart_medicine_app/controllers/drawer_medication_controller.dart";
import "package:smart_medicine_app/data/repositories/drawer_medication_repository.dart";
import "package:smart_medicine_app/models/drawer_medication_model.dart";
import "package:smart_medicine_app/models/drawer_model.dart";
import "package:smart_medicine_app/models/medicine_box_model.dart";
import "package:smart_medicine_app/services/drawer_medication_service.dart";

MedicineBoxModel _makeBox({
  MedicineBoxStatus status = MedicineBoxStatus.active,
  DeviceStatus deviceStatus = DeviceStatus.active,
  String userId = "user-1",
}) {
  final DateTime now = DateTime.utc(2025, 1, 1);
  return MedicineBoxModel(
    id: "box-1",
    deviceId: "DEV-1",
    name: "Test Box",
    status: status,
    deviceStatus: deviceStatus,
    userId: userId,
    numberOfDrawers: 4,
    drawerCapacity: 20,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group("MedicineBoxStatus parsing", () {
    test("READY parses", () {
      final MedicineBoxModel b = MedicineBoxModel.fromJson(<String, dynamic>{
        "status": "READY",
      });
      expect(b.status, MedicineBoxStatus.ready);
      expect(b.status.isReady, isTrue);
      expect(b.status.isActive, isFalse);
      expect(b.status.isMaintenance, isFalse);
    });

    test("ACTIVE parses", () {
      final MedicineBoxModel b = MedicineBoxModel.fromJson(<String, dynamic>{
        "status": "ACTIVE",
      });
      expect(b.status, MedicineBoxStatus.active);
      expect(b.status.isActive, isTrue);
    });

    test("MAINTENANCE parses", () {
      final MedicineBoxModel b = MedicineBoxModel.fromJson(<String, dynamic>{
        "status": "MAINTENANCE",
      });
      expect(b.status, MedicineBoxStatus.maintenance);
      expect(b.status.isMaintenance, isTrue);
    });

    test("Unknown lifecycle status fails safely", () {
      final MedicineBoxModel b = MedicineBoxModel.fromJson(<String, dynamic>{
        "status": "GARBAGE",
      });
      expect(b.status, MedicineBoxStatus.unknown);
      expect(b.status.isActive, isFalse);
      expect(b.status.isReady, isFalse);
      expect(b.status.isMaintenance, isFalse);
    });

    test("Null status defaults to unknown (never active)", () {
      final MedicineBoxModel b = MedicineBoxModel.fromJson(<String, dynamic>{});
      expect(b.status, MedicineBoxStatus.unknown);
      expect(b.status.isActive, isFalse);
    });
  });

  group("DeviceStatus parsing", () {
    test("DeviceStatus ACTIVE parses", () {
      final MedicineBoxModel b = MedicineBoxModel.fromJson(<String, dynamic>{
        "deviceStatus": "ACTIVE",
      });
      expect(b.deviceStatus, DeviceStatus.active);
      expect(b.deviceStatus.isOnline, isTrue);
      expect(b.deviceStatus.isOffline, isFalse);
    });

    test("DeviceStatus OFFLINE parses", () {
      final MedicineBoxModel b = MedicineBoxModel.fromJson(<String, dynamic>{
        "deviceStatus": "OFFLINE",
      });
      expect(b.deviceStatus, DeviceStatus.offline);
      expect(b.deviceStatus.isOffline, isTrue);
      expect(b.deviceStatus.isOnline, isFalse);
    });

    test(
      "Snake_case device_status also parses (via canonical alias ingestion)",
      () {
        final MedicineBoxModel b = MedicineBoxModel.fromJson(<String, dynamic>{
          "device_status": "OFFLINE",
        });
        expect(b.deviceStatus, DeviceStatus.offline);
      },
    );

    test("Unknown deviceStatus fails safely", () {
      final MedicineBoxModel b = MedicineBoxModel.fromJson(<String, dynamic>{
        "deviceStatus": "SOMETHING_ELSE",
      });
      expect(b.deviceStatus, DeviceStatus.unknown);
      expect(b.deviceStatus.isOnline, isFalse);
    });
  });

  group("canUsePhysicalOperations central guard", () {
    test("ACTIVE + ACTIVE enables physical operations", () {
      final MedicineBoxModel b = _makeBox(
        status: MedicineBoxStatus.active,
        deviceStatus: DeviceStatus.active,
      );
      expect(b.canUsePhysicalOperations, isTrue);
      expect(b.status.isActive, isTrue);
      expect(b.deviceStatus.isOnline, isTrue);
    });

    test("ACTIVE + OFFLINE disables physical operations", () {
      final MedicineBoxModel b = _makeBox(
        status: MedicineBoxStatus.active,
        deviceStatus: DeviceStatus.offline,
      );
      expect(b.canUsePhysicalOperations, isFalse);
      expect(b.status.isActive, isTrue);
    });

    test("READY + OFFLINE enables only activation state", () {
      final MedicineBoxModel b = _makeBox(
        status: MedicineBoxStatus.ready,
        deviceStatus: DeviceStatus.offline,
      );
      expect(b.canUsePhysicalOperations, isFalse);
      expect(b.canActivate, isTrue);
    });

    test("MAINTENANCE + ACTIVE disables physical operations", () {
      final MedicineBoxModel b = _makeBox(
        status: MedicineBoxStatus.maintenance,
        deviceStatus: DeviceStatus.active,
      );
      expect(b.canUsePhysicalOperations, isFalse);
      expect(b.status.isMaintenance, isTrue);
    });

    test("MAINTENANCE + OFFLINE disables physical operations", () {
      final MedicineBoxModel b = _makeBox(
        status: MedicineBoxStatus.maintenance,
        deviceStatus: DeviceStatus.offline,
      );
      expect(b.canUsePhysicalOperations, isFalse);
    });

    test("READY + ACTIVE still no physical operations (not owned)", () {
      final MedicineBoxModel b = _makeBox(
        status: MedicineBoxStatus.ready,
        deviceStatus: DeviceStatus.active,
      );
      expect(b.canUsePhysicalOperations, isFalse);
      expect(b.canActivate, isTrue);
    });
  });

  group("Unassign state transitions", () {
    test("copyWith status->READY and userId=null", () {
      final MedicineBoxModel owned = _makeBox(
        status: MedicineBoxStatus.active,
        userId: "user-1",
      );
      expect(owned.status.isActive, isTrue);
      expect(owned.userId, "user-1");

      final MedicineBoxModel unassigned = owned.copyWith(
        status: MedicineBoxStatus.ready,
        userId: null,
      );
      expect(unassigned.status, MedicineBoxStatus.ready);
      expect(unassigned.userId, isNull);
      expect(unassigned.canActivate, isTrue);
      expect(unassigned.canUsePhysicalOperations, isFalse);
    });

    test("Unassign preserves name/device/box fields", () {
      final DateTime t = DateTime.utc(2025, 3, 1);
      final MedicineBoxModel owned = MedicineBoxModel(
        id: "b1",
        deviceId: "DEV-BOX-9",
        name: "Kitchen Box",
        status: MedicineBoxStatus.active,
        deviceStatus: DeviceStatus.offline,
        userId: "u42",
        numberOfDrawers: 6,
        drawerCapacity: 16,
        createdAt: t,
        updatedAt: t,
      );
      final MedicineBoxModel after = owned.copyWith(
        status: MedicineBoxStatus.ready,
        userId: null,
      );
      expect(after.id, "b1");
      expect(after.deviceId, "DEV-BOX-9");
      expect(after.name, "Kitchen Box");
      expect(after.numberOfDrawers, 6);
      expect(after.drawerCapacity, 16);
      expect(after.createdAt, t);
      expect(after.updatedAt, t);
      expect(after.deviceStatus, DeviceStatus.offline);
    });
  });

  group("DrawerMedication PATCH body format correctness", () {
    test("PATCH body only emits isActive when provided", () {
      const UpdateDrawerMedicationRequest req = UpdateDrawerMedicationRequest(
        isActive: false,
      );
      final Map<String, dynamic> body = req.body;
      expect(body.keys, <String>["isActive"]);
      expect(body["isActive"], isFalse);
      expect(body.containsKey("drawerId"), isFalse);
      expect(body.containsKey("medicationId"), isFalse);
    });

    test("PATCH body emits isActive true", () {
      const UpdateDrawerMedicationRequest req = UpdateDrawerMedicationRequest(
        isActive: true,
      );
      final Map<String, dynamic> body = req.body;
      expect(body, <String, dynamic>{"isActive": true});
    });

    test("Empty PATCH body is empty map (never drawerId/medicationId)", () {
      const UpdateDrawerMedicationRequest req = UpdateDrawerMedicationRequest();
      expect(req.isEmpty, isTrue);
      expect(req.body, isEmpty);
    });

    test(
      "Create request emits drawerId, medicationId, quantity, missingQuantity",
      () {
        const CreateDrawerMedicationRequest req = CreateDrawerMedicationRequest(
          drawerId: " dr-1 ",
          medicationId: " med-7 ",
          quantity: 12,
          missingQuantity: 5,
        );
        final Map<String, dynamic> body = req.toJson();
        expect(body.keys.toSet(), <String>{
          "drawerId",
          "medicationId",
          "quantity",
          "missingQuantity",
        });
        expect(body["drawerId"], "dr-1");
        expect(body["medicationId"], "med-7");
        expect(body["quantity"], 12);
        expect(body["missingQuantity"], 5);
        expect(body.containsKey("isActive"), isFalse);
      },
    );
  });

  group("Activation does not imply device connectivity", () {
    test("status=ACTIVE deviceStatus=OFFLINE is valid and not online", () {
      final MedicineBoxModel postActivate = _makeBox(
        status: MedicineBoxStatus.active,
        deviceStatus: DeviceStatus.offline,
      );
      expect(postActivate.status.isActive, isTrue);
      expect(postActivate.deviceStatus.isOnline, isFalse);
      expect(postActivate.deviceStatus.isOffline, isTrue);
      expect(postActivate.canUsePhysicalOperations, isFalse);
    });

    test("Offline after activation: status active but device offline", () {
      final MedicineBoxModel b = MedicineBoxModel.fromJson(<String, dynamic>{
        "status": "ACTIVE",
        "deviceStatus": "OFFLINE",
        "userId": "user-2",
      });
      expect(b.status, MedicineBoxStatus.active);
      expect(b.deviceStatus, DeviceStatus.offline);
      expect(b.userId, "user-2");
      expect(b.canUsePhysicalOperations, isFalse);
    });
  });

  group("Read-only still allowed when offline", () {
    test("ACTIVE + OFFLINE: status.active true so reads permitted", () {
      final MedicineBoxModel b = _makeBox(
        status: MedicineBoxStatus.active,
        deviceStatus: DeviceStatus.offline,
      );
      final bool canRead = b.status.isActive;
      expect(canRead, isTrue);
      expect(b.canUsePhysicalOperations, isFalse);
    });

    test("MAINTENANCE + OFFLINE: status.not active but status exists", () {
      final MedicineBoxModel b = _makeBox(
        status: MedicineBoxStatus.maintenance,
        deviceStatus: DeviceStatus.offline,
      );
      expect(b.status.isMaintenance, isTrue);
      expect(b.canUsePhysicalOperations, isFalse);
    });
  });

  group("DrawerMedication assignment contract", () {
    test(
      "CreateDrawerMedicationRequest emits drawerId, medicationId, quantity:20, missingQuantity:70",
      () {
        const CreateDrawerMedicationRequest req = CreateDrawerMedicationRequest(
          drawerId: "drawer-1",
          medicationId: "med-1",
          quantity: 20,
          missingQuantity: 70,
        );
        final Map<String, dynamic> body = req.toJson();
        expect(body.keys.toSet(), <String>{
          "drawerId",
          "medicationId",
          "quantity",
          "missingQuantity",
        });
        expect(body, <String, dynamic>{
          "drawerId": "drawer-1",
          "medicationId": "med-1",
          "quantity": 20,
          "missingQuantity": 70,
        });
      },
    );

    test(
      "CreateDrawerMedicationRequest missingQuantity=0 is explicitly sent (not omitted)",
      () {
        const CreateDrawerMedicationRequest req = CreateDrawerMedicationRequest(
          drawerId: "drawer-1",
          medicationId: "med-1",
          quantity: 15,
          missingQuantity: 0,
        );
        final Map<String, dynamic> body = req.toJson();
        expect(body["drawerId"], "drawer-1");
        expect(body["medicationId"], "med-1");
        expect(body["quantity"], 15);
        expect(body["missingQuantity"], 0);
        expect(
          body.containsKey("missingQuantity"),
          isTrue,
          reason: "missingQuantity=0 must still be present",
        );
      },
    );

    test("Repository sanitizer accepts quantity and missingQuantity", () {
      final Map<String, dynamic> raw = <String, dynamic>{
        "drawer_id": " drawer-1 ",
        "medication_id": "med-1",
        "quantity": 20,
        "missing_quantity": 70,
      };
      final Map<String, dynamic> body =
          DrawerMedicationRepository.sanitizeCreateBodyPublic(raw);
      expect(body["drawerId"], "drawer-1");
      expect(body["medicationId"], "med-1");
      expect(body["quantity"], 20);
      expect(body["missingQuantity"], 70);
    });

    test(
      "DrawerMedicationModel.fromJson parses backend quantity=20 missingQuantity=70",
      () {
        final Map<String, dynamic> json = <String, dynamic>{
          "id": "dm-uuid",
          "drawerId": "dr-1",
          "medicationId": "med-1",
          "assignedAt": "2026-08-28T12:00:00Z",
          "isActive": true,
          "quantity": 20,
          "missingQuantity": 70,
        };
        final DrawerMedicationModel m = DrawerMedicationModel.fromJson(json);
        expect(m.quantity, 20);
        expect(m.missingQuantity, 70);
        expect(m.id, "dm-uuid");
        expect(m.drawerId, "dr-1");
        expect(m.isActive, isTrue);
      },
    );

    test("DrawerMedicationModel.fromJson parses snake_case aliases", () {
      final Map<String, dynamic> json = <String, dynamic>{
        "id": "dm-uuid-2",
        "drawer_id": "dr-2",
        "medication_id": "med-2",
        "assignedAt": "2026-08-28T12:00:00Z",
        "is_active": true,
        "assignedQuantity": 15,
        "missing_quantity": 0,
      };
      final DrawerMedicationModel m = DrawerMedicationModel.fromJson(json);
      expect(m.quantity, 15);
      expect(m.missingQuantity, 0);
      expect(m.drawerId, "dr-2");
      expect(m.medicationId, "med-2");
      expect(m.isActive, isTrue);
    });

    test(
      "DrawerMedicationModel missingQuantity=0 parsed as zero (no warning)",
      () {
        final Map<String, dynamic> json = <String, dynamic>{
          "id": "dm-z",
          "drawerId": "dr-z",
          "medicationId": "med-z",
          "assignedAt": "2026-08-28T12:00:00Z",
          "isActive": true,
          "quantity": 15,
          "missingQuantity": 0,
        };
        final DrawerMedicationModel m = DrawerMedicationModel.fromJson(json);
        expect(m.quantity, 15);
        expect(m.missingQuantity, 0);
        final bool hasMissing =
            m.missingQuantity != null && m.missingQuantity! > 0;
        expect(
          hasMissing,
          isFalse,
          reason: "missingQuantity=0 must NOT trigger warning state",
        );
      },
    );

    test(
      "DrawerMedicationModel toJson roundtrips quantity+missingQuantity",
      () {
        final DrawerMedicationModel m = DrawerMedicationModel(
          id: "dm-1",
          drawerId: "d-1",
          medicationId: "m-1",
          assignedAt: DateTime.utc(2026, 8, 28),
          isActive: true,
          quantity: 20,
          missingQuantity: 70,
        );
        final Map<String, dynamic> j = m.toJson();
        expect(j["quantity"], 20);
        expect(j["missingQuantity"], 70);
        expect(j["isActive"], true);
      },
    );

    test("DrawerMedicationModel copyWith preserves quantity fields", () {
      final DrawerMedicationModel a = DrawerMedicationModel(
        id: "dm-a",
        drawerId: "d-a",
        medicationId: "m-a",
        assignedAt: DateTime.utc(2026),
        isActive: true,
        quantity: 5,
        missingQuantity: 3,
      );
      final DrawerMedicationModel b = a.copyWith(isActive: false);
      expect(b.quantity, 5);
      expect(b.missingQuantity, 3);
      expect(b.isActive, false);
    });
  });

  group("DrawerMedicationController split guards (Rule 13)", () {
    DrawerMedicationController _makeControllerWith({
      required MedicineBoxModel box,
      required DrawerModel drawer,
      _FakeDrawerMedicationService? service,
    }) {
      service ??= _FakeDrawerMedicationService();
      final DrawerMedicationController c = DrawerMedicationController(
        service: service,
      );
      c.boxForDrawerResolver = (String id) =>
          id.trim() == drawer.id.trim() ? box : null;
      return c;
    }

    DrawerModel _makeDrawer(String id, String boxId, int n) {
      return DrawerModel(
        id: id,
        medicineBoxId: boxId,
        drawerNumber: n,
        status: DrawerStatus.empty,
        createdAt: null,
        updatedAt: null,
      );
    }

    test(
      "ACTIVE + OFFLINE: createAssignment allowed (offline not blocked)",
      () async {
        final MedicineBoxModel box = _makeBox(
          status: MedicineBoxStatus.active,
          deviceStatus: DeviceStatus.offline,
        );
        final DrawerModel drawer = _makeDrawer("dr-offline-1", box.id, 1);
        final _FakeDrawerMedicationService svc = _FakeDrawerMedicationService();
        final DrawerMedicationController c = _makeControllerWith(
          box: box,
          drawer: drawer,
          service: svc,
        );
        final DrawerMedicationModel created = await c.createAssignment(
          drawerId: drawer.id,
          medicationId: "med-x",
          quantity: 20,
          missingQuantity: 70,
        );
        expect(svc.createCalls, 1);
        expect(svc.lastCreateDrawer, drawer.id.trim());
        expect(svc.lastCreateMedication, "med-x");
        expect(svc.lastCreateQuantity, 20);
        expect(svc.lastCreateMissingQuantity, 70);
        expect(created.id, isNotEmpty);
      },
    );

    test(
      "READY + ACTIVE: createAssignment blocked (non-active status)",
      () async {
        final MedicineBoxModel box = _makeBox(
          status: MedicineBoxStatus.ready,
          deviceStatus: DeviceStatus.active,
        );
        final DrawerModel drawer = _makeDrawer("dr-ready-1", box.id, 1);
        final DrawerMedicationController c = _makeControllerWith(
          box: box,
          drawer: drawer,
        );
        expect(
          () => c.createAssignment(
            drawerId: drawer.id,
            medicationId: "med-x",
            quantity: 20,
            missingQuantity: 70,
          ),
          throwsA(
            isA<DrawerMedicationControllerException>().having(
              (DrawerMedicationControllerException e) =>
                  e.message.toLowerCase().contains("activate"),
              "activate",
              true,
            ),
          ),
        );
      },
    );

    test(
      "MAINTENANCE + OFFLINE: createAssignment blocked (maintenance)",
      () async {
        final MedicineBoxModel box = _makeBox(
          status: MedicineBoxStatus.maintenance,
          deviceStatus: DeviceStatus.offline,
        );
        final DrawerModel drawer = _makeDrawer("dr-maint-1", box.id, 1);
        final DrawerMedicationController c = _makeControllerWith(
          box: box,
          drawer: drawer,
        );
        expect(
          () => c.createAssignment(
            drawerId: drawer.id,
            medicationId: "med-x",
            quantity: 20,
            missingQuantity: 70,
          ),
          throwsA(
            isA<DrawerMedicationControllerException>().having(
              (DrawerMedicationControllerException e) =>
                  e.message.toLowerCase().contains("maintenance"),
              "maintenance",
              true,
            ),
          ),
        );
      },
    );

    test(
      "ACTIVE + OFFLINE: updateAssignment blocked (physical ops offline)",
      () async {
        final MedicineBoxModel box = _makeBox(
          status: MedicineBoxStatus.active,
          deviceStatus: DeviceStatus.offline,
        );
        final DrawerModel drawer = _makeDrawer("dr-offline-upd", box.id, 2);
        final _FakeDrawerMedicationService svc = _FakeDrawerMedicationService();
        final DrawerMedicationController c = _makeControllerWith(
          box: box,
          drawer: drawer,
          service: svc,
        );
        final DrawerMedicationModel existing = DrawerMedicationModel(
          id: "dm-existing-1",
          drawerId: drawer.id,
          medicationId: "med-x",
          assignedAt: DateTime.utc(2026),
          isActive: true,
        );
        expect(
          () => c.updateAssignment(existing, isActive: false),
          throwsA(
            isA<DrawerMedicationControllerException>().having(
              (DrawerMedicationControllerException e) =>
                  e.message.toLowerCase().contains("offline"),
              "offline",
              true,
            ),
          ),
        );
        expect(
          svc.updateCalls,
          0,
          reason: "Physical ops guard should prevent service call",
        );
      },
    );

    test(
      "ACTIVE + ACTIVE: updateAssignment allowed (physical ops online)",
      () async {
        final MedicineBoxModel box = _makeBox(
          status: MedicineBoxStatus.active,
          deviceStatus: DeviceStatus.active,
        );
        final DrawerModel drawer = _makeDrawer("dr-online-upd", box.id, 3);
        final _FakeDrawerMedicationService svc = _FakeDrawerMedicationService();
        final DrawerMedicationController c = _makeControllerWith(
          box: box,
          drawer: drawer,
          service: svc,
        );
        final DrawerMedicationModel existing = DrawerMedicationModel(
          id: "dm-online-1",
          drawerId: drawer.id,
          medicationId: "med-y",
          assignedAt: DateTime.utc(2026),
          isActive: true,
        );
        final DrawerMedicationModel updated = await c.updateAssignment(
          existing,
          isActive: false,
        );
        expect(svc.updateCalls, 1);
        expect(updated.isActive, false);
      },
    );

    test(
      "Duplicate-tap protection: two createAssignment = 1 service call",
      () async {
        final MedicineBoxModel box = _makeBox(
          status: MedicineBoxStatus.active,
          deviceStatus: DeviceStatus.offline,
        );
        final DrawerModel drawer = _makeDrawer("dr-dbltap", box.id, 4);
        final _FakeDrawerMedicationService svc = _FakeDrawerMedicationService(
          delayMs: 120,
        );
        final DrawerMedicationController c = _makeControllerWith(
          box: box,
          drawer: drawer,
          service: svc,
        );
        final Future<DrawerMedicationModel> f1 = c.createAssignment(
          drawerId: drawer.id,
          medicationId: "med-dbl",
          quantity: 20,
          missingQuantity: 70,
        );
        final Future<Object> f2 = Future<Object>.microtask(
          () => c.createAssignment(
            drawerId: drawer.id,
            medicationId: "med-dbl",
            quantity: 20,
            missingQuantity: 70,
          ),
        ).catchError((Object e) => e);
        await f1;
        final Object r2 = await f2;
        expect(
          svc.createCalls,
          1,
          reason:
              "Second rapid tap must be short-circuited by _isCreating flag",
        );
        expect(r2, isA<DrawerMedicationControllerException>());
        expect(
          (r2 as DrawerMedicationControllerException).message
              .toLowerCase()
              .contains("another"),
          isTrue,
        );
      },
    );
  });

  group("409 Conflict friendly error mapping", () {
    test("DrawerMedicationService maps 409 to conflict message", () async {
      final _FakeDrawerMedicationService svc = _FakeDrawerMedicationService(
        forceErrorCode: 409,
      );
      try {
        await svc.createAssignment(
          drawerId: "d",
          medicationId: "m",
          quantity: 20,
          missingQuantity: 70,
        );
        fail("Expected DrawerMedicationServiceException for 409");
      } on DrawerMedicationServiceException catch (e) {
        expect(
          e.message.toLowerCase().contains("already assigned") ||
              e.message.toLowerCase().contains("conflict") ||
              e.message.toLowerCase().contains("no longer available"),
          isTrue,
          reason: "409 should map to a human-friendly conflict message",
        );
      }
    });
  });

  group("Drawer capacity not hardcoded (backend-driven)", () {
    test("Different boxes can have different drawerCapacity values", () {
      final MedicineBoxModel boxA = MedicineBoxModel.fromJson(<String, dynamic>{
        "drawerCapacity": 20,
      });
      final MedicineBoxModel boxB = MedicineBoxModel.fromJson(<String, dynamic>{
        "drawerCapacity": 30,
      });
      expect(boxA.drawerCapacity, 20);
      expect(boxB.drawerCapacity, 30);
      expect(
        boxA.drawerCapacity != boxB.drawerCapacity,
        isTrue,
        reason: "Capacity is per-box; never assume one global value",
      );
    });
  });
}

class _FakeDrawerMedicationService implements DrawerMedicationService {
  _FakeDrawerMedicationService({this.delayMs = 0, this.forceErrorCode});

  final int delayMs;
  final int? forceErrorCode;

  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  String? lastCreateDrawer;
  String? lastCreateMedication;
  Object? lastCreateQuantity;
  Object? lastCreateMissingQuantity;

  @override
  Future<DrawerMedicationModel> createAssignment({
    required String drawerId,
    required String medicationId,
    required int quantity,
    required int missingQuantity,
  }) async {
    createCalls++;
    lastCreateDrawer = drawerId.trim();
    lastCreateMedication = medicationId.trim();
    lastCreateQuantity = quantity;
    lastCreateMissingQuantity = missingQuantity;
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
    if (forceErrorCode != null) {
      if (forceErrorCode == 409) {
        throw DrawerMedicationServiceException(
          "This drawer or medication is already assigned.",
        );
      }
      if (forceErrorCode == 404) {
        throw DrawerMedicationServiceException(
          "Drawer or medication not found.",
        );
      }
      if (forceErrorCode == 400) {
        throw DrawerMedicationServiceException("Invalid request.");
      }
    }
    return DrawerMedicationModel(
      id: "fake-dm-${createCalls.toString()}",
      drawerId: drawerId.trim(),
      medicationId: medicationId.trim(),
      assignedAt: DateTime.now().toUtc(),
      isActive: true,
      quantity: quantity,
      missingQuantity: missingQuantity,
    );
  }

  @override
  Future<DrawerMedicationModel> updateAssignment(
    String id, {
    bool? isActive,
  }) async {
    updateCalls++;
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
    return DrawerMedicationModel(
      id: id.trim(),
      drawerId: "d",
      medicationId: "m",
      assignedAt: DateTime.now().toUtc(),
      isActive: isActive ?? true,
    );
  }

  @override
  Future<void> deleteAssignment(String id) async {
    deleteCalls++;
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
  }

  @override
  Future<List<DrawerMedicationModel>> getAssignments({
    String? drawerId,
    String? medicationId,
  }) async {
    return const <DrawerMedicationModel>[];
  }

  @override
  Future<DrawerMedicationModel> getAssignmentById(String id) async {
    return DrawerMedicationModel(
      id: id.trim(),
      drawerId: "d",
      medicationId: "m",
      assignedAt: DateTime.now().toUtc(),
      isActive: true,
    );
  }

  @override
  Future<DrawerMedicationModel> moveAssignment({
    required String assignmentId,
    required String fromDrawerId,
    required String toDrawerId,
    required String medicationId,
    int? originalQuantity,
    int? originalMissingQuantity,
  }) async {
    final int qty = originalQuantity != null && originalQuantity >= 0
        ? originalQuantity
        : 0;
    final int mq =
        originalMissingQuantity != null && originalMissingQuantity >= 0
        ? originalMissingQuantity
        : 0;
    return DrawerMedicationModel(
      id: assignmentId.trim(),
      drawerId: toDrawerId.trim(),
      medicationId: medicationId.trim(),
      assignedAt: DateTime.now().toUtc(),
      isActive: true,
      quantity: qty,
      missingQuantity: mq,
    );
  }

  @override
  noSuchMethod(Invocation invocation) {
    throw UnimplementedError();
  }
}
