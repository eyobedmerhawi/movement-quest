import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const activityTypes = ['Walking', 'Running', 'Cycling', 'Hiking'];

class AppDb {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await openDatabase(
      p.join(await getDatabasesPath(), 'movement_quest.db'),
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE workout_plan (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            activityType TEXT NOT NULL,
            targetMinutes INTEGER NOT NULL,
            targetDistance REAL NOT NULL,
            planNote TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE training_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            workoutId INTEGER,
            activityName TEXT NOT NULL,
            activityType TEXT NOT NULL,
            activityDate TEXT NOT NULL,
            actualMinutes INTEGER NOT NULL,
            actualDistance REAL NOT NULL,
            status TEXT NOT NULL DEFAULT 'completed',
            notes TEXT NOT NULL DEFAULT '',
            FOREIGN KEY(workoutId) REFERENCES workout_plan(id) ON DELETE SET NULL
          )
        ''');
      },
    );
    return _database!;
  }
}

typedef Record = Map<String, Object?>;

Future<List<Record>> getPlans() async =>
    (await AppDb.database).query('workout_plan', orderBy: 'id DESC');

Future<List<Record>> getLogs() async =>
    (await AppDb.database).query('training_log', orderBy: 'activityDate DESC, id DESC');

String activityDateLabel(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  return '${date.month}/${date.day}/${date.year}';
}

DateTime startOfWeek(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  return local.subtract(Duration(days: local.weekday - 1));
}

List<Record> thisWeeksLogs(List<Record> logs) {
  final start = startOfWeek(DateTime.now());
  final end = start.add(const Duration(days: 7));
  return logs.where((log) {
    final date = DateTime.tryParse(log['activityDate'] as String? ?? '')?.toLocal();
    return date != null && !date.isBefore(start) && date.isBefore(end) &&
        log['status'] == 'completed';
  }).toList();
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MovementQuestApp());
}

class MovementQuestApp extends StatelessWidget {
  const MovementQuestApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Movement Quest',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
        home: const HomeShell(),
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int selected = 0;
  int revision = 0;

  void refresh() => setState(() => revision++);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardTab(onNavigate: (i) => setState(() => selected = i)),
      PlansTab(onChanged: refresh),
      TrackTab(onChanged: refresh),
      HistoryTab(onChanged: refresh),
      const SettingsTab(),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Movement Quest')),
      body: SafeArea(child: KeyedSubtree(key: ValueKey('$selected-$revision'), child: pages[selected])),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) => setState(() => selected = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Plans'),
          NavigationDestination(icon: Icon(Icons.directions_run), label: 'Track'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class DashboardTab extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  const DashboardTab({super.key, required this.onNavigate});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  List<Record> plans = [];
  List<Record> logs = [];
  int weeklyGoal = 3;
  bool encouragement = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final resultPlans = await getPlans();
    final resultLogs = await getLogs();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      plans = resultPlans;
      logs = resultLogs;
      weeklyGoal = prefs.getInt('weeklyGoal') ?? 3;
      encouragement = prefs.getBool('encouragement') ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final weekly = thisWeeksLogs(logs);
    final minutes = weekly.fold<int>(0, (sum, log) => sum + (log['actualMinutes'] as int));
    final miles = weekly.fold<double>(0, (sum, log) => sum + (log['actualDistance'] as num).toDouble());
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Your week', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${weekly.length} / $weeklyGoal activities completed'),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (weekly.length / weeklyGoal).clamp(0.0, 1.0)),
          const SizedBox(height: 8),
          Text('$minutes minutes  •  ${miles.toStringAsFixed(2)} miles'),
        ]),
      )),
      if (encouragement) const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Every activity you record is progress worth keeping.'),
      ),
      const SizedBox(height: 12),
      Text('Choose an activity', style: Theme.of(context).textTheme.titleMedium),
      Wrap(spacing: 8, runSpacing: 8, children: activityTypes.map((type) =>
        ActionChip(label: Text(type), onPressed: () => widget.onNavigate(1))
      ).toList()),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: () => widget.onNavigate(1),
        icon: const Icon(Icons.add),
        label: const Text('Create or view plans'),
      ),
      const SizedBox(height: 16),
      QuestGuide(plans: plans, logs: logs),
    ]);
  }
}

class QuestGuide extends StatelessWidget {
  final List<Record> plans;
  final List<Record> logs;
  const QuestGuide({super.key, required this.plans, required this.logs});

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return const Card(child: ListTile(
        title: Text('Progressive Quest Guide'),
        subtitle: Text('Create a plan first to see an optional suggestion.'),
      ));
    }
    final plan = plans.first;
    final type = plan['activityType'] as String;
    final recent = logs.where((log) =>
        log['activityType'] == type && log['status'] == 'completed').take(3).toList();
    final target = plan['targetMinutes'] as int;
    late final String suggestion;
    if (recent.length < 3) {
      suggestion = 'Try your ${plan['title']} plan at its current $target-minute target. '
          'There are fewer than three completed $type activities to compare.';
    } else {
      final consistent = recent.every((log) => (log['actualMinutes'] as int) >= target);
      suggestion = consistent
          ? 'Your last three $type activities reached $target minutes. '
              'You could optionally try ${target + 5} minutes next time.'
          : 'Some recent $type activities were below $target minutes. '
              'Consider keeping your current target and adjusting it yourself if needed.';
    }
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Progressive Quest Guide', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(suggestion),
        const SizedBox(height: 6),
        const Text('Optional suggestion only. You choose your activity and goals.'),
      ]),
    ));
  }
}

class PlansTab extends StatefulWidget {
  final VoidCallback onChanged;
  const PlansTab({super.key, required this.onChanged});

  @override
  State<PlansTab> createState() => _PlansTabState();
}

class _PlansTabState extends State<PlansTab> {
  List<Record> plans = [];
  String filter = 'All';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final rows = await getPlans();
    if (mounted) setState(() => plans = rows);
  }

  Future<void> editPlan([Record? plan]) async {
    final changed = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => PlanEditor(plan: plan)));
    if (changed == true) {
      await load();
      widget.onChanged();
    }
  }

  Future<void> deletePlan(Record plan) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete plan?'),
      content: const Text('The plan will be removed, but completed activity history will be kept.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ));
    if (confirmed != true) return;
    await (await AppDb.database).delete('workout_plan', where: 'id = ?', whereArgs: [plan['id']]);
    if (!mounted) return;
    await load();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final shown = filter == 'All' ? plans : plans.where((plan) => plan['activityType'] == filter).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          initialValue: filter,
          decoration: const InputDecoration(labelText: 'Filter activity'),
          items: ['All', ...activityTypes].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
          onChanged: (value) => setState(() => filter = value ?? 'All'),
        )),
        const SizedBox(width: 8),
        FilledButton.icon(onPressed: () => editPlan(), icon: const Icon(Icons.add), label: const Text('New')),
      ])),
      Expanded(child: shown.isEmpty
        ? const Center(child: Text('No plans found. Tap New to create one.'))
        : ListView.builder(itemCount: shown.length, itemBuilder: (context, index) {
          final plan = shown[index];
          return Card(child: ListTile(
            title: Text(plan['title'] as String),
            subtitle: Text('${plan['activityType']} • ${plan['targetMinutes']} min • ${plan['targetDistance']} mi'),
            onTap: () => editPlan(plan),
            trailing: IconButton(
              tooltip: 'Delete plan', icon: const Icon(Icons.delete_outline),
              onPressed: () => deletePlan(plan),
            ),
          ));
        })),
    ]);
  }
}

class PlanEditor extends StatefulWidget {
  final Record? plan;
  const PlanEditor({super.key, this.plan});

  @override
  State<PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<PlanEditor> {
  final formKey = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.plan?['title'] as String? ?? '');
  late final minutes = TextEditingController(text: widget.plan?['targetMinutes']?.toString() ?? '');
  late final distance = TextEditingController(text: widget.plan?['targetDistance']?.toString() ?? '');
  late final note = TextEditingController(text: widget.plan?['planNote'] as String? ?? '');
  late String type = widget.plan?['activityType'] as String? ?? activityTypes.first;
  bool saving = false;

  @override
  void dispose() {
    title.dispose(); minutes.dispose(); distance.dispose(); note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final values = <String, Object?>{
        'title': title.text.trim(),
        'activityType': type,
        'targetMinutes': int.parse(minutes.text.trim()),
        'targetDistance': double.parse(distance.text.trim()),
        'planNote': note.text.trim(),
      };
      final db = await AppDb.database;
      if (widget.plan == null) {
        await db.insert('workout_plan', values);
      } else {
        await db.update('workout_plan', values, where: 'id = ?', whereArgs: [widget.plan!['id']]);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e, stackTrace) {
  debugPrint('PLAN SAVE ERROR: $e');
  debugPrintStack(stackTrace: stackTrace);

  if (mounted) {
    showMessage(context, 'Save failed: $e');
  }
} finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.plan == null ? 'Create plan' : 'Edit plan')),
    body: Form(key: formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
      TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Plan name'),
        validator: (value) => value == null || value.trim().isEmpty ? 'Enter a plan name' : null),
      DropdownButtonFormField<String>(
        initialValue: type, decoration: const InputDecoration(labelText: 'Activity type'),
        items: activityTypes.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
        onChanged: (value) => setState(() => type = value ?? type),
      ),
      TextFormField(controller: minutes, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Target minutes'),
        validator: (value) {
          final n = int.tryParse(value?.trim() ?? '');
          return n == null || n <= 0 ? 'Enter a positive whole number' : null;
        }),
      TextFormField(controller: distance,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Target distance (miles)'),
        validator: (value) {
          final n = double.tryParse(value?.trim() ?? '');
          return n == null || !n.isFinite || n <= 0 ? 'Enter a positive distance' : null;
        }),
      TextFormField(controller: note, maxLines: 3,
        decoration: const InputDecoration(labelText: 'Notes (optional)')),
      const SizedBox(height: 16),
      FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Saving...' : 'Save plan')),
    ])),
  );
}

class TrackTab extends StatefulWidget {
  final VoidCallback onChanged;
  const TrackTab({super.key, required this.onChanged});

  @override
  State<TrackTab> createState() => _TrackTabState();
}

class _TrackTabState extends State<TrackTab> {
  List<Record> plans = [];
  int? planId;
  bool active = false;
  bool saving = false;
  String? error;
  final minutes = TextEditingController();
  final distance = TextEditingController();
  final notes = TextEditingController();

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final rows = await getPlans();
    if (!mounted) return;
    setState(() {
      plans = rows;
      if (!plans.any((plan) => plan['id'] == planId)) planId = null;
    });
  }

  @override
  void dispose() {
    minutes.dispose(); distance.dispose(); notes.dispose();
    super.dispose();
  }

  Future<void> finish() async {
    if (!active || saving || planId == null) return;
    final duration = int.tryParse(minutes.text.trim());
    final miles = double.tryParse(distance.text.trim());
    if (duration == null || duration <= 0 || miles == null || !miles.isFinite || miles <= 0) {
      setState(() => error = 'Enter positive minutes and distance.');
      return;
    }
    final matching = plans.where((plan) => plan['id'] == planId);
    if (matching.isEmpty) {
      setState(() => error = 'The selected plan is no longer available.');
      return;
    }
    final plan = matching.first;
    setState(() { saving = true; error = null; });
    try {
      await (await AppDb.database).insert('training_log', {
        'workoutId': planId,
        'activityName': plan['title'],
        'activityType': plan['activityType'],
        'activityDate': DateTime.now().toIso8601String(),
        'actualMinutes': duration,
        'actualDistance': miles,
        'status': 'completed',
        'notes': notes.text.trim(),
      });
      if (!mounted) return;
      setState(() { active = false; minutes.clear(); distance.clear(); notes.clear(); });
      showMessage(context, 'Activity saved to history');
      widget.onChanged();
    } catch (_) {
      if (mounted) setState(() => error = 'Could not save the activity. Try again.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> reset() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Reset this activity?'),
      content: const Text('Discard the unfinished activity? Saved history will remain.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
      ],
    ));
    if (!mounted || confirmed != true) return;
    setState(() { active = false; error = null; minutes.clear(); distance.clear(); notes.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    final selected = plans.where((plan) => plan['id'] == planId);
    final plan = selected.isEmpty ? null : selected.first;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Track an activity', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(
        value: planId,
        decoration: const InputDecoration(labelText: 'Choose a plan'),
        items: plans.map((plan) => DropdownMenuItem(
          value: plan['id'] as int, child: Text(plan['title'] as String),
        )).toList(),
        onChanged: active ? null : (value) => setState(() => planId = value),
      ),
      if (plan != null) Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('Goal: ${plan['targetMinutes']} minutes • ${plan['targetDistance']} miles'),
      ),
      Text(active ? 'Status: In progress' : 'Status: Not started'),
      const SizedBox(height: 12),
      if (!active)
        FilledButton(onPressed: plan == null ? null : () => setState(() { active = true; error = null; }),
          child: const Text('Start'))
      else ...[
        TextField(controller: minutes, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Actual minutes')),
        TextField(controller: distance,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Actual distance (miles)')),
        TextField(controller: notes, maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes (optional)')),
        const SizedBox(height: 12),
        FilledButton(onPressed: saving ? null : finish, child: Text(saving ? 'Saving...' : 'Finish & Save')),
        OutlinedButton(onPressed: saving ? null : reset, child: const Text('Reset')),
      ],
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12),
        child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    ]);
  }
}

class HistoryTab extends StatefulWidget {
  final VoidCallback onChanged;
  const HistoryTab({super.key, required this.onChanged});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<Record> logs = [];
  String filter = 'All';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final rows = await getLogs();
    if (mounted) setState(() => logs = rows);
  }

  Future<void> editLog(Record log) async {
    final changed = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => LogEditor(log: log)));
    if (changed == true) { await load(); widget.onChanged(); }
  }

  Future<void> deleteLog(Record log) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete activity?'),
      content: const Text('This completed activity will be permanently removed.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ));
    if (confirmed != true) return;
    await (await AppDb.database).delete('training_log', where: 'id = ?', whereArgs: [log['id']]);
    if (!mounted) return;
    await load();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final shown = filter == 'All' ? logs : logs.where((log) => log['activityType'] == filter).toList();
    final weekly = thisWeeksLogs(logs);
    final totalMinutes = weekly.fold<int>(0, (sum, log) => sum + (log['actualMinutes'] as int));
    final totalMiles = weekly.fold<double>(0, (sum, log) => sum + (log['actualDistance'] as num).toDouble());
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        Text('This week: ${weekly.length} activities • $totalMinutes min • ${totalMiles.toStringAsFixed(2)} mi'),
        DropdownButtonFormField<String>(
          initialValue: filter, decoration: const InputDecoration(labelText: 'Filter history'),
          items: ['All', ...activityTypes].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
          onChanged: (value) => setState(() => filter = value ?? 'All'),
        ),
      ])),
      Expanded(child: shown.isEmpty
        ? const Center(child: Text('No completed activities yet.'))
        : ListView.builder(itemCount: shown.length, itemBuilder: (context, index) {
          final log = shown[index];
          return Card(child: ListTile(
            title: Text('${log['activityName']} • ${log['activityType']}'),
            subtitle: Text('${activityDateLabel(log['activityDate'] as String)} • '
              '${log['actualMinutes']} min • ${log['actualDistance']} mi'),
            onTap: () => editLog(log),
            trailing: IconButton(icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete activity', onPressed: () => deleteLog(log)),
          ));
        })),
    ]);
  }
}

class LogEditor extends StatefulWidget {
  final Record log;
  const LogEditor({super.key, required this.log});

  @override
  State<LogEditor> createState() => _LogEditorState();
}

class _LogEditorState extends State<LogEditor> {
  final formKey = GlobalKey<FormState>();
  late final minutes = TextEditingController(text: widget.log['actualMinutes'].toString());
  late final distance = TextEditingController(text: widget.log['actualDistance'].toString());
  late final notes = TextEditingController(text: widget.log['notes'] as String? ?? '');
  bool saving = false;

  @override
  void dispose() { minutes.dispose(); distance.dispose(); notes.dispose(); super.dispose(); }

  Future<void> save() async {
    if (saving || !formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await (await AppDb.database).update('training_log', {
        'actualMinutes': int.parse(minutes.text.trim()),
        'actualDistance': double.parse(distance.text.trim()),
        'notes': notes.text.trim(),
      }, where: 'id = ?', whereArgs: [widget.log['id']]);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) showMessage(context, 'Unable to update activity.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit completed activity')),
    body: Form(key: formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
      Text(widget.log['activityName'] as String, style: Theme.of(context).textTheme.titleLarge),
      TextFormField(controller: minutes, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Actual minutes'),
        validator: (value) {
          final n = int.tryParse(value?.trim() ?? '');
          return n == null || n <= 0 ? 'Enter a positive whole number' : null;
        }),
      TextFormField(controller: distance,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Actual distance (miles)'),
        validator: (value) {
          final n = double.tryParse(value?.trim() ?? '');
          return n == null || !n.isFinite || n <= 0 ? 'Enter a positive distance' : null;
        }),
      TextFormField(controller: notes, maxLines: 3,
        decoration: const InputDecoration(labelText: 'Notes')),
      const SizedBox(height: 16),
      FilledButton(onPressed: saving ? null : save, child: const Text('Save changes')),
    ])),
  );
}

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  int weeklyGoal = 3;
  bool encouragement = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      weeklyGoal = prefs.getInt('weeklyGoal') ?? 3;
      encouragement = prefs.getBool('encouragement') ?? true;
    });
  }

  Future<void> updateGoal(double value) async {
    final goal = value.round();
    setState(() => weeklyGoal = goal);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('weeklyGoal', goal);
  }

  Future<void> updateEncouragement(bool value) async {
    setState(() => encouragement = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('encouragement', value);
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    Text('Weekly activity goal: $weeklyGoal', style: Theme.of(context).textTheme.titleMedium),
    Slider(value: weeklyGoal.toDouble(), min: 1, max: 14, divisions: 13,
      label: '$weeklyGoal activities', onChanged: (value) => setState(() => weeklyGoal = value.round()),
      onChangeEnd: updateGoal),
    SwitchListTile(title: const Text('Motivational messages'),
      subtitle: const Text('Show an encouraging message on the dashboard'),
      value: encouragement, onChanged: updateEncouragement),
    const Divider(),
    const ListTile(title: Text('Distance unit'), subtitle: Text('Miles (current version)')),
    const ListTile(title: Text('About'), subtitle: Text('Movement Quest • Offline activity tracker')),
  ]);
}
