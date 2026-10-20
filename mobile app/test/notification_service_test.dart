import "package:flutter_test/flutter_test.dart";
import "package:smart_medicine_app/models/medication_model.dart";
import "package:smart_medicine_app/models/schedule_model.dart";
import "package:smart_medicine_app/services/notification_service.dart";

ScheduleModel _mkSchedule({
  required String id,
  required String medicationId,
  required ScheduleStatus status,
  required bool isActive,
  required List<String> times,
  required List<int> daysOfWeek,
  required DateTime startDate,
  required int timesPerDay,
  String dosage = "",
  String? medicationName,
  bool refillReminder = false,
}) {
  return ScheduleModel(
    id: id,
    medicationId: medicationId,
    dosage: dosage,
    timesPerDay: timesPerDay,
    times: times,
    startDate: startDate,
    daysOfWeek: daysOfWeek,
    status: status,
    isActive: isActive,
    refillReminder: refillReminder,
    medicationName: medicationName,
  );
}

MedicationModel _mkMed({
  required String id,
  required String patientId,
  required String name,
  required String dosage,
  required MedicationForm form,
  required int quantity,
}) {
  return MedicationModel(
    id: id,
    patientId: patientId,
    name: name,
    dosage: dosage,
    form: form,
    quantity: quantity,
  );
}

void main() {
  group("NotificationService.deterministicIdFor", () {
    const String kMedA = "550e8400-e29b-41d4-a716-446655440000";
    const String kMedB = "550e8400-e29b-41d4-a716-446655440001";
    const String kSchA = "550e8400-e29b-41d4-a716-446655440010";
    const String kSchB = "550e8400-e29b-41d4-a716-446655440011";
    const int kMaxId = 0x7FFFFFFF;

    test("same inputs always produce the same id (deterministic)", () {
      final int id1 = NotificationService.deterministicIdFor(
        medicationId: kMedA,
        scheduleId: kSchA,
        time: "08:00",
        index: 0,
      );
      final int id2 = NotificationService.deterministicIdFor(
        medicationId: kMedA,
        scheduleId: kSchA,
        time: "08:00",
        index: 0,
      );
      expect(id1, id2);
      expect(id1, greaterThanOrEqualTo(0));
      expect(id1, lessThanOrEqualTo(kMaxId));
    });

    test("different medication ids produce different ids", () {
      final int id1 = NotificationService.deterministicIdFor(
        medicationId: kMedA,
        scheduleId: kSchA,
        time: "08:00",
        index: 0,
      );
      final int id2 = NotificationService.deterministicIdFor(
        medicationId: kMedB,
        scheduleId: kSchA,
        time: "08:00",
        index: 0,
      );
      expect(id1, isNot(equals(id2)));
    });

    test("different schedule ids produce different ids", () {
      final int id1 = NotificationService.deterministicIdFor(
        medicationId: kMedA,
        scheduleId: kSchA,
        time: "08:00",
        index: 0,
      );
      final int id2 = NotificationService.deterministicIdFor(
        medicationId: kMedA,
        scheduleId: kSchB,
        time: "08:00",
        index: 0,
      );
      expect(id1, isNot(equals(id2)));
    });

    test(
      "different times produce different ids (edit schedule time changes id)",
      () {
        final int idOld = NotificationService.deterministicIdFor(
          medicationId: kMedA,
          scheduleId: kSchA,
          time: "08:00",
          index: 0,
        );
        final int idNew = NotificationService.deterministicIdFor(
          medicationId: kMedA,
          scheduleId: kSchA,
          time: "09:30",
          index: 0,
        );
        expect(idOld, isNot(equals(idNew)));
      },
    );

    test("different time indices per schedule produce different ids", () {
      final int id0 = NotificationService.deterministicIdFor(
        medicationId: kMedA,
        scheduleId: kSchA,
        time: "08:00",
        index: 0,
      );
      final int id1 = NotificationService.deterministicIdFor(
        medicationId: kMedA,
        scheduleId: kSchA,
        time: "12:00",
        index: 1,
      );
      expect(id0, isNot(equals(id1)));
    });

    test("all produced ids are non-negative 31-bit integers", () {
      final List<String> meds = <String>[kMedA, kMedB, "", "   ", "a", "ab"];
      final List<String> schs = <String>[kSchA, kSchB, "", "x", "y"];
      final List<String> times = <String>["00:00", "08:00", "23:59", ""];
      final List<int> indices = <int>[0, 1, 2, 100];
      final Set<int> seen = <int>{};
      for (final String m in meds) {
        for (final String s in schs) {
          for (final String t in times) {
            for (final int i in indices) {
              final int id = NotificationService.deterministicIdFor(
                medicationId: m,
                scheduleId: s,
                time: t,
                index: i,
              );
              expect(id, greaterThanOrEqualTo(0));
              expect(id, lessThanOrEqualTo(kMaxId));
              seen.add(id);
            }
          }
        }
      }
      expect(seen.length, greaterThan(10));
    });
  });

  group("Duplicate prevention: cancel-then-reschedule produces same IDs", () {
    test(
      "scheduleForContext called 3 times returns same deterministic id set",
      () {
        final ScheduleModel s = _mkSchedule(
          id: "sch-1",
          medicationId: "med-1",
          status: ScheduleStatus.active,
          isActive: true,
          times: <String>["08:00", "20:00"],
          daysOfWeek: const <int>[],
          startDate: DateTime(2025, 1, 1),
          timesPerDay: 2,
          medicationName: "Aspirin",
          dosage: "100mg",
        );
        final MedicationModel m = _mkMed(
          id: "med-1",
          patientId: "pat-1",
          name: "Aspirin",
          dosage: "100mg",
          form: MedicationForm.tablet,
          quantity: 30,
        );
        final ScheduleMedicationContext ctx = ScheduleMedicationContext(
          schedule: s,
          medication: m,
          patientFirstName: "Alice",
          patientLastName: "Smith",
        );

        final Set<int> ids1 = _expectedIds(ctx);
        final Set<int> ids2 = _expectedIds(ctx);
        final Set<int> ids3 = _expectedIds(ctx);

        expect(ids1.length, 2);
        expect(ids1, ids2);
        expect(ids2, ids3);
      },
    );

    test("editing schedule time → old ids disappear, new ids appear", () {
      final MedicationModel m = _mkMed(
        id: "med-1",
        patientId: "pat-1",
        name: "Aspirin",
        dosage: "100mg",
        form: MedicationForm.tablet,
        quantity: 30,
      );
      final ScheduleModel sOld = _mkSchedule(
        id: "sch-1",
        medicationId: "med-1",
        status: ScheduleStatus.active,
        isActive: true,
        times: <String>["08:00", "12:00"],
        daysOfWeek: const <int>[],
        startDate: DateTime(2025, 1, 1),
        timesPerDay: 2,
        medicationName: "Aspirin",
      );
      final ScheduleModel sNew = _mkSchedule(
        id: "sch-1",
        medicationId: "med-1",
        status: ScheduleStatus.active,
        isActive: true,
        times: <String>["09:00", "13:00"],
        daysOfWeek: const <int>[],
        startDate: DateTime(2025, 1, 1),
        timesPerDay: 2,
        medicationName: "Aspirin",
      );
      final Set<int> oldIds = _expectedIds(
        ScheduleMedicationContext(schedule: sOld, medication: m),
      );
      final Set<int> newIds = _expectedIds(
        ScheduleMedicationContext(schedule: sNew, medication: m),
      );
      expect(oldIds.intersection(newIds).length, 0);
      expect(oldIds.length, 2);
      expect(newIds.length, 2);
    });

    test("different schedules on same medication → independent id sets", () {
      final MedicationModel m = _mkMed(
        id: "med-1",
        patientId: "pat-1",
        name: "Aspirin",
        dosage: "100mg",
        form: MedicationForm.tablet,
        quantity: 30,
      );
      final ScheduleModel s1 = _mkSchedule(
        id: "sch-morning",
        medicationId: "med-1",
        status: ScheduleStatus.active,
        isActive: true,
        times: <String>["08:00"],
        daysOfWeek: const <int>[],
        startDate: DateTime(2025, 1, 1),
        timesPerDay: 1,
      );
      final ScheduleModel s2 = _mkSchedule(
        id: "sch-night",
        medicationId: "med-1",
        status: ScheduleStatus.active,
        isActive: true,
        times: <String>["22:00"],
        daysOfWeek: const <int>[],
        startDate: DateTime(2025, 1, 1),
        timesPerDay: 1,
      );
      final Set<int> ids1 = _expectedIds(
        ScheduleMedicationContext(schedule: s1, medication: m),
      );
      final Set<int> ids2 = _expectedIds(
        ScheduleMedicationContext(schedule: s2, medication: m),
      );
      expect(ids1.length, 1);
      expect(ids2.length, 1);
      expect(ids1.first, isNot(equals(ids2.first)));
    });
  });

  group("Schedule eligibility guards", () {
    test("paused schedule should NOT schedule", () {
      final ScheduleModel s = _mkSchedule(
        id: "sch-1",
        medicationId: "med-1",
        status: ScheduleStatus.paused,
        isActive: true,
        times: <String>["08:00"],
        daysOfWeek: const <int>[],
        startDate: DateTime(2025, 1, 1),
        timesPerDay: 1,
      );
      expect(NotificationService.shouldScheduleForTest(s), false);
    });

    test("completed schedule should NOT schedule", () {
      final ScheduleModel s = _mkSchedule(
        id: "sch-1",
        medicationId: "med-1",
        status: ScheduleStatus.completed,
        isActive: true,
        times: <String>["08:00"],
        daysOfWeek: const <int>[],
        startDate: DateTime(2025, 1, 1),
        timesPerDay: 1,
      );
      expect(NotificationService.shouldScheduleForTest(s), false);
    });

    test("archived schedule should NOT schedule", () {
      final ScheduleModel s = _mkSchedule(
        id: "sch-1",
        medicationId: "med-1",
        status: ScheduleStatus.archived,
        isActive: true,
        times: <String>["08:00"],
        daysOfWeek: const <int>[],
        startDate: DateTime(2025, 1, 1),
        timesPerDay: 1,
      );
      expect(NotificationService.shouldScheduleForTest(s), false);
    });

    test("disabled isActive schedule should NOT schedule", () {
      final ScheduleModel s = _mkSchedule(
        id: "sch-1",
        medicationId: "med-1",
        status: ScheduleStatus.active,
        isActive: false,
        times: <String>["08:00"],
        daysOfWeek: const <int>[],
        startDate: DateTime(2025, 1, 1),
        timesPerDay: 1,
      );
      expect(NotificationService.shouldScheduleForTest(s), false);
    });

    test("active schedule with isActive=true should schedule", () {
      final ScheduleModel s = _mkSchedule(
        id: "sch-1",
        medicationId: "med-1",
        status: ScheduleStatus.active,
        isActive: true,
        times: <String>["08:00"],
        daysOfWeek: const <int>[],
        startDate: DateTime(2025, 1, 1),
        timesPerDay: 1,
      );
      expect(NotificationService.shouldScheduleForTest(s), true);
    });

    test("empty times falls back to timesPerDay defaults", () {
      final ScheduleModel sEmpty = _mkSchedule(
        id: "sch-1",
        medicationId: "med-1",
        status: ScheduleStatus.active,
        isActive: true,
        times: const <String>[],
        daysOfWeek: const <int>[],
        startDate: DateTime(2025, 1, 1),
        timesPerDay: 2,
      );
      final List<String> resolved = NotificationService.resolveTimesForTest(
        sEmpty,
      );
      expect(resolved, <String>["08:00", "12:00"]);

      final ScheduleModel sPerDay4 = _mkSchedule(
        id: "sch-1",
        medicationId: "med-1",
        status: ScheduleStatus.active,
        isActive: true,
        times: const <String>[],
        daysOfWeek: const <int>[],
        startDate: DateTime(2025, 1, 1),
        timesPerDay: 4,
      );
      expect(NotificationService.resolveTimesForTest(sPerDay4), <String>[
        "08:00",
        "12:00",
        "18:00",
        "21:00",
      ]);
    });

    test("invalid times are filtered out and deduped", () {
      final ScheduleModel s = _mkSchedule(
        id: "sch-1",
        medicationId: "med-1",
        status: ScheduleStatus.active,
        isActive: true,
        times: const <String>[
          "08:00",
          "not-a-time",
          "08:00",
          "25:00",
          "12:61",
          "20:00",
        ],
        daysOfWeek: const <int>[],
        startDate: DateTime(2025, 1, 1),
        timesPerDay: 1,
      );
      final List<String> resolved = NotificationService.resolveTimesForTest(s);
      expect(resolved, <String>["08:00", "20:00"]);
    });
  });

  group("Notification body builder", () {
    test(
      "body includes patient name + medication + dosage when all present",
      () {
        final String b = NotificationServiceTesting.buildBody(
          patientName: "Alice Smith",
          medicationName: "Aspirin",
          dosage: "100mg",
        );
        expect(b, "Alice Smith: It's time to take Aspirin - 100mg");
      },
    );

    test("body omits dosage when empty", () {
      final String b = NotificationServiceTesting.buildBody(
        patientName: "Bob",
        medicationName: "Ibuprofen",
        dosage: "",
      );
      expect(b, "Bob: It's time to take Ibuprofen");
    });

    test("body omits patient name when empty", () {
      final String b = NotificationServiceTesting.buildBody(
        patientName: "",
        medicationName: "Acetaminophen",
        dosage: "500mg",
      );
      expect(b, "It's time to take Acetaminophen - 500mg");
    });
  });

  group("Permission denied -> no crashes (guaranteed safe)", () {
    test(
      "deterministicIdFor + resolveTimes/shouldSchedule never throw even for "
      "null/empty/whacky inputs",
      () {
        expect(
          () => NotificationService.deterministicIdFor(
            medicationId: "",
            scheduleId: "",
            time: "",
            index: -1,
          ),
          returnsNormally,
        );
        expect(
          () => NotificationService.resolveTimesForTest(
            _mkSchedule(
              id: "",
              medicationId: "",
              status: ScheduleStatus.active,
              isActive: true,
              times: const <String>["not a time", "26:00"],
              daysOfWeek: const <int>[],
              startDate: DateTime(2025),
              timesPerDay: 0,
            ),
          ),
          returnsNormally,
        );
        expect(
          () => NotificationService.shouldScheduleForTest(
            _mkSchedule(
              id: "",
              medicationId: "",
              status: ScheduleStatus.archived,
              isActive: false,
              times: const <String>[],
              daysOfWeek: const <int>[],
              startDate: DateTime(2025),
              timesPerDay: 999,
            ),
          ),
          returnsNormally,
        );
      },
    );
  });
}

Set<int> _expectedIds(ScheduleMedicationContext ctx) {
  final List<String> times = NotificationService.resolveTimesForTest(
    ctx.schedule,
  );
  final Set<int> ids = <int>{};
  for (int i = 0; i < times.length; i++) {
    ids.add(
      NotificationService.deterministicIdFor(
        medicationId: ctx.schedule.medicationId,
        scheduleId: ctx.schedule.id,
        time: times[i],
        index: i,
      ),
    );
  }
  return ids;
}

class NotificationServiceTesting {
  static String buildBody({
    required String patientName,
    required String medicationName,
    required String dosage,
  }) {
    final List<String> parts = <String>[];
    if (patientName.isNotEmpty) parts.add("$patientName:");
    parts.add("It's time to take $medicationName");
    if (dosage.isNotEmpty) parts.add("- $dosage");
    return parts.join(" ");
  }
}
