import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:hydrogauge/widgets/hover_bubble.dart';

class AnalystScreen extends StatefulWidget {
  const AnalystScreen({super.key});

  @override
  State<AnalystScreen> createState() => _AnalystScreenState();
}

class _AnalystScreenState extends State<AnalystScreen> {
  int _index = 0; // 0 Overview, 1 Trends, 2 Alerts, 3 Reports, 4 Profile
  String _region = 'Mumbai';

  static final List<_SiteLevel> _levels = [
    _SiteLevel(city: 'Mumbai', lat: 19.0760, lng: 72.8777, levelM: 3.6),
    _SiteLevel(city: 'Thane', lat: 19.2183, lng: 72.9781, levelM: 2.7),
    _SiteLevel(city: 'Navi Mumbai', lat: 19.0330, lng: 73.0297, levelM: 4.3),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyst — Regional Overview'),
        actions: [
          // Global filters (region, date, refresh)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _region,
                items: const [
                  DropdownMenuItem(value: 'Mumbai', child: Text('Mumbai')),
                  DropdownMenuItem(value: 'Pune', child: Text('Pune')),
                  DropdownMenuItem(value: 'Nashik', child: Text('Nashik')),
                ],
                onChanged: (v) => setState(() => _region = v ?? _region),
              ),
            ),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.calendar_month)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _IssueAlertSheet(),
          );
        },
        label: const Text('Issue Alert'),
        icon: const Icon(Icons.add_alert),
        backgroundColor: Colors.redAccent,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Trends'),
          NavigationDestination(icon: Icon(Icons.warning_amber_rounded), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.insert_chart_outlined), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_index) {
      case 0:
        return _Overview(levels: _levels);
      case 1:
        return _Trends(levels: _levels);
      case 2:
        return const _Alerts();
      case 3:
        return const _Reports();
      case 4:
        return const _ProfileSettings();
      default:
        return _Overview(levels: _levels);
    }
  }
}

class _SimpleBarChart extends StatelessWidget {
  const _SimpleBarChart({required this.levels});
  final List<_SiteLevel> levels;

  @override
  Widget build(BuildContext context) {
    final maxLevel = levels.map((e) => e.levelM).fold<double>(0, (p, n) => n > p ? n : p);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 6))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: levels.map((l) {
          final ratio = maxLevel == 0 ? 0.0 : (l.levelM / maxLevel);
          final c = l.levelM >= 4.0 ? Colors.red : (l.levelM >= 3.0 ? Colors.orange : Colors.green);
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.levelM.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 100 * ratio + 10,
                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
                ),
                const SizedBox(height: 6),
                Text(l.city, style: const TextStyle(fontSize: 12)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.levels});
  final List<_SiteLevel> levels;

  @override
  Widget build(BuildContext context) {
    final center = latlng.LatLng(19.0760, 72.8777);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Map with colored markers
        Container(
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blueGrey),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 10.5),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.hydrogauge',
              ),
              MarkerLayer(
                markers: levels.map((l) {
                  // Color coding retained for future use
                  // final c = l.levelM >= 4.0 ? Colors.red : (l.levelM >= 3.0 ? Colors.orange : Colors.green);
                  return Marker(
                    point: latlng.LatLng(l.lat, l.lng),
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.place, color: Colors.blue),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Recent Levels', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _SimpleBarChart(levels: levels),
        const SizedBox(height: 16),
        ...levels.map((l) => Card(
              child: HoverBubble(
                child: ListTile(
                  leading: const Icon(Icons.water_drop),
                  title: Text('${l.city} – ${l.levelM.toStringAsFixed(2)} m'),
                  subtitle: const Text('Risk score is based on thresholds 3.0 and 4.0 m'),
                ),
              ),
            )),
      ],
    );
  }
}

class _Trends extends StatelessWidget {
  const _Trends({required this.levels});
  final List<_SiteLevel> levels;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Trends', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          FilterChip(label: const Text('Water Level'), selected: true, onSelected: (_) {}),
          FilterChip(label: const Text('Rainfall'), selected: false, onSelected: (_) {}),
          FilterChip(label: const Text('Temperature'), selected: false, onSelected: (_) {}),
        ]),
        const SizedBox(height: 12),
        _SimpleBarChart(levels: levels),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Predictive thresholds', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text('Overlay lines show thresholds for likely risk over next 7–30 days.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Alerts extends StatelessWidget {
  const _Alerts();

  @override
  Widget build(BuildContext context) {
    final items = const [
      _AlertCard(title: 'Navi Mumbai — 4.3 m', subtitle: 'Exceeded by 0.3 m • 9:55 PM • High', statusColor: Colors.red),
      _AlertCard(title: 'Thane — 3.2 m', subtitle: 'Under review • 9:40 PM • Medium', statusColor: Colors.orange),
      _AlertCard(title: 'Mumbai — 2.7 m', subtitle: 'Resolved • 6:10 PM • Low', statusColor: Colors.green),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Alerts', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 8),
        const Wrap(spacing: 8, children: [
          Chip(label: Text('All')),
          Chip(label: Text('Active')),
          Chip(label: Text('Resolved')),
        ]),
        const SizedBox(height: 12),
        ...items,
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.title, required this.subtitle, required this.statusColor});
  final String title;
  final String subtitle;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded, color: statusColor),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }
}

class _Reports extends StatelessWidget {
  const _Reports();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Reports', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _ReportCard(title: 'Export as PDF', icon: Icons.picture_as_pdf, color: Colors.purple)),
            const SizedBox(width: 12),
            Expanded(child: _ReportCard(title: 'Export as Excel', icon: Icons.grid_on, color: Colors.green)),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Region-wise breakdown'),
                SizedBox(height: 6),
                Text('Select time range and generate summaries.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.title, required this.icon, required this.color});
  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: HoverBubble(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(radius: 18, backgroundColor: color, child: Icon(icon, color: Colors.white)),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSettings extends StatelessWidget {
  const _ProfileSettings();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ListTile(leading: Icon(Icons.person), title: Text('Account')), 
        Divider(),
        ListTile(leading: Icon(Icons.tune), title: Text('Region Filters')),
        Divider(),
        ListTile(leading: Icon(Icons.logout), title: Text('Logout')),
      ],
    );
  }
}

class _IssueAlertSheet extends StatelessWidget {
  const _IssueAlertSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Issue Alert', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 12),
            const _Labeled('Region/Site'),
            const SizedBox(height: 6),
            const _FakeDropdown(values: ['Mumbai', 'Thane', 'Navi Mumbai']),
            const SizedBox(height: 12),
            const _Labeled('Current Reading (auto-filled)')
            ,
            const Text('4.3 m', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const _Labeled('Severity')
            ,
            const Wrap(spacing: 8, children: [
              ChoiceChip(label: Text('Low'), selected: false),
              ChoiceChip(label: Text('Medium'), selected: true),
              ChoiceChip(label: Text('High'), selected: false),
            ]),
            const SizedBox(height: 12),
            const _Labeled('Remarks')
            ,
            const TextField(maxLines: 3),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.send), label: const Text('Submit')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w600));
  }
}

class _FakeDropdown extends StatelessWidget {
  const _FakeDropdown({required this.values});
  final List<String> values;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 18),
          const SizedBox(width: 8),
          Text(values.first),
          const Spacer(),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

class _SiteLevel {
  final String city;
  final double lat;
  final double lng;
  final double levelM;
  const _SiteLevel({required this.city, required this.lat, required this.lng, required this.levelM});
}


