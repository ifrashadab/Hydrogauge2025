import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'history_screen.dart';
import 'package:hydrogauge/widgets/hover_bubble.dart';

class SupervisorScreen extends StatelessWidget {
  const SupervisorScreen({super.key});

  static final List<_Agent> _agents = [
    _Agent(id: 'A101', name: 'Ravi Kumar', phone: '+91 98765 43210', lat: 19.0760, lng: 72.8777, lastLevelM: 3.2, lastTime: '2025-10-02 08:05'),
    _Agent(id: 'A102', name: 'Priya Singh', phone: '+91 98765 43211', lat: 19.2183, lng: 72.9781, lastLevelM: 2.6, lastTime: '2025-10-02 07:50'),
    _Agent(id: 'A103', name: 'Arjun Patel', phone: '+91 98765 43212', lat: 18.9900, lng: 72.8300, lastLevelM: 4.1, lastTime: '2025-10-02 08:10'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supervisor – Team Overview')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // KPI row
          Row(
            children: [
              Expanded(
                child: _KpiTile(
                  label: 'Agents',
                  value: _agents.length.toString(),
                  color: Colors.indigo,
                  icon: Icons.group,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiTile(
                  label: 'Alerts',
                  value: _agents.where((a) => a.lastLevelM >= 4.0).length.toString(),
                  color: Colors.red,
                  icon: Icons.warning_amber_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiTile(
                  label: 'Avg level (m)',
                  value: (_agents.map((a) => a.lastLevelM).fold<double>(0, (s, n) => s + n) / _agents.length)
                      .toStringAsFixed(2),
                  color: Colors.teal,
                  icon: Icons.water_drop,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SupervisorMap(agents: _agents),
          const SizedBox(height: 12),
          const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.8,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: [
              _FeatureCard(
                color: Colors.blue,
                icon: Icons.history,
                title: 'View History',
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
                },
              ),
              _FeatureCard(
                color: Colors.orange,
                icon: Icons.warning_amber_rounded,
                title: 'Alerts Center',
                onTap: () {
                  _showAlerts(context);
                },
              ),
              _FeatureCard(
                color: Colors.purple,
                icon: Icons.file_download,
                title: 'Export CSV',
                onTap: () async {
                  await _exportCsv(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Agents', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ..._agents.map((a) => Card(
                child: HoverBubble(
                  child: ListTile(
                  leading: CircleAvatar(child: Text(a.name.substring(0, 1))),
                  title: Text(a.name),
                  subtitle: Text('ID: ${a.id}  •  ${a.lat.toStringAsFixed(3)}, ${a.lng.toStringAsFixed(3)}\nLast: ${a.lastTime}'),
                  isThreeLine: true,
                  trailing: _LevelChip(level: a.lastLevelM),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (_) => _AgentSheet(agent: a),
                    );
                  },
                ),
              ),
              )),
        ],
      ),
    );
  }

  void _showAlerts(BuildContext context) {
    final critical = _agents.where((a) => a.lastLevelM >= 4.0).toList();
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Alerts Center', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (critical.isEmpty) const Text('No active alerts.') else ...[
                for (final a in critical)
                  ListTile(
                    leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    title: Text(a.name),
                    subtitle: Text('Level ${a.lastLevelM.toStringAsFixed(2)} m  •  ${a.lastTime}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).pop();
                      showModalBottomSheet(context: context, builder: (_) => _AgentSheet(agent: a));
                    },
                  ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final src = File('${dir.path}/readings.txt');
      if (!await src.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No readings found to export.')),
        );
        return;
      }
      final dest = File('${dir.path}/readings_export.csv');
      final contents = await src.readAsString();
      // readings.txt is already CSV-like: time,lat,lng,level,photoPath
      await dest.writeAsString(contents);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported CSV to ${dest.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export failed.')),
      );
    }
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.label, required this.value, required this.color, required this.icon});
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(radius: 16, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text(label, style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.title, required this.icon, required this.color, required this.onTap});
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(radius: 18, backgroundColor: color, child: Icon(icon, color: Colors.white)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level});
  final double level;

  @override
  Widget build(BuildContext context) {
    final Color c = level >= 4.0 ? Colors.red : (level >= 3.0 ? Colors.orange : Colors.green);
    return Chip(
      label: Text('${level.toStringAsFixed(2)} m'),
      backgroundColor: c.withOpacity(0.15),
      labelStyle: TextStyle(color: c, fontWeight: FontWeight.w700),
      side: BorderSide(color: c),
    );
  }
}

class _SupervisorMap extends StatelessWidget {
  const _SupervisorMap({required this.agents});
  final List<_Agent> agents;

  @override
  Widget build(BuildContext context) {
    final center = latlng.LatLng(19.0760, 72.8777); // Mumbai
    return Container(
      height: 220,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueGrey),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: 10),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.hydrogauge',
          ),
          MarkerLayer(
            markers: agents
                .map((a) => Marker(
                      point: latlng.LatLng(a.lat, a.lng),
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 32),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AgentSheet extends StatelessWidget {
  const _AgentSheet({required this.agent});
  final _Agent agent;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(agent.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('ID: ${agent.id}'),
            Text('Location: ${agent.lat}, ${agent.lng}'),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Last level: '),
                _LevelChip(level: agent.lastLevelM),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.phone, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(agent.phone)),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () async {
                  final uri = Uri(scheme: 'tel', path: agent.phone.replaceAll(' ', ''));
                  try {
                    final launched = await launchUrl(uri);
                    if (!launched) {
                      // ignore silently if cannot launch
                    }
                  } catch (_) {
                    // ignore errors to avoid crashing UI
                  }
                },
                icon: const Icon(Icons.call),
                label: const Text('Call'),
              ),
            ],
          ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: FlutterMap(
                options: MapOptions(initialCenter: latlng.LatLng(agent.lat, agent.lng), initialZoom: 13),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.hydrogauge',
                  ),
                  MarkerLayer(markers: [
                    Marker(
                      point: latlng.LatLng(agent.lat, agent.lng),
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Colors.red),
                    )
                  ])
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _Agent {
  final String id;
  final String name;
  final String phone;
  final double lat;
  final double lng;
  final double lastLevelM;
  final String lastTime;
  const _Agent({required this.id, required this.name, required this.phone, required this.lat, required this.lng, required this.lastLevelM, required this.lastTime});
}


