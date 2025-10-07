import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hydrogauge/services/sites_store.dart';
import 'package:hydrogauge/services/visits_store.dart';

class ScheduleVisitScreen extends StatefulWidget {
  const ScheduleVisitScreen({super.key});

  @override
  State<ScheduleVisitScreen> createState() => _ScheduleVisitScreenState();
}

class _ScheduleVisitScreenState extends State<ScheduleVisitScreen> {
  DateTime _date = DateTime.now();
  String _timeLabel = '10:00 AM';
  Site? _site;
  VisitType _type = VisitType.routine;
  VisitPriority _priority = VisitPriority.medium;
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    SitesStore.instance.load();
    VisitsStore.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule Visit')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<List<Site>>(
              valueListenable: SitesStore.instance.sites,
              builder: (_, sites, __) => DropdownButtonFormField<Site>(
                initialValue: _site,
                items: sites.map((s) => DropdownMenuItem(value: s, child: Text('${s.name} (${s.id})'))).toList(),
                onChanged: (v) => setState(() => _site = v),
                decoration: const InputDecoration(labelText: 'Site', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('yyyy-MM-dd').format(_date)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final now = TimeOfDay.now();
                    final t = await showTimePicker(context: context, initialTime: now);
                    if (t != null) {
                      setState(() => _timeLabel = t.format(context));
                    }
                  },
                  icon: const Icon(Icons.schedule),
                  label: Text(_timeLabel),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<VisitType>(
                  initialValue: _type,
                  items: const [
                    DropdownMenuItem(value: VisitType.routine, child: Text('Routine')),
                    DropdownMenuItem(value: VisitType.inspection, child: Text('Inspection')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? _type),
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<VisitPriority>(
                  initialValue: _priority,
                  items: const [
                    DropdownMenuItem(value: VisitPriority.low, child: Text('Low')),
                    DropdownMenuItem(value: VisitPriority.medium, child: Text('Medium')),
                    DropdownMenuItem(value: VisitPriority.high, child: Text('High')),
                  ],
                  onChanged: (v) => setState(() => _priority = v ?? _priority),
                  decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving
                  ? null
                  : () async {
                      if (_site == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a site')));
                        return;
                      }
                      setState(() => _saving = true);
                      final v = Visit(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        date: DateTime(_date.year, _date.month, _date.day),
                        time: _timeLabel,
                        siteId: _site!.id,
                        siteName: _site!.name,
                        type: _type,
                        priority: _priority,
                        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                      );
                      await VisitsStore.instance.add(v);
                      if (!mounted) return;
                      Navigator.of(context).pop(true);
                    },
              icon: const Icon(Icons.add_task),
              label: Text(_saving ? 'Saving…' : 'Schedule Visit'),
            ),
          ],
        ),
      ),
    );
  }
}


