/// Model representing an app notification.
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // critical, warning, info, success
  final DateTime timestamp;
  final bool isRead;
  final String? projectId;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.projectId,
  });
}
