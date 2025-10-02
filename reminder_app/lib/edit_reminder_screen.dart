import 'package:flutter/material.dart';
import 'package:reminder_app/reminder.dart';

class EditReminderScreen extends StatefulWidget {
  final Reminder reminder;

  const EditReminderScreen({super.key, required this.reminder});

  @override
  State<EditReminderScreen> createState() => _EditReminderScreenState();
}

class _EditReminderScreenState extends State<EditReminderScreen> {
  late TextEditingController _titleController;
  late TextEditingController _recurrenceController;
  late List<DateTime> _ledger;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.reminder.title);
    _recurrenceController = TextEditingController(text: widget.reminder.recurrence);
    _ledger = List<DateTime>.from(widget.reminder.ledger);
  }

  Future<void> _editLedgerEntry(int index) async {
    final entry = _ledger[index];
    final newDate = await showDatePicker(
      context: context,
      initialDate: entry,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (!mounted || newDate == null) return;

    final newTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(entry),
    );

    if (!mounted || newTime == null) return;

    setState(() {
      _ledger[index] = DateTime(
        newDate.year,
        newDate.month,
        newDate.day,
        newTime.hour,
        newTime.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Reminder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              final updatedReminder = widget.reminder.copyWith(
                title: _titleController.text,
                recurrence: _recurrenceController.text,
                ledger: _ledger,
              );
              Navigator.of(context).pop(updatedReminder);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _recurrenceController,
              decoration: const InputDecoration(labelText: 'Recurrence'),
            ),
            const SizedBox(height: 20),
            const Text('Ledger', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: _ledger.length,
                itemBuilder: (context, index) {
                  final entry = _ledger[index];
                  return ListTile(
                    title: Text(entry.toString().substring(0, 16)),
                    onTap: () => _editLedgerEntry(index),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _ledger.removeAt(index);
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}