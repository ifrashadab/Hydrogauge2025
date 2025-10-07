import 'package:flutter/material.dart';
import 'history_detail_screen.dart';
import 'package:hydrogauge/services/api_client.dart';
import 'package:hydrogauge/services/auth_store.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<_Entry> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = AuthStore.instance.token.value;
      if (token != null && token.isNotEmpty) {
        final resp = await ApiClient().listSubmissions(token: token, limit: 100);
        if (resp['ok'] == true && resp['submissions'] is List) {
          final arr = (resp['submissions'] as List).cast<dynamic>();
          final items = arr.map((j) {
            final m = (j as Map).cast<String, dynamic>();
            return _Entry(
              m['capturedAt']?.toString() ?? '',
              m['lat']?.toString() ?? '',
              m['lng']?.toString() ?? '',
              (m['waterLevelMeters']?.toString() ?? ''),
              m['imageUrl']?.toString(),
            );
          }).where((e) => e.time.isNotEmpty).toList();
          setState(() => _entries = items);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_entries.isEmpty) {
      return const Center(child: Text('No history yet'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (ctx, i) {
        final e = _entries[i];
        return ListTile(
          leading: const Icon(Icons.water_drop),
          title: Text('${e.level} m  •  ${e.time.substring(0, 19)}'),
          subtitle: Text('${e.lat}, ${e.lng}'),
          trailing: e.photoPath != null ? const Icon(Icons.image) : null,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HistoryDetailScreen(entry: '${e.time},${e.lat},${e.lng},${e.level},${e.photoPath ?? ''}'),
              ),
            );
          },
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: _entries.length,
    );
  }
}

class _Entry {
  final String time;
  final String lat;
  final String lng;
  final String level;
  final String? photoPath;

  _Entry(this.time, this.lat, this.lng, this.level, this.photoPath);
}