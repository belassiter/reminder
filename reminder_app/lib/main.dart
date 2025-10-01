import 'package:flutter/material.dart';
import 'package:reminder_app/edit_reminder_screen.dart';
import 'package:reminder_app/reminder.dart';

void main() {
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
  final List<Reminder> _reminders = [
    Reminder(
      title: 'Haircut',
      nextDueDate: DateTime.now().add(const Duration(days: 30)),
      recurrence: 'Every 30 days',
      ledger: [],
    ),
    Reminder(
      title: 'Oil Change',
      nextDueDate: DateTime.now().add(const Duration(days: 90)),
      recurrence: 'Every 90 days',
      ledger: [],
    ),
  ];

  void _markAsDone(int index) {
    setState(() {
      final reminder = _reminders[index];
      final now = DateTime.now();
      final newLedger = List<DateTime>.from(reminder.ledger)..add(now);

      // Basic recurrence parsing, assuming "Every X days"
      final parts = reminder.recurrence.split(' ');
      int? days;
      if (parts.length >= 2) {
        days = int.tryParse(parts[1]);
      }
      
      final newDueDate = (days != null)
          ? now.add(Duration(days: days))
          : reminder.nextDueDate;

      _reminders[index] = reminder.copyWith(
        nextDueDate: newDueDate,
        ledger: newLedger,
      );
    });
  }

  Future<void> _navigateToEditScreen(int index) async {
    final reminder = _reminders[index];
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditReminderScreen(reminder: reminder),
      ),
    );

    if (result != null && result is Reminder) {
      setState(() {
        _reminders[index] = result;
      });
    }
  }

  int? _parseRecurrence(String recurrence) {
    final parts = recurrence.split(' ');
    if (parts.length == 3 && parts[0].toLowerCase() == 'every') {
      final days = int.tryParse(parts[1]);
      if (days != null && parts[2].toLowerCase().startsWith('day')) {
        return days;
      }
    }
    return null;
  }

  Future<void> _showAddReminderDialog() async {
    final titleController = TextEditingController();
    final recurrenceController = TextEditingController();
    String? recurrenceError;

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
                      labelText: 'Recurrence (e.g., Every 30 days)',
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
                    if (titleController.text.isNotEmpty && recurrence.isNotEmpty) {
                      final days = _parseRecurrence(recurrence);
                      if (days != null) {
                        this.setState(() {
                          _reminders.add(
                            Reminder(
                              title: titleController.text,
                              nextDueDate: DateTime.now(),
                              recurrence: recurrence,
                              ledger: [],
                            ),
                          );
                        });
                        Navigator.of(context).pop();
                      } else {
                        setState(() {
                          recurrenceError = 'Invalid format. Use "Every X days".';
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
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text('Title', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Recurrence', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Last Completed', style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 130), // Width for buttons
              ],
            ),
          ),
          const Divider(height: 1),

          // List
          Expanded(
            child: ListView.builder(
              itemCount: _reminders.length,
              itemBuilder: (context, index) {
                final reminder = _reminders[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text(reminder.title, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text(reminder.nextDueDate.toString().substring(0, 10))),
                        Expanded(flex: 2, child: Text(reminder.recurrence)),
                        Expanded(
                          flex: 2,
                          child: reminder.ledger.isNotEmpty
                              ? Text(reminder.ledger.last.toString().substring(0, 16))
                              : const SizedBox(),
                        ),
                        SizedBox(
                          width: 130,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(onPressed: () => _markAsDone(index), child: const Text('Done')),
                              IconButton(icon: const Icon(Icons.edit), onPressed: () => _navigateToEditScreen(index)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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