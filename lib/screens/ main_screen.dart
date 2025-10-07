import 'package:flutter/material.dart';

// add these imports for your screens
import 'capture_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  String? _addressTitle; // updated by CaptureScreen

  late final List<Widget> _pages = [
    CaptureScreen(
      onAddressChange: (addr) {
        if (!mounted) return;
        setState(() => _addressTitle = addr);
      },
    ),
    const HistoryScreen(),
    const ProfileScreen(),
  ];

  String _titleFor(int i) {
    if (i == 0) {
      return (_addressTitle != null && _addressTitle!.trim().isNotEmpty)
          ? _addressTitle!
          : 'Field – Capture';
    }
    return i == 1 ? 'History' : 'Profile';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleFor(_currentIndex), overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.blueAccent,
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Capture',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}