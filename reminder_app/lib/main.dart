import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reminder_app/edit_reminder_screen.dart';
import 'package:reminder_app/firebase_options.dart';
import 'package:reminder_app/reminder.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reminder App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ReminderListScreen(),
    );
  }
}

class ReminderListScreen extends StatefulWidget {
  const ReminderListScreen({super.key});

  @override
  State<ReminderListScreen> createState() => _ReminderListScreenState();
}

class _ReminderListScreenState extends State<ReminderListScreen> {
  final Stream<QuerySnapshot> _remindersStream =
      FirebaseFirestore.instance.collection('reminders').orderBy('order').snapshots();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double elevation = lerpDouble(0, 6, animValue)!;
        return Material(
          elevation: elevation,
          shadowColor: Colors.black,
          child: child,
        );
      },
      child: child,
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Overdue':
        return Colors.orange;
      case 'Due today':
      case 'Due soon':
        return Colors.yellow;
      case 'Ok':
        return Colors.green;
      default:
        return Colors.transparent;
    }
  }

  String _getStatus(Reminder reminder) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextDueDate = DateTime(reminder.nextDueDate.year,
        reminder.nextDueDate.month, reminder.nextDueDate.day);

    if (nextDueDate.isBefore(today)) {
      return 'Overdue';
    } else if (nextDueDate.isAtSameMomentAs(today)) {
      return 'Due today';
    }

    int dueSoonDays;
    if (reminder.ledger.isEmpty) {
      final rule = _parseFrequency(reminder.recurrence);
      if (rule == null) {
        dueSoonDays = 1;
      } else {
        final int number = rule['number'] as int;
        final String unit = rule['unit'] as String;
        double durationDays;
        if (unit == 'days') {
          durationDays = number.toDouble();
        } else if (unit == 'weeks') {
          durationDays = (number * 7).toDouble();
        } else if (unit == 'fortnights') {
          durationDays = (number * 14).toDouble();
        } else if (unit == 'months') {
          durationDays = (number * 30).toDouble(); // Approximation
        } else if (unit == 'quarters') {
          durationDays = (number * 90).toDouble(); // Approximation
        } else if (unit == 'years') {
          durationDays = (number * 365).toDouble(); // Approximation
        } else {
          durationDays = 1;
        }
        dueSoonDays = (durationDays * 0.1).ceil();
      }
    } else {
      final previousDate = reminder.ledger.last;
      final duration = reminder.nextDueDate.difference(previousDate).inDays;
      dueSoonDays = (duration * 0.1).ceil();
    }

    dueSoonDays = dueSoonDays.clamp(1, 7);

    final dueSoonDate = nextDueDate.subtract(Duration(days: dueSoonDays));

    if (today.isAfter(dueSoonDate) || today.isAtSameMomentAs(dueSoonDate)) {
      return 'Due soon';
    }

    return 'Ok';
  }

  DateTime _calculateNextDueDate(DateTime lastCompleted, String recurrence) {
    final rule = _parseFrequency(recurrence);
    if (rule == null) {
      // Default to last completed date if parsing fails
      return lastCompleted;
    }

    final int number = rule['number'] as int;
    final String unit = rule['unit'] as String;

    if (unit == 'days') {
      return lastCompleted.add(Duration(days: number));
    } else if (unit == 'weeks') {
      return lastCompleted.add(Duration(days: number * 7));
    } else if (unit == 'fortnights') {
      return lastCompleted.add(Duration(days: number * 14));
    } else if (unit == 'months') {
      var newMonth = lastCompleted.month + number;
      var newYear = lastCompleted.year;
      while (newMonth > 12) {
        newMonth -= 12;
        newYear++;
      }
      var newDay = lastCompleted.day;
      var lastDayOfNewMonth = DateTime(newYear, newMonth + 1, 0).day;
      if (newDay > lastDayOfNewMonth) {
        newDay = lastDayOfNewMonth;
      }
      return DateTime(newYear, newMonth, newDay);
    } else if (unit == 'quarters') {
      return _calculateNextDueDate(lastCompleted, '${number * 3} months');
    } else if (unit == 'years') {
      var newYear = lastCompleted.year + number;
      var newDay = lastCompleted.day;
      var lastDayOfNewMonth = DateTime(newYear, lastCompleted.month + 1, 0).day;
      if (newDay > lastDayOfNewMonth) {
        newDay = lastDayOfNewMonth;
      }
      return DateTime(newYear, lastCompleted.month, newDay);
    }
    return lastCompleted;
  }

  Map<String, Object>? _parseFrequency(String input) {
    input = input.toLowerCase().trim().replaceAll('every', '').trim();
    final parts = input.split(' ');
    int number;
    String unit;

    if (parts.length == 1) {
      number = 1;
      unit = parts[0];
      if (unit.endsWith('ly')) {
        unit = unit.substring(0, unit.length - 2);
      }
    } else if (parts.length == 2) {
      number = int.tryParse(parts[0]) ?? 1;
      unit = parts[1];
    } else {
      return null;
    }

    if (unit.endsWith('s')) {
      unit = unit.substring(0, unit.length - 1);
    }

    switch (unit) {
      case 'day':
        return {'number': number, 'unit': 'days'};
      case 'week':
        return {'number': number, 'unit': 'weeks'};
      case 'fortnight':
        return {'number': number, 'unit': 'fortnights'};
      case 'month':
        return {'number': number, 'unit': 'months'};
      case 'quarter':
        return {'number': number, 'unit': 'quarters'};
      case 'year':
        return {'number': number, 'unit': 'years'};
      default:
        return null;
    }
  }

  void _markAsDone(String id, Reminder reminder) {
    final now = DateTime.now();
    final newLedger = List<DateTime>.from(reminder.ledger)..add(now);
    final newDueDate = _calculateNextDueDate(now, reminder.recurrence);

    FirebaseFirestore.instance.collection('reminders').doc(id).update({
      'nextDueDate': newDueDate,
      'ledger': newLedger,
    });
  }

  Future<void> _navigateToEditScreen(String id, Reminder reminder) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditReminderScreen(reminder: reminder),
      ),
    );

    if (result != null && result is Reminder) {
      final newDueDate = result.ledger.isNotEmpty
          ? _calculateNextDueDate(result.ledger.last, result.recurrence)
          : _calculateNextDueDate(DateTime.now(), result.recurrence);

      FirebaseFirestore.instance
          .collection('reminders')
          .doc(id)
          .update(result.copyWith(nextDueDate: newDueDate).toFirestore());
    }
  }

  Future<void> _showAddReminderDialog() async {
    final titleController = TextEditingController();
    final recurrenceController = TextEditingController();
    String? recurrenceError;
    final int reminderCount = (await FirebaseFirestore.instance.collection('reminders').get()).docs.length;

    if (!mounted) return;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Reminder'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  TextField(
                    controller: recurrenceController,
                    decoration: InputDecoration(
                      labelText: 'Frequency (e.g., 30 days, weekly)',
                      errorText: recurrenceError,
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Add'),
                  onPressed: () {
                    final recurrence = recurrenceController.text;
                    if (titleController.text.isNotEmpty &&
                        recurrence.isNotEmpty) {
                      final Map<String, Object>? rule =
                          _parseFrequency(recurrence);
                      if (rule != null) {
                        FirebaseFirestore.instance.collection('reminders').add(
                              Reminder(
                                title: titleController.text,
                                nextDueDate: _calculateNextDueDate(
                                    DateTime.now(), recurrence),
                                recurrence: recurrence,
                                ledger: [],
                                order: reminderCount,
                              ).toFirestore(),
                            );
                        Navigator.of(context).pop();
                      } else {
                        setState(() {
                          recurrenceError =
                              'Invalid format. Use "30 days", "weekly", etc.';
                        });
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search',
                hintText: 'Search reminders...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(25.0)),
                ),
              ),
            ),
          ),
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: const [
                Expanded(
                    flex: 4,
                    child: Text('Reminder',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 2,
                    child: Text('Status',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 2,
                    child: Text('Next',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 2,
                    child: Text('Previous',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 2,
                    child: Text('Frequency',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 130), // Width for buttons
              ],
            ),
          ),
          const Divider(height: 1),

          // List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _remindersStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Something went wrong');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('No reminders yet. Add one!'));
                }

                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final reminder = Reminder.fromFirestore(doc);
                  return reminder.title
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                      child: Text('No matching reminders found.'));
                }

                if (_searchQuery.isNotEmpty) {
                  return ListView(
                    children: 
                        filteredDocs.map((document) {
                      final reminder = Reminder.fromFirestore(document);
                      final status = _getStatus(reminder);
                      return Card(
                        key: ValueKey(document.id),
                        margin: const EdgeInsets.fromLTRB(8.0, 4.0, 24.0, 4.0),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                  flex: 4,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Text(reminder.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  )),
                              Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 12.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status),
                                        borderRadius: BorderRadius.circular(4.0),
                                      ),
                                      child: Text(
                                        status,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  )),
                              Expanded(
                                  flex: 2,
                                  child: Text(DateFormat('MMM d, yyyy')
                                      .format(reminder.nextDueDate))),
                              Expanded(
                                flex: 2,
                                child: reminder.ledger.isNotEmpty
                                    ? Text(DateFormat('MMM d, yyyy')
                                        .format(reminder.ledger.last))
                                    : const SizedBox(),
                              ),
                              Expanded(
                                  flex: 2, child: Text(reminder.recurrence)),
                              SizedBox(
                                width: 130,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton(
                                        onPressed: () =>
                                            _markAsDone(document.id, reminder),
                                        child: const Text('Now')),
                                    IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _navigateToEditScreen(
                                            document.id, reminder)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }

                return ReorderableListView(
                  buildDefaultDragHandles: false,
                  proxyDecorator: _proxyDecorator,
                  onReorder: (int oldIndex, int newIndex) {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final docs = snapshot.data!.docs;
                    final item = docs.removeAt(oldIndex);
                    docs.insert(newIndex, item);

                    final batch = FirebaseFirestore.instance.batch();
                    for (int i = 0; i < docs.length; i++) {
                      batch.update(docs[i].reference, {'order': i});
                    }
                    batch.commit();
                  },
                  children: 
                      snapshot.data!.docs.map((document) {
                    final reminder = Reminder.fromFirestore(document);
                    final status = _getStatus(reminder);
                    return Card(
                      key: ValueKey(document.id),
                      margin: const EdgeInsets.fromLTRB(8.0, 4.0, 24.0, 4.0),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                                flex: 4,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Text(reminder.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                )),
                            Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status),
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                    child: Text(
                                      status,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )),
                            Expanded(
                                flex: 2,
                                child: Text(DateFormat('MMM d, yyyy')
                                    .format(reminder.nextDueDate))),
                            Expanded(
                              flex: 2,
                              child: reminder.ledger.isNotEmpty
                                  ? Text(DateFormat('MMM d, yyyy')
                                      .format(reminder.ledger.last))
                                  : const SizedBox(),
                            ),
                            Expanded(
                                flex: 2, child: Text(reminder.recurrence)),
                            SizedBox(
                              width: 130,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton(
                                      onPressed: () =>
                                          _markAsDone(document.id, reminder),
                                      child: const Text('Now')),
                                  IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _navigateToEditScreen(
                                          document.id, reminder)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddReminderDialog,
        tooltip: 'Add Reminder',
        child: const Icon(Icons.add),
      ),
    );
  }
}
