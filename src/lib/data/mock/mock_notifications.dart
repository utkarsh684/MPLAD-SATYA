import '../models/notification_model.dart';

/// Mock notifications for the notification center.
class MockNotifications {
  MockNotifications._();

  static final List<NotificationModel> all = [
    NotificationModel(
      id: 'NOTIF-001',
      title: 'Critical project detected',
      body: 'Project MPL-2026-00482 has a risk score of 94. Immediate review recommended.',
      type: 'critical',
      timestamp: DateTime(2026, 8, 28, 10, 42),
      projectId: 'MPL-2026-00482',
    ),
    NotificationModel(
      id: 'NOTIF-002',
      title: 'New high-risk flagged',
      body: 'CC Road Construction (Ward 12) flagged with risk score 91.',
      type: 'critical',
      timestamp: DateTime(2026, 8, 25, 14, 30),
      projectId: 'MPL-2026-01678',
    ),
    NotificationModel(
      id: 'NOTIF-003',
      title: 'Verification pending',
      body: '3 field verifications are pending in your district.',
      type: 'warning',
      timestamp: DateTime(2026, 8, 27, 9, 0),
    ),
    NotificationModel(
      id: 'NOTIF-004',
      title: 'Investigation update',
      body: 'Panchayat Bhawan investigation (INV-2026-0003) requires your review.',
      type: 'warning',
      timestamp: DateTime(2026, 8, 26, 16, 20),
      projectId: 'MPL-2026-01205',
    ),
    NotificationModel(
      id: 'NOTIF-005',
      title: 'Sync completed',
      body: '12 evidence records synced successfully.',
      type: 'success',
      timestamp: DateTime(2026, 8, 28, 10, 42),
    ),
    NotificationModel(
      id: 'NOTIF-006',
      title: 'Weekly risk summary',
      body: '4 new high-risk projects detected this week. 2 verifications completed.',
      type: 'info',
      timestamp: DateTime(2026, 8, 26, 8, 0),
    ),
    NotificationModel(
      id: 'NOTIF-007',
      title: 'Field evidence uploaded',
      body: 'Evidence for Community Toilet Complex (Guwahati) uploaded by field officer.',
      type: 'info',
      timestamp: DateTime(2026, 8, 25, 11, 30),
      projectId: 'MPL-2026-00934',
    ),
    NotificationModel(
      id: 'NOTIF-008',
      title: 'Decision recorded',
      body: 'Footpath & Drain Construction verified as acceptable by Officer Demo.',
      type: 'success',
      timestamp: DateTime(2026, 8, 24, 15, 45),
      projectId: 'MPL-2026-02178',
    ),
    NotificationModel(
      id: 'NOTIF-009',
      title: 'PHC Equipment - Tender missing',
      body: 'Rule violation detected: No tender documentation for ₹38L procurement.',
      type: 'critical',
      timestamp: DateTime(2026, 8, 23, 12, 0),
      projectId: 'MPL-2026-00623',
    ),
    NotificationModel(
      id: 'NOTIF-010',
      title: 'Offline data ready',
      body: 'District data has been cached for offline access. 18 projects available.',
      type: 'info',
      timestamp: DateTime(2026, 8, 22, 7, 30),
    ),
  ];

  static int get unreadCount => all.where((n) => !n.isRead).length;
}
