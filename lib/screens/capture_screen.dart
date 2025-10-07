import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:hydrogauge/services/gauge_counter.dart';
import 'package:hydrogauge/services/api_client.dart';
import 'package:hydrogauge/services/sites_store.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, this.onAddressChange});
  final ValueChanged<String>? onAddressChange;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  Position? _position;
  String _address = '';
  String? _photoPath;
  int? _detectedGaugePosts;
  final TextEditingController _readingCtrl = TextEditingController();
  StreamSubscription<Position>? _posSub;
  bool _liveLocation = true;
  Site? _site; // selected monitoring site
  static const double _allowedRadiusMeters = 150; // configurable geofence radius
  bool? _wasInside; // track geofence transitions for haptics/animations
  final ApiClient _api = ApiClient();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    SitesStore.instance.load();
  }

  bool get _isInsideSelectedSiteArea {
    if (_position == null || _site == null) return false;
    final d = _distanceMeters(
      _position!.latitude,
      _position!.longitude,
      _site!.lat,
      _site!.lng,
    );
    return d <= _activeRadiusMeters;
  }

  double get _activeRadiusMeters => _site?.radiusMeters ?? _allowedRadiusMeters;

  // ------- Location + reverse geocode -------
  Future<void> _getLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location is OFF. Turn it on.')),
      );
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied.')),
        );
        return;
      }
    }
    if (p == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied forever. Open settings.')),
      );
      await Geolocator.openAppSettings();
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      setState(() => _position = pos);
      await _reverseGeocode(pos);
      if (_liveLocation) _subscribePositionStream();
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        setState(() => _position = last);
        await _reverseGeocode(last);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Using last known location.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to get location.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Location error: $e')));
    }
  }

  void _subscribePositionStream() {
    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((pos) {
      setState(() => _position = pos);
      if (_site != null) {
        final nowInside = _isInsideSelectedSiteArea;
        if (_wasInside != null && _wasInside != nowInside) {
          if (nowInside) {
            HapticFeedback.mediumImpact();
          } else {
            HapticFeedback.selectionClick();
          }
        }
        _wasInside = nowInside;
      }
    });
  }

  Future<void> _reverseGeocode(Position pos) async {
    try {
      final marks = await Future.any<List<Placemark>>([
        placemarkFromCoordinates(pos.latitude, pos.longitude),
        Future<List<Placemark>>.delayed(const Duration(seconds: 5), () => const []),
      ]);
      if (marks.isNotEmpty) {
        final p = marks.first;
        final addr = [
          p.name,
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
          p.postalCode
        ].where((e) => (e ?? '').trim().isNotEmpty).join(', ');
        setState(() => _address = addr);
        widget.onAddressChange?.call(addr);
        return;
      }
    } catch (e) {
      // ignore and fall back to coordinates
    }

    final coords = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
    setState(() => _address = coords);
    widget.onAddressChange?.call(coords);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address lookup failed. Using coordinates.')),
      );
    }
  }

  // ------- Camera -------
  Future<void> _openCamera() async {
    if (!mounted) return;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _CameraPage(),
      ),
    );
    if (!mounted) return;
    if (result != null && result.isNotEmpty) {
      setState(() {
        _photoPath = result;
        _detectedGaugePosts = null; // reset previous detection
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo captured')),
      );
      // Kick off AI detection (non-blocking)
      _detectGaugePosts(result);
    }
  }

  Future<void> _detectGaugePosts(String imagePath) async {
    try {
      final counter = const GaugeCounter();
      final count = await counter.countPosts(imagePath);
      if (!mounted) return;
      setState(() => _detectedGaugePosts = count);
      if (count != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Detected gauge posts: $count')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not detect gauge posts')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Detection error: $e')),
      );
    }
  }

  // ------- QR Scan -------
  Future<void> _scanQr() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) {
        return SafeArea(
          child: _QrScannerSheet(
            onDetect: (value) {
              Navigator.of(ctx).pop();
              final trimmed = value.trim();
              if (trimmed.isEmpty) return;
              // Try parse as site QR: expected JSON {id, name, lat, lng}
              try {
                final map = _tryParseJson(trimmed);
                if (map != null && map['id'] is String && map['lat'] is num && map['lng'] is num) {
                  setState(() {
                    _site = Site(
                      id: map['id'] as String,
                      name: (map['name'] as String?) ?? 'Site',
                      lat: (map['lat'] as num).toDouble(),
                      lng: (map['lng'] as num).toDouble(),
                    );
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Site selected: ${_site!.name}')),
                  );
                  return;
                }
              } catch (_) {}

              // Fallback: numeric reading
              final numeric = double.tryParse(trimmed);
              if (numeric != null) {
                _readingCtrl.text = trimmed;
                _showSuccessPulse(message: 'Reading filled from QR');
              } else {
                _showSuccessPulse(message: 'Scanned');
              }
            },
          ),
        );
      },
    );
  }

  // ------- Save to backend -------
  Future<void> _save() async {
    if (_position == null || _photoPath == null || _readingCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete location, photo, and level.')),
      );
      return;
    }
    if (_site == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a site (scan QR)')),
      );
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // In a real app, upload the image and get a URL. For now, send the local path.
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final resp = await _api.submitMeasurement(
        id: id,
        siteId: _site!.id,
        siteName: _site!.name,
        waterLevelMeters: double.parse(_readingCtrl.text.trim()),
        lat: _position!.latitude,
        lng: _position!.longitude,
        capturedAt: DateTime.now(),
        imageUrl: _photoPath!,
        deviceId: 'flutter-app',
      );
      if (resp['ok'] == true) {
        _showSuccessPulse(message: 'Submitted');
        _readingCtrl.clear();
        setState(() => _photoPath = null);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit failed: ${resp['error'] ?? 'Unknown'}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _readingCtrl.dispose();
    super.dispose();
  }

  // ------- UI -------
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    const pad = 16.0;
    const gap = 14.0;
    const double rectHeight = 110; // <-- fixed height so both rectangles match
    final leftWidth = (w - pad * 2 - gap) * 0.40; // two rectangles column
    final rightWidth = (w - pad * 2 - gap) * 0.60; // big square

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0F7FF), Color(0xFFE6EEFF), Color(0xFFF7F9FF)],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(pad),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // Mock site selector (shared store)
          ValueListenableBuilder<List<Site>>(
            valueListenable: SitesStore.instance.sites,
            builder: (context, sites, _) {
              return DropdownButtonFormField<Site>(
                initialValue: _site,
                decoration: const InputDecoration(
                  labelText: 'Select mock site (for testing)',
                  border: OutlineInputBorder(),
                ),
                items: sites
                    .map((s) => DropdownMenuItem<Site>(value: s, child: Text('${s.name} (${s.id})')))
                    .toList(),
                onChanged: (v) => setState(() {
                  _site = v;
                  _wasInside = (_site != null) ? _isInsideSelectedSiteArea : null;
                }),
              );
            },
          ),
          const SizedBox(height: 8),
          if (_site != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: Container(
                key: ValueKey(_site!.id),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.green.shade100.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Text(
                'Site: ${_site!.name} (ID: ${_site!.id})',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              ),
            ),
          const SizedBox(height: gap),

          // Row: two rectangles (left) + one big square (right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: leftWidth,
                child: Column(
                  children: [
                    _RectButton(
                      height: rectHeight,               // <- same height
                      icon: Icons.my_location,
                      label: 'Get Location',
                      onTap: _getLocation,
                    ),
                    const SizedBox(height: gap),
                    _RectButton(
                      height: rectHeight,               // <- same height
                      icon: Icons.qr_code_scanner,
                      label: 'Scan QR (site or reading)',
                      onTap: _scanQr,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: gap),
              SizedBox(
                width: rightWidth,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.95, end: _isInsideSelectedSiteArea ? 1.0 : 0.95),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) {
                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _isInsideSelectedSiteArea ? 1 : 0.6,
                        child: Transform.scale(
                          scale: scale,
                          child: child,
                        ),
                      );
                    },
                    child: _SquareBigButton(
                      icon: Icons.camera_alt,
                      label: 'Open Camera',
                      onTap: _isInsideSelectedSiteArea
                          ? () {
                              HapticFeedback.lightImpact();
                              _openCamera();
                            }
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Move inside the site area to capture photo')),
                              );
                              HapticFeedback.selectionClick();
                            },
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: gap),

          // Manual entry
          TextField(
            controller: _readingCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Enter manual data (water level, m)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: gap),

          // AI-detected gauge posts (from captured photo)
          if (_detectedGaugePosts != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.analytics_outlined, color: Colors.indigo),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Detected gauge posts: $_detectedGaugePosts',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (_detectedGaugePosts != null) {
                          _readingCtrl.text = _detectedGaugePosts!.toString();
                          _showSuccessPulse(message: 'Filled from AI detection');
                        }
                      },
                      child: const Text('Use'),
                    ),
                  ],
                ),
              ),
            ),
          if (_detectedGaugePosts != null) const SizedBox(height: gap),

          // Photo preview (animated)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _photoPath != null
                ? Container(
                    key: ValueKey(_photoPath),
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 14, offset: const Offset(0, 6)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.file(File(_photoPath!), fit: BoxFit.cover),
                  )
                : const SizedBox.shrink(),
          ),
          if (_photoPath != null) const SizedBox(height: gap),

          // Live Map with geofence status
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: _isInsideSelectedSiteArea ? Colors.green : Colors.blueGrey),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (_isInsideSelectedSiteArea ? Colors.green : Colors.black).withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
              color: Colors.white,
            ),
            clipBehavior: Clip.antiAlias,
            child: _position == null
                ? const Center(child: Text('Tap Get Location to start'))
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: latlng.LatLng(_position!.latitude, _position!.longitude),
                      initialZoom: 15,
                      onMapReady: () {},
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.hydrogauge',
                      ),
                      if (_site != null)
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: latlng.LatLng(_site!.lat, _site!.lng),
                              color: (_isInsideSelectedSiteArea
                                      ? Colors.green.withOpacity(0.20)
                                      : Colors.orange.withOpacity(0.20)),
                              borderColor: _isInsideSelectedSiteArea ? Colors.green : Colors.orange,
                              borderStrokeWidth: 2,
                              useRadiusInMeter: true,
                              radius: _activeRadiusMeters,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: latlng.LatLng(_position!.latitude, _position!.longitude),
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 36),
                          ),
                          if (_site != null)
                            Marker(
                              point: latlng.LatLng(_site!.lat, _site!.lng),
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.flag, color: Colors.blue, size: 30),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          if (_address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _address,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
              ),
            ),
          if (_site != null && _position != null)
            Builder(builder: (_) {
              final d = _distanceMeters(_position!.latitude, _position!.longitude, _site!.lat, _site!.lng);
              final inside = d <= _activeRadiusMeters;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: inside ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: inside ? Colors.green.shade200 : Colors.orange.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: (inside ? Colors.green : Colors.orange).withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  inside
                      ? 'Inside geofence (within ${_activeRadiusMeters.toStringAsFixed(0)} m)'
                      : 'Outside geofence by ${d.toStringAsFixed(0)} m',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              );
            }),
          Row(
            children: [
              Switch(
                value: _liveLocation,
                onChanged: (v) {
                  setState(() => _liveLocation = v);
                  if (v) {
                    if (_position != null) _subscribePositionStream();
                  } else {
                    _posSub?.cancel();
                    _posSub = null;
                  }
                },
              ),
              const SizedBox(width: 8),
              const Text('Live location'),
            ],
          ),
          const SizedBox(height: gap),

          // Save
          FilledButton.icon(
            onPressed: () {
              if (_site == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Scan site QR to select a monitoring site')),
                );
                return;
              }
              if (_position == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Get current location before saving')),
                );
                return;
              }
              final dist = _distanceMeters(_position!.latitude, _position!.longitude, _site!.lat, _site!.lng);
              if (dist > _activeRadiusMeters) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Outside allowed zone (${dist.toStringAsFixed(0)} m)')),
                );
                return;
              }
              if (_photoPath == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Capture live photo before saving')),
                );
                return;
              }
              HapticFeedback.lightImpact();
              _save();
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.save),
            label: Text(_saving ? 'Submitting…' : 'Save'),
          ),

          const SizedBox(height: 10),
          Text(
            'Now: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
        ),
      ),
    );
  }
}

// -------- helper buttons --------

class _RectButton extends StatelessWidget {
  const _RectButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.height = 110, // default
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquareBigButton extends StatelessWidget {
  const _SquareBigButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ------- Bottom sheet widget for QR scanning -------
class _QrScannerSheet extends StatefulWidget {
  const _QrScannerSheet({required this.onDetect});

  final ValueChanged<String> onDetect;

  @override
  State<_QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<_QrScannerSheet> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: const [
              Icon(Icons.qr_code_scanner, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Scan a QR code',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: MobileScanner(
            controller: MobileScannerController(facing: CameraFacing.back),
            onDetect: (capture) {
              if (_handled) return;
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final raw = barcodes.first.rawValue ?? '';
              if (raw.isEmpty) return;
              _handled = true;
              widget.onDetect(raw);
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Align the QR within the frame',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// (Removed bottom sheet camera variant in favor of fullscreen page)

// ------- Fullscreen Camera Page -------
class _CameraPage extends StatefulWidget {
  const _CameraPage();

  @override
  State<_CameraPage> createState() => _CameraPageState();
}

// ------- simple models/util -------
Map<String, dynamic>? _tryParseJson(String s) {
  try {
    return (s.isNotEmpty) ? (jsonDecode(s) as Map<String, dynamic>) : null;
  } catch (_) {
    return null;
  }
}

double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const double r = 6371000; // earth radius meters
  final double dLat = _deg2rad(lat2 - lat1);
  final double dLon = _deg2rad(lon2 - lon1);
  final double a =
      (math.sin(dLat / 2) * math.sin(dLat / 2)) +
          math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
              (math.sin(dLon / 2) * math.sin(dLon / 2));
  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

double _deg2rad(double deg) => deg * (3.141592653589793 / 180.0);

class _CameraPageState extends State<_CameraPage> {
  CameraController? _controller;
  bool _initializing = true;
  bool _shooting = false;
  bool _recording = false;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    try {
      final cams = await availableCameras();
      if (!mounted) return;
      if (cams.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No camera available')),
        );
        Navigator.of(context).maybePop();
        return;
      }
      _cameras = cams;
      _cameraIndex = 0;
      _controller = CameraController(_cameras[_cameraIndex], ResolutionPreset.max, enableAudio: true);
      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _initializing = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Camera error: $e')));
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_shooting) return;
    setState(() => _shooting = true);
    try {
      final file = await _controller!.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop<String>(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Capture failed: $e')));
      setState(() => _shooting = false);
    }
  }

  @override
  void dispose() {
    if (_recording) {
      // Best-effort stop on dispose without requiring a return value
      () async {
        try {
          await _controller?.stopVideoRecording();
        } catch (_) {}
      }();
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _initializing
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller!),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 12,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _toggleRecord,
                        icon: Icon(
                          _recording ? Icons.stop_circle_outlined : Icons.fiber_manual_record,
                          color: _recording ? Colors.redAccent : Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: _switchCamera,
                        icon: const Icon(Icons.cameraswitch, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                if (_recording)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 56,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.circle, size: 10, color: Colors.white),
                            SizedBox(width: 6),
                            Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _shooting ? null : _takePicture,
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(18),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        child: const Icon(Icons.camera_alt),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _switchCamera() async {
    if (_cameras.isEmpty) return;
    final nextIndex = (_cameraIndex + 1) % _cameras.length;
    try {
      setState(() => _initializing = true);
      if (_recording) {
        final file = await _controller!.stopVideoRecording();
        _recording = false;
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Recording saved: ${file.path.split('/').last}')));
        }
      }
      await _controller?.dispose();
      _cameraIndex = nextIndex;
      _controller = CameraController(_cameras[_cameraIndex], ResolutionPreset.max, enableAudio: true);
      await _controller!.initialize();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Switch failed: $e')));
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _toggleRecord() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      if (!_recording) {
        await _controller!.startVideoRecording();
        setState(() => _recording = true);
      } else {
        final file = await _controller!.stopVideoRecording();
        setState(() => _recording = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Recording saved: ${file.path.split('/').last}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Record error: $e')));
    }
  }
}

// ------- lightweight success pulse overlay -------
extension _SuccessPulse on _CaptureScreenState {
  void _showSuccessPulse({required String message}) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }
    final entry = OverlayEntry(
      builder: (_) {
        return _PulseWidget(message: message);
      },
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 900), () {
      entry.remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    });
  }
}

class _PulseWidget extends StatefulWidget {
  const _PulseWidget({required this.message});
  final String message;

  @override
  State<_PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<_PulseWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
  late final Animation<double> _scale = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: const Interval(0.2, 1.0, curve: Curves.easeOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _fade,
              builder: (_, __) => Container(color: Colors.black.withOpacity(0.05 * _fade.value)),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: ScaleTransition(
                scale: _scale,
                child: FadeTransition(
                  opacity: _fade,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.green.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 12)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(widget.message, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}