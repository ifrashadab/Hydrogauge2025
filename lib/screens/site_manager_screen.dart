import 'package:flutter/material.dart';
import 'package:hydrogauge/services/sites_store.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

class SiteManagerScreen extends StatefulWidget {
  const SiteManagerScreen({super.key});

  @override
  State<SiteManagerScreen> createState() => _SiteManagerScreenState();
}

class _SiteManagerScreenState extends State<SiteManagerScreen> {
  final _id = TextEditingController();
  final _name = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _rad = TextEditingController(text: '300');
  bool _saving = false;
  final _address = TextEditingController();
  bool _searching = false;
  latlng.LatLng? _previewPoint;

  @override
  void initState() {
    super.initState();
    SitesStore.instance.load();
    _lat.addListener(_onLatLngChanged);
    _lng.addListener(_onLatLngChanged);
  }

  void _onLatLngChanged() {
    final la = double.tryParse(_lat.text.trim());
    final lo = double.tryParse(_lng.text.trim());
    if (la != null && lo != null) {
      setState(() => _previewPoint = latlng.LatLng(la, lo));
    }
  }

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _lat.dispose();
    _lng.dispose();
    _rad.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Sites')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add Site', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            TextField(
              controller: _address,
              decoration: InputDecoration(
                labelText: 'Search location (address, place, coordinates)',
                suffixIcon: IconButton(
                  icon: _searching ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
                  onPressed: _searching
                      ? null
                      : () async {
                          final query = _address.text.trim();
                          if (query.isEmpty) return;
                          setState(() => _searching = true);
                          try {
                            // If user enters "lat,lng" directly
                            final parts = query.split(',');
                            if (parts.length == 2) {
                              final la = double.tryParse(parts[0].trim());
                              final lo = double.tryParse(parts[1].trim());
                              if (la != null && lo != null) {
                                _lat.text = la.toString();
                                _lng.text = lo.toString();
                                setState(() => _previewPoint = latlng.LatLng(la, lo));
                                setState(() => _searching = false);
                                return;
                              }
                            }
                            final marks = await locationFromAddress(query);
                            if (marks.isNotEmpty) {
                              final m = marks.first;
                              _lat.text = m.latitude.toString();
                              _lng.text = m.longitude.toString();
                              setState(() => _previewPoint = latlng.LatLng(m.latitude, m.longitude));
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No results found')));
                              }
                            }
                          } catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search failed')));
                            }
                          } finally {
                            if (mounted) setState(() => _searching = false);
                          }
                        },
                ),
              ),
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _id, decoration: const InputDecoration(labelText: 'Site ID'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name'))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _lat, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _lng, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 8),
              SizedBox(width: 120, child: TextField(controller: _rad, decoration: const InputDecoration(labelText: 'Radius m'), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _previewPoint == null
                    ? Container(
                        decoration: BoxDecoration(border: Border.all(color: Colors.blueGrey), borderRadius: BorderRadius.circular(12)),
                        child: const Center(child: Text('Map preview (search to preview)')),
                      )
                    : FlutterMap(
                        options: MapOptions(initialCenter: _previewPoint!, initialZoom: 14),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.hydrogauge',
                          ),
                          MarkerLayer(markers: [
                            Marker(point: _previewPoint!, width: 40, height: 40, child: const Icon(Icons.place, color: Colors.red)),
                          ]),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving
                  ? null
                  : () async {
                      final id = _id.text.trim();
                      final name = _name.text.trim();
                      final lat = double.tryParse(_lat.text.trim());
                      final lng = double.tryParse(_lng.text.trim());
                      final rad = double.tryParse(_rad.text.trim());
                      if (id.isEmpty || name.isEmpty || lat == null || lng == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all fields correctly')));
                        return;
                      }
                      setState(() => _saving = true);
                      await SitesStore.instance.add(Site(id: id, name: name, lat: lat, lng: lng, radiusMeters: rad));
                      setState(() => _saving = false);
                      _id.clear();
                      _name.clear();
                      _lat.clear();
                      _lng.clear();
                      _rad.text = '300';
                      _address.clear();
                      setState(() => _previewPoint = null);
                    },
              icon: const Icon(Icons.add),
              label: Text(_saving ? 'Adding…' : 'Add Site'),
            ),
            const SizedBox(height: 16),
            const Text('Sites', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Expanded(
              child: ValueListenableBuilder<List<Site>>(
                valueListenable: SitesStore.instance.sites,
                builder: (_, list, __) {
                  if (list.isEmpty) return const Center(child: Text('No sites yet'));
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final s = list[i];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.place),
                          title: Text('${s.name} (${s.id})'),
                          subtitle: Text('${s.lat.toStringAsFixed(5)}, ${s.lng.toStringAsFixed(5)}  •  radius ${ (s.radiusMeters ?? 300).toStringAsFixed(0)} m'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => SitesStore.instance.removeById(s.id),
                          ),
                        ),
                      );
                    },
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


