import 'json.dart';
import 'work.dart';

/// Mirrors `FieldDashboardOut`. `pendingSync` is filled by the client — the
/// server cannot know a phone's unsynced outbox depth.
class FieldDashboard {
  final int assigned;
  final int dueToday;
  final int highRisk;
  final int pendingSync;

  const FieldDashboard({
    required this.assigned,
    required this.dueToday,
    required this.highRisk,
    this.pendingSync = 0,
  });

  factory FieldDashboard.fromJson(Map<String, dynamic> json) => FieldDashboard(
        assigned: asInt(json['assigned']),
        dueToday: asInt(json['due_today']),
        highRisk: asInt(json['high_risk']),
        pendingSync: asInt(json['pending_sync']),
      );

  FieldDashboard withPendingSync(int count) => FieldDashboard(
        assigned: assigned,
        dueToday: dueToday,
        highRisk: highRisk,
        pendingSync: count,
      );
}

/// Mirrors `AssignmentOut` — one field verification task.
class Assignment {
  final String id;
  final WorkSummary work;
  final String status;
  final DateTime? assignedAt;
  final DateTime? dueAt;

  const Assignment({
    required this.id,
    required this.work,
    required this.status,
    this.assignedAt,
    this.dueAt,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
        id: asString(json['id']),
        work: WorkSummary.fromJson(asMap(json['work'])),
        status: asString(json['status']),
        assignedAt: asDate(json['assigned_at']),
        dueAt: asDate(json['due_at']),
      );

  bool get isOverdue =>
      dueAt != null && dueAt!.isBefore(DateTime.now()) && status != 'completed';

  bool get isDueToday {
    if (dueAt == null) return false;
    final now = DateTime.now();
    return dueAt!.year == now.year &&
        dueAt!.month == now.month &&
        dueAt!.day == now.day;
  }
}
