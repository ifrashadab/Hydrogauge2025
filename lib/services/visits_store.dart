import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hydrogauge/services/api_client.dart';
import 'package:hydrogauge/services/auth_store.dart';

enum VisitType { routine, inspection }
enum VisitPriority { low, medium, high }

class Visit {
  final String id;
  final DateTime date; // date only (at local midnight)
  final String time; // display-friendly time e.g., "10:00 AM"
  final String siteId;
  final String siteName;
  final VisitType type;
  final VisitPriority priority;
  final String? notes;

  const Visit({
    required this.id,
    required this.date,
    required this.time,
    required this.siteId,
    required this.siteName,
    this.type = VisitType.routine,
    this.priority = VisitPriority.medium,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'time': time,
        'siteId': siteId,
        'siteName': siteName,
        'type': type.name,
        'priority': priority.name,
        if (notes != null) 'notes': notes,
      };

  static Visit fromJson(Map<String, dynamic> j) => Visit(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        time: j['time'] as String,
        siteId: j['siteId'] as String,
        siteName: j['siteName'] as String,
        type: VisitType.values.firstWhere((e) => e.name == (j['type'] as String? ?? 'routine'), orElse: () => VisitType.routine),
        priority: VisitPriority.values.firstWhere((e) => e.name == (j['priority'] as String? ?? 'medium'), orElse: () => VisitPriority.medium),
        notes: j['notes'] as String?,
      );
}

class VisitsStore {
  VisitsStore._();
  static final VisitsStore instance = VisitsStore._();

  final ValueNotifier<List<Visit>> visits = ValueNotifier<List<Visit>>([]);

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/visits.json');
  }

  Future<void> load({String? status, String? siteId}) async {
    // Try live API first
    final token = AuthStore.instance.token.value;
    if (token != null && token.isNotEmpty) {
      try {
        final resp = await ApiClient().listVisits(token: token, status: status, siteId: siteId);
        if (resp['ok'] == true && resp['visits'] is List) {
          final arr = (resp['visits'] as List).cast<dynamic>();
          visits.value = arr.map((e) => Visit.fromJson(_mapVisitFromApi(e as Map<String, dynamic>))).toList();
          await save();
          return;
        }
      } catch (_) {
        // fall back to local cache below
      }
    }
    // Fallback to local persisted cache
    try {
      final f = await _file();
      if (await f.exists()) {
        final arr = jsonDecode(await f.readAsString()) as List<dynamic>;
        visits.value = arr.map((e) => Visit.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        visits.value = const [];
      }
    } catch (_) {}
  }

  Future<void> save() async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode(visits.value.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> add(Visit v) async {
    // Try schedule via API if token present; otherwise just persist locally
    final token = AuthStore.instance.token.value;
    if (token != null && token.isNotEmpty) {
      try {
        final payload = {
          'siteId': v.siteId,
          'siteName': v.siteName,
          'scheduledDate': DateTime(v.date.year, v.date.month, v.date.day).toIso8601String(),
          'scheduledTime': v.time,
          'type': v.type.name,
          'priority': v.priority.name,
          if (v.notes != null && v.notes!.isNotEmpty) 'notes': v.notes,
        };
        final resp = await ApiClient().scheduleVisit(token: token, payload: payload);
        if (resp['ok'] == true && resp['visit'] is Map) {
          final serverVisit = Visit.fromJson(_mapVisitFromApi((resp['visit'] as Map).cast<String, dynamic>()));
          visits.value = [...visits.value, serverVisit];
          await save();
          return;
        }
      } catch (_) {}
    }
    visits.value = [...visits.value, v];
    await save();
  }

  Future<void> remove(String id) async {
    visits.value = visits.value.where((v) => v.id != id).toList();
    await save();
  }

  // Backend Visit model uses different keys; convert to our Visit json shape
  Map<String, dynamic> _mapVisitFromApi(Map<String, dynamic> j) {
    return {
      'id': (j['id'] ?? j['_id'] ?? '').toString(),
      'date': (j['scheduledDate'] ?? j['date'] ?? DateTime.now().toIso8601String()).toString(),
      'time': (j['scheduledTime'] ?? j['time'] ?? '10:00 AM').toString(),
      'siteId': (j['siteId'] ?? '').toString(),
      'siteName': (j['siteName'] ?? (j['site']?['name'] ?? 'Site')).toString(),
      'type': (j['type'] ?? 'routine').toString(),
      'priority': (j['priority'] ?? 'medium').toString(),
      if (j['notes'] != null) 'notes': j['notes'].toString(),
    };
  }
}


