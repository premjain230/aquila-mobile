import 'package:cloud_firestore/cloud_firestore.dart';

/// A single study task — `tasks/{taskId}` (mirrors web task shape).
class StudyTask {
  final String docId;
  final String taskId;
  final String subject;
  final String topic;
  final int durationMinutes;
  final String type; // learn | revise | practice | test
  final String priority; // high | medium | low
  final String status; // pending | completed | skipped
  final DateTime scheduledDate;
  final String? weekDay;
  final int week;

  const StudyTask({
    required this.docId,
    required this.taskId,
    required this.subject,
    required this.topic,
    required this.durationMinutes,
    required this.type,
    required this.priority,
    required this.status,
    required this.scheduledDate,
    this.weekDay,
    this.week = 1,
  });

  bool get isCompleted => status == 'completed';
  bool get isSkipped => status == 'skipped';

  StudyTask copyWith({String? status}) => StudyTask(
        docId: docId,
        taskId: taskId,
        subject: subject,
        topic: topic,
        durationMinutes: durationMinutes,
        type: type,
        priority: priority,
        status: status ?? this.status,
        scheduledDate: scheduledDate,
        weekDay: weekDay,
        week: week,
      );

  factory StudyTask.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final dateVal = d['scheduledDate'];
    DateTime date;
    if (dateVal is Timestamp) {
      date = dateVal.toDate();
    } else if (dateVal is DateTime) {
      date = dateVal;
    } else {
      date = DateTime.now();
    }
    return StudyTask(
      docId: doc.id,
      taskId: d['taskId']?.toString() ?? doc.id,
      subject: d['subject']?.toString() ?? '',
      topic: d['topic']?.toString() ?? '',
      durationMinutes: (d['durationMinutes'] as num?)?.toInt() ?? 60,
      type: d['type']?.toString() ?? 'learn',
      priority: d['priority']?.toString() ?? 'medium',
      status: d['status']?.toString() ?? 'pending',
      scheduledDate: date,
      weekDay: d['weekDay']?.toString(),
      week: (d['week'] as num?)?.toInt() ?? 1,
    );
  }
}