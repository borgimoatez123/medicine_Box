import "package:flutter_test/flutter_test.dart";
import "package:smart_medicine_app/models/medication_event_model.dart";

void main() {
  group("MedicationEventModel.fromJson", () {
    test("parses the full example response correctly", () {
      final Map<String, dynamic> json = <String, dynamic>{
        "id": "d5f5c378-4bd4-4250-993a-f5f2eef32974",
        "deviceId": "DEV-BOX-zQL2QCn",
        "patientId": "c5a4277e-0950-4bd6-aa2d-02e883965347",
        "scheduleId": "6247993e-e75a-4c92-abdb-d5f483227a48",
        "drawerId": "c77a90f8-a493-4985-89fc-12b058083558",
        "medicationId": "94c14b77-809f-4b0c-9648-9e1d82a91a81",
        "status": "TAKEN",
        "quantityTaken": 1,
        "quantityBefore": 10,
        "quantityAfter": 9,
        "scheduledAt": "2026-10-13T05:10:00.000Z",
        "completedAt": "2026-10-13T05:10:11.608Z",
        "createdAt": "2026-10-13T05:10:00.000Z",
        "occurrenceDate": "2026-10-12",
        "occurrenceTime": "06:10",
      };

      final MedicationEventModel e = MedicationEventModel.fromJson(json);

      expect(e.id, "d5f5c378-4bd4-4250-993a-f5f2eef32974");
      expect(e.deviceId, "DEV-BOX-zQL2QCn");
      expect(e.patientId, "c5a4277e-0950-4bd6-aa2d-02e883965347");
      expect(e.scheduleId, "6247993e-e75a-4c92-abdb-d5f483227a48");
      expect(e.drawerId, "c77a90f8-a493-4985-89fc-12b058083558");
      expect(e.medicationId, "94c14b77-809f-4b0c-9648-9e1d82a91a81");
      expect(e.status, "TAKEN");
      expect(e.quantityTaken, 1);
      expect(e.quantityBefore, 10);
      expect(e.quantityAfter, 9);
      expect(e.scheduledAt, isNotNull);
      expect(e.completedAt, isNotNull);
      expect(e.occurrenceDate, "2026-10-12");
      expect(e.occurrenceTime, "06:10");
    });

    test("handles all-null optional fields without throwing", () {
      final MedicationEventModel e = MedicationEventModel.fromJson(
        <String, dynamic>{"id": "evt-1", "status": "TAKEN"},
      );

      expect(e.id, "evt-1");
      expect(e.deviceId, isNull);
      expect(e.patientId, isNull);
      expect(e.scheduleId, isNull);
      expect(e.drawerId, isNull);
      expect(e.medicationId, isNull);
      expect(e.quantityTaken, isNull);
      expect(e.quantityBefore, isNull);
      expect(e.quantityAfter, isNull);
      expect(e.scheduledAt, isNull);
      expect(e.completedAt, isNull);
      expect(e.createdAt, isNull);
      expect(e.occurrenceDate, isNull);
      expect(e.occurrenceTime, isNull);
    });

    test("supports snake_case alias keys", () {
      final MedicationEventModel e = MedicationEventModel.fromJson(
        <String, dynamic>{
          "id": "evt-2",
          "device_id": "DEV-1",
          "patient_id": "p-1",
          "medication_id": "m-1",
          "quantity_taken": 2,
          "quantity_before": 20,
          "quantity_after": 18,
          "scheduled_at": "2026-10-01T08:00:00.000Z",
          "completed_at": "2026-10-01T08:05:00.000Z",
          "status": "MISSED",
        },
      );

      expect(e.deviceId, "DEV-1");
      expect(e.patientId, "p-1");
      expect(e.medicationId, "m-1");
      expect(e.quantityTaken, 2);
      expect(e.quantityBefore, 20);
      expect(e.quantityAfter, 18);
      expect(e.status, "MISSED");
      expect(e.scheduledAt, isNotNull);
      expect(e.completedAt, isNotNull);
    });

    test("parses numeric strings for quantities", () {
      final MedicationEventModel e = MedicationEventModel.fromJson(
        <String, dynamic>{
          "id": "evt-3",
          "status": "TAKEN",
          "quantityTaken": "3",
          "quantityBefore": "15",
          "quantityAfter": "12",
        },
      );

      expect(e.quantityTaken, 3);
      expect(e.quantityBefore, 15);
      expect(e.quantityAfter, 12);
    });
  });

  group("MedicationEventStatus mapping", () {
    test("TAKEN maps to taken status with taken label", () {
      final MedicationEventModel e = MedicationEventModel.fromJson(
        <String, dynamic>{"id": "evt", "status": "TAKEN"},
      );
      expect(e.eventStatus, MedicationEventStatus.taken);
      expect(e.isTaken, isTrue);
      expect(e.isAlert, isFalse);
      expect(e.isHistoryTaken, isTrue);
      expect(e.eventStatus.label, "Medication recorded as taken");
    });

    test("MISSED maps to missed and is treated as an alert", () {
      final MedicationEventModel e = MedicationEventModel.fromJson(
        <String, dynamic>{"id": "evt", "status": "MISSED"},
      );
      expect(e.eventStatus, MedicationEventStatus.missed);
      expect(e.isAlert, isTrue);
      expect(e.eventStatus.label, "Missed medication");
    });

    test("PENDING maps to pending and is NOT an alert", () {
      final MedicationEventModel e = MedicationEventModel.fromJson(
        <String, dynamic>{"id": "evt", "status": "PENDING"},
      );
      expect(e.eventStatus, MedicationEventStatus.pending);
      expect(e.isAlert, isFalse);
      expect(e.eventStatus.label, "Pending");
    });

    test("unknown status falls back to unknown without crashing", () {
      final MedicationEventModel e = MedicationEventModel.fromJson(
        <String, dynamic>{"id": "evt", "status": "WHATEVER_NEW_STATUS"},
      );
      expect(e.eventStatus, MedicationEventStatus.unknown);
      expect(e.isAlert, isFalse);
      expect(e.eventStatus.label, "Unknown");
    });

    test("empty status does not crash", () {
      final MedicationEventModel e = MedicationEventModel.fromJson(
        <String, dynamic>{"id": "evt", "status": ""},
      );
      expect(e.eventStatus, MedicationEventStatus.unknown);
    });
  });

  group("parseMedicationEventListResponse", () {
    test("parses nested data.events + data.pagination", () {
      final Map<String, dynamic> response = <String, dynamic>{
        "status": "success",
        "statusCode": 200,
        "data": <String, dynamic>{
          "events": <Map<String, dynamic>>[
            <String, dynamic>{"id": "e1", "status": "TAKEN"},
            <String, dynamic>{"id": "e2", "status": "MISSED"},
          ],
          "pagination": <String, dynamic>{
            "limit": 20,
            "offset": 0,
            "total": 2,
          },
        },
      };

      final MedicationEventListResult result =
          parseMedicationEventListResponse(response);

      expect(result.events.length, 2);
      expect(result.events[0].id, "e1");
      expect(result.events[1].id, "e2");
      expect(result.pagination?.limit, 20);
      expect(result.pagination?.offset, 0);
      expect(result.pagination?.total, 2);
    });

    test("returns empty list for empty events array", () {
      final Map<String, dynamic> response = <String, dynamic>{
        "data": <String, dynamic>{
          "events": <dynamic>[],
          "pagination": <String, dynamic>{"limit": 20, "offset": 0, "total": 0},
        },
      };

      final MedicationEventListResult result =
          parseMedicationEventListResponse(response);

      expect(result.events, isEmpty);
      expect(result.pagination?.total, 0);
    });

    test("tolerates a top-level list response", () {
      final List<dynamic> response = <dynamic>[
        <String, dynamic>{"id": "e1", "status": "TAKEN"},
      ];

      final MedicationEventListResult result =
          parseMedicationEventListResponse(response);

      expect(result.events.length, 1);
      expect(result.pagination, isNull);
    });

    test("tolerates null / unexpected response without throwing", () {
      final MedicationEventListResult r1 =
          parseMedicationEventListResponse(null);
      final MedicationEventListResult r2 =
          parseMedicationEventListResponse("unexpected");
      final MedicationEventListResult r3 =
          parseMedicationEventListResponse(<String, dynamic>{});

      expect(r1.events, isEmpty);
      expect(r2.events, isEmpty);
      expect(r3.events, isEmpty);
    });
  });
}
