import 'dart:io';

import 'package:flutter/material.dart';

class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({super.key, required this.entry});

  final String entry; // raw csv line

  @override
  Widget build(BuildContext context) {
    final parts = entry.split(',');
    final time = parts.isNotEmpty ? parts[0] : '';
    final lat = parts.length > 1 ? parts[1] : '';
    final lng = parts.length > 2 ? parts[2] : '';
    final level = parts.length > 3 ? parts[3] : '';
    final photo = parts.length > 4 ? parts[4] : '';

    return Scaffold(
      appBar: AppBar(title: const Text('Reading Detail')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (photo.isNotEmpty && File(photo).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(photo), height: 220, fit: BoxFit.cover),
            ),
          const SizedBox(height: 16),
          _Row(label: 'Date & Time', value: time.replaceAll('T', ' ').substring(0, 19)),
          _Row(label: 'Latitude', value: lat),
          _Row(label: 'Longitude', value: lng),
          _Row(label: 'Water Level (m)', value: level),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}


