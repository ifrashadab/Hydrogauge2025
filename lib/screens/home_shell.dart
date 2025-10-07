import 'package:flutter/material.dart';
import 'package:hydrogauge/screens/dashboard_screen.dart';
import 'package:hydrogauge/screens/capture_screen.dart';
import 'package:hydrogauge/screens/history_screen.dart';
import 'package:hydrogauge/screens/profile_screen.dart';
import 'package:hydrogauge/screens/supervisor_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  String _address = '';
  bool _didApplyInitialRouteIndex = false;
  String _role = 'field'; // 'field' | 'supervisor'

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didApplyInitialRouteIndex) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final role = args['role'];
        final idx = args['index'];
        if (role is String) _role = role;
        if (idx is int) _index = idx;
      } else if (args is int && args >= 0 && args <= 4) {
        // backward compatibility: only index provided
        _index = args;
      }
      _didApplyInitialRouteIndex = true;
    }
  }

  Widget _buildBody() {
    // Tab order differs by role
    final isSupervisor = _role == 'supervisor';
    if (_index == 0) {
      return DashboardScreen(
        onNavigateToTab: (tabIndex) => setState(() => _index = tabIndex),
        isSupervisor: _role == 'supervisor',
      );
    }
    if (isSupervisor) {
      if (_index == 1) return const SupervisorScreen();
      if (_index == 2) return const HistoryScreen();
      return const ProfileScreen();
    } else {
      if (_index == 1) {
        return CaptureScreen(
          onAddressChange: (addr) => setState(() => _address = addr),
        );
      }
      if (_index == 2) return const HistoryScreen();
      return const ProfileScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: _index == 0
            ? const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w800))
            : _index == 1
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('HydroGauge', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                        _address.isEmpty ? 'Location not set' : _address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  )
                : Builder(
                    builder: (_) {
                      final isSupervisor = _role == 'supervisor';
                      if (isSupervisor) {
                        // Supervisor has no Capture tab; index 1 => Agents
                        return Text(_index == 1 ? 'Agents' : _index == 2 ? 'History' : 'Profile');
                      } else {
                        return Text(_index == 2 ? 'History' : 'Profile');
                      }
                    },
                  ),
        centerTitle: false,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _buildBody(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _role == 'supervisor'
            ? const [
                NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
                NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'Agents'),
                NavigationDestination(icon: Icon(Icons.history), label: 'History'),
                NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
              ]
            : const [
                NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
                NavigationDestination(icon: Icon(Icons.camera_alt_outlined), selectedIcon: Icon(Icons.camera_alt), label: 'Capture'),
                NavigationDestination(icon: Icon(Icons.history), label: 'History'),
                NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
              ],
      ),
    );
  }
}


