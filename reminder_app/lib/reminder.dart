
class Reminder {
  final String title;
  final DateTime nextDueDate;
  final String recurrence;
  final List<DateTime> ledger;

  Reminder({
    required this.title,
    required this.nextDueDate,
    required this.recurrence,
    this.ledger = const [],
  });

  Reminder copyWith({
    String? title,
    DateTime? nextDueDate,
    String? recurrence,
    List<DateTime>? ledger,
  }) {
    return Reminder(
      title: title ?? this.title,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      recurrence: recurrence ?? this.recurrence,
      ledger: ledger ?? this.ledger,
    );
  }
}
