import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person, size: 32, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Your Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton(
              onPressed: () {},
              child: const Text('Edit'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Card(
          child: ListTile(
            leading: Icon(Icons.badge),
            title: Text('Name'),
            subtitle: Text('Hydro User'),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.email_outlined),
            title: Text('Email'),
            subtitle: Text('user@example.com'),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Preferences', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SwitchListTile(
          value: true,
          onChanged: (_) {},
          title: const Text('Live location updates'),
          subtitle: const Text('Auto-refresh location while app is open'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.color_lens_outlined),
          title: const Text('Theme'),
          subtitle: const Text('Brand colors & typography applied'),
          onTap: () {},
        ),
        const SizedBox(height: 40),
        Center(
          child: Text(
            'HydroGauge v1.0.0',
            style: TextStyle(color: Colors.black.withOpacity(0.5)),
          ),
        )
      ],
    );
  }
}


