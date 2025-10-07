// Hydrogauge — Welcome → Login/Register → Field Home (Capture | History | Profile)
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const WaterLevelApp());
}

class WaterLevelApp extends StatelessWidget {
  const WaterLevelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HydroGauge',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const WelcomeScreen(),
    );
  }
}

// -------------------- WELCOME / AUTH --------------------
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HydroGauge')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Welcome to HydroGauge',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Secure water level capture with GPS, live photo and audit trail.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text('Login'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: const Text('Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String role = 'Field Personnel';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _email,
                  decoration:
                      const InputDecoration(labelText: 'Email / Employee ID'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  items: const [
                    DropdownMenuItem(
                        value: 'Field Personnel', child: Text('Field Personnel')),
                    DropdownMenuItem(
                        value: 'Supervisor', child: Text('Supervisor')),
                    DropdownMenuItem(value: 'Analyst', child: Text('Analyst')),
                  ],
                  onChanged: (v) => setState(() => role = v ?? role),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    if (role == 'Field Personnel') {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const FieldHome()),
                      );
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RolePlaceholderScreen(role: role),
                        ),
                      );
                    }
                  },
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final name = TextEditingController();
    final id = TextEditingController();
    final phone = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Full Name')),
                const SizedBox(height: 12),
                TextField(
                    controller: id,
                    decoration:
                        const InputDecoration(labelText: 'Employee ID')),
                const SizedBox(height: 12),
                TextField(
                    controller: phone,
                    decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Submit & Back to Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RolePlaceholderScreen extends StatelessWidget {
  final String role;
  const RolePlaceholderScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$role Dashboard')),
      body: const Center(
        child: Text('Supervisor/Analyst dashboard will come here.'),
      ),
    );
  }
}

// -------------------- FIELD HOME (Tabs) --------------------
class FieldHome extends StatefulWidget {
  const FieldHome({super.key});
  @override
  State<FieldHome> createState() => _FieldHomeState();
}

class _FieldHomeState extends State<FieldHome> {
  int _index = 0;
  final pages = const [CaptureScreen(), HistoryScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field – Capture')),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.camera_alt_outlined),
              selectedIcon: Icon(Icons.camera_alt),
              label: 'Capture'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// -------------------- CAPTURE SCREEN --------------------
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});
  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  Position? _position;
  String? _photoPath;
  final _readingCtrl = TextEditingController();

  Future<void> _getLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Turn on Location Services.')));
      }
      await Geolocator.openLocationSettings();
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied.')));
        }
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Permission permanently denied. Open settings.')));
      }
      await Geolocator.openAppSettings();
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      setState(() => _position = pos);
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        setState(() => _position = last);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Using last known location.')));
        }
      }
    }
  }

  Future<void> _openCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No camera available')));
        }
        return;
      }
      final path = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (_) => CameraCaptureScreen(camera: cameras.first),
        ),
      );
      if (path != null) setState(() => _photoPath = path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Camera error: $e')));
      }
    }
  }

  Future<void> _save() async {
    if (_position == null || _photoPath == null || _readingCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Complete location, photo, and level.')));
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/readings.txt');
    final line =
        '${DateTime.now().toIso8601String()},${_position!.latitude},${_position!.longitude},${_readingCtrl.text.trim()},$_photoPath\n';
    await file.writeAsString(line, mode: FileMode.append);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Saved locally')));
    _readingCtrl.clear();
    setState(() => _photoPath = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                    onPressed: _getLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Get location')),
                FilledButton.icon(
                    onPressed: _openCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Open camera')),
                FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR (later)')),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _readingCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Manual water level (m)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_photoPath != null)
              SizedBox(
                height: 180,
                child: kIsWeb
                    ? Image.network(_photoPath!, fit: BoxFit.cover)
                    : Image.file(File(_photoPath!), fit: BoxFit.cover),
              ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.blueGrey.shade50),
                    const Center(
                        child: Text('Map preview (geofence coming next)')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save')),
            const SizedBox(height: 8),
            Text(
              _position == null
                  ? 'Location: —'
                  : 'Location: ${_position!.latitude.toStringAsFixed(6)}, '
                      '${_position!.longitude.toStringAsFixed(6)}',
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------- HISTORY --------------------
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<String> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

 Future<void> _load() async {
  final dir = await getApplicationDocumentsDirectory();
  final f = File('${dir.path}/readings.txt');
  if (await f.exists()) {
    final lines = await f.readAsLines();   // await first
    if (!mounted) return;                  // safety
    setState(() {                          // then setState
      _entries = lines;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: _entries.isEmpty
          ? const Center(child: Text('No entries yet'))
          : ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (_, i) {
                final p = _entries[i].split(',');
                final dt = DateFormat('yyyy-MM-dd HH:mm:ss')
                    .format(DateTime.parse(p[0]));
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading:
                        const Icon(Icons.water_drop, color: Colors.blue),
                    title: Text('Reading: ${p[3]} m'),
                    subtitle:
                        Text('Time: $dt\nLat: ${p[1]}, Lng: ${p[2]}'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
    );
  }
}

// -------------------- PROFILE --------------------
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
              leading: Icon(Icons.account_circle),
              title: Text('Role: Field Personnel')),
          ListTile(
              leading: Icon(Icons.badge),
              title: Text('Employee ID: (demo)')),
          ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout (to be implemented)')),
        ],
      ),
    );
  }
}

// -------------------- CAMERA CAPTURE --------------------
class CameraCaptureScreen extends StatefulWidget {
  final CameraDescription camera;
  const CameraCaptureScreen({super.key, required this.camera});
  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  late CameraController _controller;
  late Future<void> _init;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.medium);
    _init = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capture Gauge Photo')),
      body: FutureBuilder<void>(
        future: _init,
        builder: (_, s) {
          if (s.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _init;
          final img = await _controller.takePicture();
          if (!mounted) return;
          Navigator.pop(context, img.path);
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}