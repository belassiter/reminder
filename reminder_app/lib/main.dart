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
  String _activeSort = 'Manual';
  final List<String> _sortOptions = [
    'Manual',
    'Name (ascending)',
    'Name (descending)',
    'Next Due',
    'Last Due',
    'Most Recent',
    'Least Recent',
    'Most Frequent',
    'Least Frequent',
  ];

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

  void _sortDocuments(List<DocumentSnapshot> docs) {
    switch (_activeSort) {
      case 'Name (ascending)':
        docs.sort((a, b) => Reminder.fromFirestore(a).title.compareTo(Reminder.fromFirestore(b).title));
        break;
      case 'Name (descending)':
        docs.sort((a, b) => Reminder.fromFirestore(b).title.compareTo(Reminder.fromFirestore(a).title));
        break;
      case 'Next Due':
        docs.sort((a, b) => Reminder.fromFirestore(a).nextDueDate.compareTo(Reminder.fromFirestore(b).nextDueDate));
        break;
      case 'Last Due':
        docs.sort((a, b) => Reminder.fromFirestore(b).nextDueDate.compareTo(Reminder.fromFirestore(a).nextDueDate));
        break;
      case 'Most Recent':
        docs.sort((a, b) {
          final aDate = Reminder.fromFirestore(a).ledger.isNotEmpty ? Reminder.fromFirestore(a).ledger.last : DateTime(1970);
          final bDate = Reminder.fromFirestore(b).ledger.isNotEmpty ? Reminder.fromFirestore(b).ledger.last : DateTime(1970);
          return bDate.compareTo(aDate);
        });
        break;
      case 'Least Recent':
        docs.sort((a, b) {
          final aDate = Reminder.fromFirestore(a).ledger.isNotEmpty ? Reminder.fromFirestore(a).ledger.last : DateTime(1970);
          final bDate = Reminder.fromFirestore(b).ledger.isNotEmpty ? Reminder.fromFirestore(b).ledger.last : DateTime(1970);
          return aDate.compareTo(bDate);
        });
        break;
      case 'Most Frequent':
        docs.sort((a, b) {
          final aDuration = _getRecurrenceDuration(Reminder.fromFirestore(a).recurrence);
          final bDuration = _getRecurrenceDuration(Reminder.fromFirestore(b).recurrence);
          return aDuration.compareTo(bDuration);
        });
        break;
      case 'Least Frequent':
        docs.sort((a, b) {
          final aDuration = _getRecurrenceDuration(Reminder.fromFirestore(a).recurrence);
          final bDuration = _getRecurrenceDuration(Reminder.fromFirestore(b).recurrence);
          return bDuration.compareTo(aDuration);
        });
        break;
      case 'Manual':
      default:
        docs.sort((a, b) => Reminder.fromFirestore(a).order.compareTo(Reminder.fromFirestore(b).order));
        break;
    }
  }

  int _getRecurrenceDuration(String recurrence) {
    final rule = _parseFrequency(recurrence);
    if (rule == null) {
      return 99999;
    }
    final int number = rule['number'] as int;
    final String unit = rule['unit'] as String;
    if (unit == 'days') {
      return number;
    } else if (unit == 'weeks') {
      return number * 7;
    } else if (unit == 'fortnights') {
      return number * 14;
    } else if (unit == 'months') {
      return number * 30; // Approximation
    } else if (unit == 'quarters') {
      return number * 90; // Approximation
    } else if (unit == 'years') {
      return number * 365; // Approximation
    } else {
      return 99999;
    }
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
            child: Row(
              children: [
                Expanded(
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
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _activeSort,
                  onChanged: (String? newValue) {
                    setState(() {
                      _activeSort = newValue!;
                    });
                  },
                  items: _sortOptions.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: const [
                SizedBox(width: 34), // Width for drag handle
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

                _sortDocuments(filteredDocs);

                if (filteredDocs.isEmpty) {
                  return const Center(
                      child: Text('No matching reminders found.'));
                }

                if (_activeSort != 'Manual' || _searchQuery.isNotEmpty) {
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

                return ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  proxyDecorator: _proxyDecorator,
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final document = filteredDocs[index];
                    final reminder = Reminder.fromFirestore(document);
                    final status = _getStatus(reminder);
                    return Card(
                      key: ValueKey(document.id),
                      margin: const EdgeInsets.fromLTRB(8.0, 4.0, 24.0, 4.0),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_indicator),
                          ),
                          Expanded(
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
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4.0),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(status),
                                            borderRadius:
                                                BorderRadius.circular(4.0),
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
                                            onPressed: () => _markAsDone(
                                                document.id, reminder),
                                            child: const Text('Now')),
                                        IconButton(
                                            icon: const Icon(Icons.edit),
                                            onPressed: () =>
                                                _navigateToEditScreen(
                                                    document.id, reminder)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  onReorder: (int oldIndex, int newIndex) {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final docs = filteredDocs;
                    final item = docs.removeAt(oldIndex);
                    docs.insert(newIndex, item);

                    final batch = FirebaseFirestore.instance.batch();
                    for (int i = 0; i < docs.length; i++) {
                      batch.update(docs[i].reference, {'order': i});
                    }
                    batch.commit();
                  },
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