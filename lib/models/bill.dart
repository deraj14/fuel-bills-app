enum BillType { creditCard, utility }

class Bill {
  final int? id;
  final String name;
  final BillType type;
  final int dueDay; // 1-31
  final double? amount;
  final int notificationId; // stable id used to schedule/cancel reminders

  Bill({
    this.id,
    required this.name,
    required this.type,
    required this.dueDay,
    this.amount,
    required this.notificationId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type == BillType.creditCard ? 'card' : 'utility',
      'due_day': dueDay,
      'amount': amount,
      'notification_id': notificationId,
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    return Bill(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: (map['type'] as String) == 'card' ? BillType.creditCard : BillType.utility,
      dueDay: map['due_day'] as int,
      amount: map['amount'] == null ? null : (map['amount'] as num).toDouble(),
      notificationId: map['notification_id'] as int,
    );
  }

  /// Next occurrence of this bill's due date, rolling to next month
  /// if today is already past this month's due day.
  DateTime nextDueDate({DateTime? from}) {
    final today = from ?? DateTime.now();
    final todayMid = DateTime(today.year, today.month, today.day);
    DateTime candidate = _safeDate(today.year, today.month, dueDay);
    if (candidate.isBefore(todayMid)) {
      candidate = _safeDate(today.year, today.month + 1, dueDay);
    }
    return candidate;
  }

  /// Clamp the day to the last valid day of the target month
  /// (e.g. dueDay 31 in February becomes Feb 28/29).
  static DateTime _safeDate(int year, int month, int day) {
    final normalizedYear = year + (month - 1) ~/ 12;
    final normalizedMonth = ((month - 1) % 12) + 1;
    final lastDayOfMonth = DateTime(normalizedYear, normalizedMonth + 1, 0).day;
    final clampedDay = day > lastDayOfMonth ? lastDayOfMonth : day;
    return DateTime(normalizedYear, normalizedMonth, clampedDay);
  }
}
