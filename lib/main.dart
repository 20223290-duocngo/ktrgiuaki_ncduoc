import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReminderApp());
}

class ReminderApp extends StatelessWidget {
  const ReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nhac viec',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const TaskListScreen(),
    );
  }
}

enum ReminderType {
  bell('Nhac bang chuong dien thoai'),
  email('Nhac qua email'),
  notification('Nhac bang thong bao');

  const ReminderType(this.label);
  final String label;
}

class Task {
  Task({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.location,
    required this.hasReminder,
    required this.reminderType,
    this.reminded = false,
  });

  final String id;
  final String title;
  final DateTime dateTime;
  final String location;
  final bool hasReminder;
  final ReminderType reminderType;
  bool reminded;

  DateTime get remindAt {
    final oneDayBefore = dateTime.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(DateTime.now())) {
      return oneDayBefore;
    }
    return dateTime;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'dateTime': dateTime.toIso8601String(),
      'location': location,
      'hasReminder': hasReminder,
      'reminderType': reminderType.name,
      'reminded': reminded,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      dateTime: DateTime.parse(map['dateTime'] as String),
      location: map['location'] as String,
      hasReminder: map['hasReminder'] as bool,
      reminderType: ReminderType.values.firstWhere(
        (type) => type.name == map['reminderType'],
        orElse: () => ReminderType.notification,
      ),
      reminded: map['reminded'] as bool? ?? false,
    );
  }
}

class TaskStorage {
  static const String _taskKey = 'simple_tasks';

  static Future<List<Task>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final rawData = prefs.getString(_taskKey);

    if (rawData == null || rawData.isEmpty) {
      return <Task>[];
    }

    final List<dynamic> decoded = jsonDecode(rawData) as List<dynamic>;
    final tasks = decoded
        .map((item) => Task.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    tasks.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return tasks;
  }

  static Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final data = tasks.map((task) => task.toMap()).toList();
    await prefs.setString(_taskKey, jsonEncode(data));
  }
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = <Task>[];
  bool _loading = true;
  bool _showingReminder = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _checkReminder(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final tasks = await TaskStorage.loadTasks();
    if (!mounted) {
      return;
    }

    setState(() {
      _tasks = tasks;
      _loading = false;
    });

    await _checkReminder();
  }

  Future<void> _checkReminder() async {
    if (!mounted || _loading || _showingReminder) {
      return;
    }

    final now = DateTime.now();
    Task? dueTask;

    for (final task in _tasks) {
      if (task.hasReminder && !task.reminded && !task.remindAt.isAfter(now)) {
        dueTask = task;
        break;
      }
    }

    if (dueTask == null) {
      return;
    }

    dueTask.reminded = true;
    await TaskStorage.saveTasks(_tasks);
    if (!mounted) {
      return;
    }

    setState(() {});
    _showingReminder = true;

    try {
      await _showReminderDialog(dueTask);
    } finally {
      _showingReminder = false;
    }
  }

  Future<void> _showReminderDialog(Task task) async {
    IconData icon = Icons.notifications_active_outlined;
    String title = 'Nhac bang thong bao';

    switch (task.reminderType) {
      case ReminderType.bell:
        icon = Icons.alarm;
        title = 'Nhac bang chuong dien thoai';
        SystemSound.play(SystemSoundType.alert);
        break;
      case ReminderType.email:
        icon = Icons.email_outlined;
        title = 'Nhac qua email';
        break;
      case ReminderType.notification:
        icon = Icons.notifications_active_outlined;
        title = 'Nhac bang thong bao';
        break;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: Icon(icon, size: 36),
          title: Text(title),
          content: Text(
            'Cong viec: ${task.title}\n'
            'Thoi gian: ${formatDateTime(task.dateTime)}\n'
            'Dia diem: ${task.location}',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Dong'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openAddTaskScreen() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => const AddTaskScreen(),
      ),
    );

    if (added == true) {
      await _loadTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sach cong viec'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final body = _tasks.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: const <Widget>[
                          SizedBox(height: 80),
                          Icon(Icons.event_note, size: 64),
                          SizedBox(height: 16),
                          Center(
                            child: Text(
                              'Chua co cong viec nao',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                          SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Nhan nut + de them cong viec moi.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTasks,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _tasks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final task = _tasks[index];
                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Text(
                                  task.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text('Thoi gian: ${formatDateTime(task.dateTime)}'),
                                      const SizedBox(height: 4),
                                      Text('Dia diem: ${task.location}'),
                                      const SizedBox(height: 8),
                                      Text(
                                        task.hasReminder
                                            ? 'Nhac viec: ${task.reminderType.label}'
                                            : 'Khong bat nhac viec',
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: Icon(
                                  task.hasReminder
                                      ? Icons.notifications_active
                                      : Icons.notifications_off_outlined,
                                ),
                              ),
                            );
                          },
                        ),
                      );

                if (constraints.maxWidth > 700) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: body,
                    ),
                  );
                }

                return body;
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTaskScreen,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();

  DateTime? _selectedDateTime;
  bool _hasReminder = false;
  ReminderType _reminderType = ReminderType.bell;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initialDate = _selectedDateTime ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? now),
    );

    if (pickedTime == null) {
      return;
    }

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDateTime == null) {
      _showMessage('Vui long chon thoi gian.');
      return;
    }

    if (_selectedDateTime!.isBefore(DateTime.now())) {
      _showMessage('Thoi gian phai lon hon hien tai.');
      return;
    }

    setState(() {
      _saving = true;
    });

    final tasks = await TaskStorage.loadTasks();
    tasks.add(
      Task(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        dateTime: _selectedDateTime!,
        location: _locationController.text.trim(),
        hasReminder: _hasReminder,
        reminderType: _reminderType,
      ),
    );

    tasks.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    await TaskStorage.saveTasks(tasks);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Them cong viec'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth > 700 ? 500 : double.infinity,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Ten cong viec',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui long nhap ten cong viec';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _pickDateTime,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Thoi gian',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            child: Text(
                              _selectedDateTime == null
                                  ? 'Chua chon thoi gian'
                                  : formatDateTime(_selectedDateTime!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Dia diem',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui long nhap dia diem';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile.adaptive(
                          value: _hasReminder,
                          title: const Text('Bat nhac viec'),
                          subtitle: const Text(
                            'Neu con hon 1 ngay, app se nhac truoc 1 ngay.\n'
                            'Neu thoi gian gan hon, app se nhac dung gio.',
                          ),
                          contentPadding: EdgeInsets.zero,
                          onChanged: (value) {
                            setState(() {
                              _hasReminder = value;
                            });
                          },
                        ),
                        if (_hasReminder) ...<Widget>[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<ReminderType>(
                            value: _reminderType,
                            decoration: const InputDecoration(
                              labelText: 'Hinh thuc nhac viec',
                              border: OutlineInputBorder(),
                            ),
                            items: ReminderType.values
                                .map(
                                  (type) => DropdownMenuItem<ReminderType>(
                                    value: type,
                                    child: Text(type.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _reminderType = value;
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _saveTask,
                            child: Text(_saving ? 'Dang luu...' : 'Ghi lai cong viec'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

String formatDateTime(DateTime dateTime) {
  return '${_twoDigits(dateTime.day)}/${_twoDigits(dateTime.month)}/${dateTime.year} '
      '${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
