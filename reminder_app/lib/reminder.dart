import 'package:cloud_firestore/cloud_firestore.dart';

class Reminder {
  final String? id;
  final String title;
  final DateTime nextDueDate;
  final String recurrence;
  final List<DateTime> ledger;
  final int order;
  final String userId;

  Reminder({
    this.id,
    required this.title,
    required this.nextDueDate,
    required this.recurrence,
    this.ledger = const [],
    required this.order,
    required this.userId,
  });

  factory Reminder.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Reminder(
      id: doc.id,
      title: data['title'] ?? '',
      nextDueDate: (data['nextDueDate'] as Timestamp).toDate(),
      recurrence: data['recurrence'] ?? '',
      ledger: (data['ledger'] as List<dynamic>)
          .map((e) => (e as Timestamp).toDate())
          .toList(),
      order: data['order'] ?? 0,
      userId: data['userId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'nextDueDate': nextDueDate,
      'recurrence': recurrence,
      'ledger': ledger,
      'order': order,
      'userId': userId,
    };
  }

  Reminder copyWith({
    String? id,
    String? title,
    DateTime? nextDueDate,
    String? recurrence,
    List<DateTime>? ledger,
    int? order,
    String? userId,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      recurrence: recurrence ?? this.recurrence,
      ledger: ledger ?? this.ledger,
      order: order ?? this.order,
      userId: userId ?? this.userId,
    );
  }
}