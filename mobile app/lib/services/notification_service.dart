import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:timezone/data/latest_all.dart" as tzdata;
import "package:timezone/timezone.dart" as tz;

import "../data/local/shared_pref_service.dart";
import "../models/medication_model.dart";
import "../models/schedule_model.dart";

typedef NotificationTapHandler =
    void Function({
      required String type,
      String? medicationId,
      String? scheduleId,
      String? patientId,
    });

@immutable
class ScheduleMedicationContext {
  const ScheduleMedicationContext({
    required this.schedule,
    this.medication,
    this.patientFirstName,
    this.patientLastName,
  });

  final ScheduleModel schedule;
  final MedicationModel? medication;
  final String? patientFirstName;
  final String? patientLastName;

  String get patientFullName {
    final String first = (patientFirstName ?? "").trim();
    final String last = (patientLastName ?? "").trim();
    if (first.isEmpty && last.isEmpty) return "";
    if (first.isEmpty) return last;
    if (last.isEmpty) return first;
    return "$first $last";
  }
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  static const String kMedicationChannelId = "medication_reminders";
  static const String kMedicationChannelName = "Medication Reminders";
  static const String kMedicationChannelDescription =
      "Timed reminders to take scheduled medications";
  static const String kTapPermissionPromptedKey =
      "notification_permission_prompted_v1";

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  NotificationTapHandler? onTapHandler;

  bool _initialized = false;
  bool _timezoneInitialized = false;
  tz.Location? _localLocation;
  tz.Location get localLocation {
    final tz.Location? loc = _localLocation;
    if (loc == null) {
      throw StateError("NotificationService timezone not initialized");
    }
    return loc;
  }

  DateTime nowLocal() {
    _ensureTz();
    return tz.TZDateTime.now(localLocation);
  }

  Future<void> initialize({NotificationTapHandler? onTap}) async {
    if (_initialized) return;
    onTapHandler = onTap;
    await _initTimezone();
    await _initPlatform();
    _initialized = true;
  }

  Future<void> ensurePermissions() async {
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (android == null) return;
        final bool? granted = await android.requestNotificationsPermission();
        if (granted == true) return;
        final bool? exact = await android.requestExactAlarmsPermission();
        debugPrint(
          "[NotificationService] Permission state: notifications=$granted, "
          "exactAlarms=$exact",
        );
        return;
      }
      if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        if (ios == null) return;
        await ios.requestPermissions(alert: true, badge: true, sound: true);
        return;
      }
      if (Platform.isMacOS) {
        final MacOSFlutterLocalNotificationsPlugin? macos = _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
        if (macos == null) return;
        await macos.requestPermissions(alert: true, badge: true, sound: true);
        return;
      }
    } catch (e, st) {
      debugPrint("[NotificationService] ensurePermissions error: $e\n$st");
    }
  }

  Future<bool> shouldPromptForPermission() async {
    if (Platform.isIOS || Platform.isMacOS || Platform.isAndroid) {
      final String? prompted = await SharedPrefService.instance.getString(
        kTapPermissionPromptedKey,
      );
      if (prompted == "1") return false;
      return true;
    }
    return false;
  }

  Future<void> markPermissionPromptShown() {
    return SharedPrefService.instance.setString(kTapPermissionPromptedKey, "1");
  }

  Future<bool> areNotificationsEnabled() async {
    try {
      final NotificationAppLaunchDetails? details = await _plugin
          .getNotificationAppLaunchDetails();
      final bool didLaunch = details?.didNotificationLaunchApp ?? false;
      final bool hasResponse = details?.notificationResponse?.payload != null;
      if (didLaunch || hasResponse) return true;
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.areNotificationsEnabled() ?? true;
      }
      if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        if (ios == null) return true;
        try {
          // ignore: deprecated_member_use
          final bool? granted = await ios.requestPermissions(
            alert: false,
            badge: false,
            sound: false,
          );
          return granted ?? true;
        } catch (_) {
          return true;
        }
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> openAppSettings() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  Future<List<int>> scheduledMedicationNotificationIds() async {
    try {
      final List<PendingNotificationRequest> pending = await _plugin
          .pendingNotificationRequests();
      return pending
          .where(
            (PendingNotificationRequest r) =>
                r.payload != null &&
                _decode(r.payload!)["type"] == "medication_reminder",
          )
          .map((PendingNotificationRequest r) => r.id)
          .toList(growable: false);
    } catch (_) {
      return <int>[];
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<void> cancelMedication(String medicationId) async {
    final String mid = medicationId.trim();
    if (mid.isEmpty) return;
    try {
      final List<PendingNotificationRequest> pending = await _plugin
          .pendingNotificationRequests();
      final List<int> ids = <int>[];
      for (final PendingNotificationRequest r in pending) {
        if (r.payload == null) continue;
        final Map<String, dynamic> payload = _decode(r.payload!);
        if (payload["medicationId"]?.toString().trim() == mid) {
          ids.add(r.id);
        }
      }
      for (final int id in ids) {
        await _plugin.cancel(id);
      }
    } catch (e) {
      debugPrint("[NotificationService] cancelMedication error: $e");
    }
  }

  Future<void> cancelSchedule(String scheduleId) async {
    final String sid = scheduleId.trim();
    if (sid.isEmpty) return;
    try {
      final List<PendingNotificationRequest> pending = await _plugin
          .pendingNotificationRequests();
      for (final PendingNotificationRequest r in pending) {
        if (r.payload == null) continue;
        final Map<String, dynamic> payload = _decode(r.payload!);
        if (payload["scheduleId"]?.toString().trim() == sid) {
          await _plugin.cancel(r.id);
        }
      }
    } catch (e) {
      debugPrint("[NotificationService] cancelSchedule error: $e");
    }
  }

  Future<void> cancelScheduleTimes(
    String scheduleId,
    List<String> times,
  ) async {
    final String sid = scheduleId.trim();
    if (sid.isEmpty) return;
    try {
      final List<PendingNotificationRequest> pending = await _plugin
          .pendingNotificationRequests();
      for (final PendingNotificationRequest r in pending) {
        if (r.payload == null) continue;
        final Map<String, dynamic> payload = _decode(r.payload!);
        if (payload["scheduleId"]?.toString().trim() != sid) continue;
        final String? t = payload["time"]?.toString();
        if (t == null || !times.contains(t)) continue;
        await _plugin.cancel(r.id);
      }
    } catch (e) {
      debugPrint("[NotificationService] cancelScheduleTimes error: $e");
    }
  }

  Future<void> scheduleAll(
    List<ScheduleMedicationContext> contexts, {
    bool cancelStaleIdsNotInList = true,
  }) async {
    try {
      final Set<int> toKeep = <int>{};
      for (final ScheduleMedicationContext ctx in contexts) {
        final List<int> ids = await scheduleForContext(ctx);
        toKeep.addAll(ids);
      }
      if (cancelStaleIdsNotInList) {
        final List<PendingNotificationRequest> pending = await _plugin
            .pendingNotificationRequests();
        final List<int> stale = <int>[];
        for (final PendingNotificationRequest r in pending) {
          if (r.payload == null) continue;
          final Map<String, dynamic> payload = _decode(r.payload!);
          if (payload["type"] != "medication_reminder") continue;
          if (toKeep.contains(r.id)) continue;
          stale.add(r.id);
        }
        for (final int id in stale) {
          await _plugin.cancel(id);
        }
      }
    } catch (e, st) {
      debugPrint("[NotificationService] scheduleAll error: $e\n$st");
    }
  }

  Future<List<int>> scheduleForContext(ScheduleMedicationContext ctx) async {
    final ScheduleModel s = ctx.schedule;
    final List<int> createdIds = <int>[];
    if (!_shouldSchedule(s)) return createdIds;

    final MedicationModel? m = ctx.medication;
    final String medicationName = (m?.name ?? s.medicationName ?? "Medication")
        .trim();
    final String patientName = ctx.patientFullName;
    final String dosage = (s.dosage.isNotEmpty ? s.dosage : m?.dosage ?? "")
        .trim();

    final List<String> times = _resolveTimes(s);
    if (times.isEmpty) return createdIds;

    final String patientId = m?.patientId ?? "";

    for (int i = 0; i < times.length; i++) {
      final String hhmm = times[i];
      final tz.TZDateTime? next = _nextOccurrenceLocal(s, hhmm);
      if (next == null) continue;
      final int id = deterministicIdFor(
        medicationId: s.medicationId,
        scheduleId: s.id,
        time: hhmm,
        index: i,
      );
      final String title = "Medication Reminder";
      final String body = _buildBody(
        patientName: patientName,
        medicationName: medicationName,
        dosage: dosage,
      );
      final Map<String, String> payload = <String, String>{
        "type": "medication_reminder",
        "medicationId": s.medicationId,
        "scheduleId": s.id,
        "patientId": patientId,
        "time": hhmm,
        "timeIndex": i.toString(),
      };
      try {
        await _plugin.cancel(id);
        await _scheduleAt(id, title, body, next, payload);
        createdIds.add(id);
      } catch (e, st) {
        debugPrint(
          "[NotificationService] schedule failed id=$id time=$hhmm: $e\n$st",
        );
      }
    }
    return createdIds;
  }

  static String _buildBody({
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

  static int deterministicIdFor({
    required String medicationId,
    required String scheduleId,
    required String time,
    required int index,
  }) {
    final String mid = medicationId.trim();
    final String sid = scheduleId.trim();
    final String t = time.trim();
    const int mask = 0x7FFFFFFF;
    if (mid.isEmpty && sid.isEmpty && t.isEmpty) {
      return (_fnv1a("schedule:$index") & mask);
    }
    final String payload = "$mid|$sid|$t|$index";
    return _fnv1a(payload) & mask;
  }

  static int _fnv1a(String input) {
    const int fnvPrime = 0x01000193;
    const int fnvOffset = 0x811C9DC5;
    int hash = fnvOffset;
    final List<int> bytes = utf8.encode(input);
    for (final int b in bytes) {
      hash ^= b;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _decode(String payload) {
    try {
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static List<String> _resolveTimes(ScheduleModel s) {
    final List<String> raw = s.times;
    final List<String> result = <String>[];
    final Set<String> seen = <String>{};
    for (final String t in raw) {
      final String clean = t.trim();
      if (!_looksLikeHhmm(clean)) continue;
      if (!seen.add(clean)) continue;
      result.add(clean);
    }
    if (result.isNotEmpty) return result;
    final int perDay = s.timesPerDay < 1
        ? 1
        : s.timesPerDay > 6
        ? 6
        : s.timesPerDay;
    const List<String> defaults = <String>[
      "08:00",
      "12:00",
      "18:00",
      "21:00",
      "09:00",
      "15:00",
    ];
    return defaults.take(perDay).toList(growable: false);
  }

  static bool _looksLikeHhmm(String v) {
    final RegExp exp = RegExp(r"^(\d{2}):(\d{2})$");
    final RegExpMatch? m = exp.firstMatch(v);
    if (m == null) return false;
    final int h = int.tryParse(m.group(1) ?? "-1") ?? -1;
    final int min = int.tryParse(m.group(2) ?? "-1") ?? -1;
    return h >= 0 && h <= 23 && min >= 0 && min <= 59;
  }

  static bool _shouldSchedule(ScheduleModel s) {
    if (s.id.trim().isEmpty || s.medicationId.trim().isEmpty) return false;
    if (s.status == ScheduleStatus.archived ||
        s.status == ScheduleStatus.completed) {
      return false;
    }
    if (s.status == ScheduleStatus.paused) return false;
    if (!s.isActive) return false;
    return true;
  }

  tz.TZDateTime? _nextOccurrenceLocal(ScheduleModel s, String hhmm) {
    _ensureTz();
    final RegExpMatch? parts = RegExp(r"^(\d{2}):(\d{2})$").firstMatch(hhmm);
    if (parts == null) return null;
    final int hour = int.parse(parts.group(1)!);
    final int minute = int.parse(parts.group(2)!);

    final tz.TZDateTime now = tz.TZDateTime.now(localLocation);
    tz.TZDateTime candidate = tz.TZDateTime(
      localLocation,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    final DateTime sStart = DateTime(
      s.startDate.year,
      s.startDate.month,
      s.startDate.day,
    );
    if (candidate.isBefore(_toLocal(sStart))) {
      candidate = _toLocal(sStart).copyWith(hour: hour, minute: minute);
    }

    final DateTime? sEnd = s.endDate == null
        ? null
        : DateTime(
            s.endDate!.year,
            s.endDate!.month,
            s.endDate!.day,
            23,
            59,
            59,
          );
    final tz.TZDateTime? endTz = sEnd == null ? null : _toLocal(sEnd);

    final List<int>? days = s.daysOfWeek.isEmpty ? null : s.daysOfWeek;
    const int maxIter = 400;
    for (int i = 0; i < maxIter; i++) {
      if (!candidate.isBefore(now) &&
          (endTz == null || !candidate.isAfter(endTz)) &&
          (days == null || days.contains(candidate.weekday))) {
        return candidate;
      }
      candidate = tz.TZDateTime(
        localLocation,
        candidate.year,
        candidate.month,
        candidate.day + 1,
        hour,
        minute,
      );
      if (endTz != null && candidate.isAfter(endTz)) return null;
    }
    return null;
  }

  tz.TZDateTime _toLocal(DateTime date) {
    _ensureTz();
    if (date.isUtc) {
      return tz.TZDateTime.from(date, localLocation);
    }
    return tz.TZDateTime(
      localLocation,
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
      date.second,
    );
  }

  Future<void> _scheduleAt(
    int id,
    String title,
    String body,
    tz.TZDateTime scheduledDateLocal,
    Map<String, String> payload,
  ) {
    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        kMedicationChannelId,
        kMedicationChannelName,
        channelDescription: kMedicationChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        icon: "@mipmap/ic_launcher",
        showWhen: true,
        ongoing: false,
        autoCancel: true,
        subText: kMedicationChannelName,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDateLocal,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: jsonEncode(payload),
    );
  }

  Future<void> _initTimezone() async {
    if (_timezoneInitialized) return;
    try {
      tzdata.initializeTimeZones();
      final String? name = await _guessLocalTimezoneName();
      final String tzName =
          name != null && tz.timeZoneDatabase.locations.containsKey(name)
          ? name
          : "UTC";
      _localLocation = tz.getLocation(tzName);
      tz.setLocalLocation(_localLocation!);
      _timezoneInitialized = true;
    } catch (e, st) {
      debugPrint("[NotificationService] tz init failed: $e\n$st");
      tz.setLocalLocation(tz.getLocation("UTC"));
      _localLocation = tz.getLocation("UTC");
      _timezoneInitialized = true;
    }
  }

  void _ensureTz() {
    if (!_timezoneInitialized) {
      tzdata.initializeTimeZones();
      final String name = DateTime.now().timeZoneName;
      if (tz.timeZoneDatabase.locations.containsKey(name)) {
        _localLocation = tz.getLocation(name);
      } else {
        _localLocation = tz.getLocation("UTC");
      }
      tz.setLocalLocation(_localLocation!);
      _timezoneInitialized = true;
    }
  }

  Future<String?> _guessLocalTimezoneName() async {
    try {
      // FlutterLocalNotificationsPlugin exposes no timezone method; use Dart's
      // built-in DateTime.currentTimeZoneName. On Android/iOS this is usually a
      // tz database name ("Europe/Paris", "America/New_York") on recent OSes.
      final String dartName = DateTime.now().timeZoneName;
      if (tz.timeZoneDatabase.locations.containsKey(dartName)) return dartName;
      // Fallback: use offset-based lookup
      final int offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
      return _locationForOffset(offsetMinutes, dartName);
    } catch (_) {
      return null;
    }
  }

  static String? _locationForOffset(int offsetMinutes, String dartName) {
    if (dartName == "UTC") return "UTC";
    final List<String> candidates = tz.timeZoneDatabase.locations.keys.toList(
      growable: false,
    );
    for (final String location in candidates) {
      final tz.Location l = tz.getLocation(location);
      final tz.TZDateTime now = tz.TZDateTime.now(l);
      if (now.timeZoneOffset.inMinutes == offsetMinutes) return location;
    }
    return "UTC";
  }

  Future<void> _initPlatform() async {
    const AndroidInitializationSettings android = AndroidInitializationSettings(
      "@mipmap/ic_launcher",
    );
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const DarwinInitializationSettings macos = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings settings = InitializationSettings(
      android: android,
      iOS: ios,
      macOS: macos,
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse,
    );
    _createAndroidChannel();
  }

  Future<void> _createAndroidChannel() async {
    if (!Platform.isAndroid) return;
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      kMedicationChannelId,
      kMedicationChannelName,
      description: kMedicationChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    await android.createNotificationChannel(channel);
  }

  void _onResponse(NotificationResponse response) {
    _dispatchTap(response);
  }

  static void _onBackgroundResponse(NotificationResponse response) {
    // Isolate has no access to main-isolate callbacks. The main isolate will
    // re-receive the tap via getNotificationAppLaunchDetails on next init.
    debugPrint(
      "[NotificationService] background tap ignored (isolate): ${response.payload}",
    );
  }

  void _dispatchTap(NotificationResponse response) {
    if (response.payload == null || response.payload!.isEmpty) return;
    final Map<String, dynamic> data = _decode(response.payload!);
    final String type = (data["type"] as String?) ?? "unknown";
    onTapHandler?.call(
      type: type,
      medicationId: data["medicationId"] as String?,
      scheduleId: data["scheduleId"] as String?,
      patientId: data["patientId"] as String?,
    );
  }

  Future<Map<String, dynamic>?> getAppLaunchPayload() async {
    try {
      final NotificationAppLaunchDetails? details = await _plugin
          .getNotificationAppLaunchDetails();
      final NotificationResponse? r = details?.notificationResponse;
      if (r == null || r.payload == null) return null;
      return _decode(r.payload!);
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static List<String> resolveTimesForTest(ScheduleModel s) => _resolveTimes(s);

  @visibleForTesting
  static bool shouldScheduleForTest(ScheduleModel s) => _shouldSchedule(s);
}

extension _TZCopyWith on tz.TZDateTime {
  tz.TZDateTime copyWith({
    int? year,
    int? month,
    int? day,
    int? hour,
    int? minute,
    int? second,
  }) {
    return tz.TZDateTime(
      location,
      year ?? this.year,
      month ?? this.month,
      day ?? this.day,
      hour ?? this.hour,
      minute ?? this.minute,
      second ?? this.second,
    );
  }
}
