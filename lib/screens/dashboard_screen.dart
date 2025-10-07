import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hydrogauge/widgets/hover_bubble.dart';
import 'package:hydrogauge/screens/site_manager_screen.dart';
import 'package:hydrogauge/services/visits_store.dart';
import 'package:hydrogauge/screens/schedule_visit_screen.dart';
import 'package:hydrogauge/services/api_client.dart';
import 'package:hydrogauge/services/auth_store.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  final bool isSupervisor;
  
  const DashboardScreen({super.key, this.onNavigateToTab, this.isSupervisor = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  Map<String, dynamic> _stats = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<ScheduledVisit>> _scheduledVisits = {};
  final List<_TeamMember> _teamMembers = const [
    _TeamMember(name: 'A. Sharma', sitesCoveredToday: 12, lastActive: 'Just now', status: TeamStatus.active),
    _TeamMember(name: 'R. Gupta', sitesCoveredToday: 8, lastActive: '30m ago', status: TeamStatus.idle),
    _TeamMember(name: 'P. Verma', sitesCoveredToday: 5, lastActive: '2h ago', status: TeamStatus.offline),
    _TeamMember(name: 'N. Iyer', sitesCoveredToday: 10, lastActive: '10m ago', status: TeamStatus.active),
  ];
  final List<_AlertItem> _alerts = const [
    _AlertItem(title: 'Site 14 – Missing Reading', timeAgo: '2 hrs ago', severity: AlertSeverity.medium),
    _AlertItem(title: 'Site 5 – Abnormal Water Level', timeAgo: '10 mins ago', severity: AlertSeverity.high),
    _AlertItem(title: 'Site 2 – Unverified Reading', timeAgo: '1 hr ago', severity: AlertSeverity.low),
  ];

  @override
  void initState() {
    super.initState();
    _loadReadings();
    _loadScheduledVisits();
    VisitsStore.instance.load();
    VisitsStore.instance.visits.addListener(() {
      setState(() {
        _scheduledVisits = _groupVisits(VisitsStore.instance.visits.value);
      });
    });
  }

  Future<void> _loadReadings() async {
    try {
      final token = AuthStore.instance.token.value;
      if (token != null && token.isNotEmpty) {
        final resp = await ApiClient().listSubmissions(token: token, limit: 200);
        if (resp['ok'] == true && resp['submissions'] is List) {
          final arr = (resp['submissions'] as List).cast<dynamic>();
          final readings = arr.map((j) {
            final m = (j as Map).cast<String, dynamic>();
            final ts = (m['capturedAt'] ?? '').toString();
            final lat = (m['lat'] is num) ? (m['lat'] as num).toDouble() : double.tryParse('${m['lat']}') ?? 0.0;
            final lng = (m['lng'] is num) ? (m['lng'] as num).toDouble() : double.tryParse('${m['lng']}') ?? 0.0;
            final lvl = (m['waterLevelMeters'] is num) ? (m['waterLevelMeters'] as num).toDouble() : double.tryParse('${m['waterLevelMeters']}') ?? 0.0;
            final img = m['imageUrl']?.toString();
            return _ReadingEntry(ts, lat, lng, lvl, img);
          }).where((e) => e.timestamp.isNotEmpty).toList();
          if (mounted) {
            setState(() {
              _stats = _calculateStats(readings);
              _loading = false;
            });
          }
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _stats = _calculateStats([]);
        _loading = false;
      });
    }
  }

  void _loadScheduledVisits() {
    _scheduledVisits = _groupVisits(VisitsStore.instance.visits.value);
  }

  Map<DateTime, List<ScheduledVisit>> _groupVisits(List<Visit> list) {
    final Map<DateTime, List<ScheduledVisit>> grouped = {};
    for (final v in list) {
      final d = DateTime(v.date.year, v.date.month, v.date.day);
      final mapped = ScheduledVisit(
        id: v.id,
        siteName: v.siteName,
        siteId: v.siteId,
        time: v.time,
        type: v.type,
        priority: v.priority,
        description: v.notes ?? '',
        address: v.siteName,
        distanceFromOffice: '',
        estimatedDuration: '',
        contactPerson: '',
        contactNumber: '',
        specialInstructions: '',
      );
      grouped.putIfAbsent(d, () => []).add(mapped);
    }
    return grouped;
  }

  Map<String, dynamic> _calculateStats(List<_ReadingEntry> readings) {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekStart = today.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      final todayReadings = readings.where((r) {
        try {
          return DateTime.parse(r.timestamp).isAfter(today);
        } catch (e) {
          return false;
        }
      }).toList();
      
      final weekReadings = readings.where((r) {
        try {
          return DateTime.parse(r.timestamp).isAfter(weekStart);
        } catch (e) {
          return false;
        }
      }).toList();
      
      final monthReadings = readings.where((r) {
        try {
          return DateTime.parse(r.timestamp).isAfter(monthStart);
        } catch (e) {
          return false;
        }
      }).toList();

      // Calculate average reading
      double avgReading = 0;
      if (readings.isNotEmpty) {
        final total = readings.fold<double>(0, (sum, r) => sum + r.level);
        avgReading = total / readings.length;
      }

      // Get recent readings (last 5)
      final recentReadings = readings.take(5).toList();

      return {
        'total': readings.length,
        'today': todayReadings.length,
        'thisWeek': weekReadings.length,
        'thisMonth': monthReadings.length,
        'averageReading': avgReading,
        'recentReadings': recentReadings,
      };
    } catch (e) {
      // Return default stats if calculation fails
      return {
        'total': 0,
        'today': 0,
        'thisWeek': 0,
        'thisMonth': 0,
        'averageReading': 0.0,
        'recentReadings': <_ReadingEntry>[],
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadReadings,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            _buildWelcomeHeader(),
            const SizedBox(height: 24),

            // Metrics
            if (widget.isSupervisor) _buildSupervisorMetricsGrid() else _buildStatsGrid(),
            const SizedBox(height: 24),

            // Quick Actions
            if (widget.isSupervisor) _buildSupervisorQuickActions() else _buildQuickActions(),
            const SizedBox(height: 24),

            // Team Summary and Alerts for Supervisor; otherwise show recent readings
            if (widget.isSupervisor) ...[
              _buildTeamSummary(),
              const SizedBox(height: 24),
              _buildAlertsSection(),
              const SizedBox(height: 24),
            ] else ...[
              _buildRecentReadings(),
              const SizedBox(height: 24),
            ],

            // Performance Insights
            _buildPerformanceInsights(),
            const SizedBox(height: 24),

            if (!widget.isSupervisor) ...[
              // Calendar Section
              _buildCalendarSection(),
              const SizedBox(height: 24),
            ],

            // Additional Features
            _buildAdditionalFeatures(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isSupervisor ? 'Supervisor' : 'Field Personnel',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (!widget.isSupervisor)
            Text(
              'Ready to capture water level readings?',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            )
          else ...[
            Text(
              'Monitor team performance and alerts.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            _buildHeaderLiveMetrics(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderLiveMetrics() {
    final total = _teamMembers.length;
    final active = _teamMembers.where((m) => m.status == TeamStatus.active).length;
    final pending = _alerts.length;
    final lastSync = DateFormat('hh:mm a').format(DateTime.now());
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _headerMetricChip(Icons.people_alt, 'Team Active: $active/$total'),
        _headerMetricChip(Icons.warning_amber_rounded, 'Pending Alerts: $pending'),
        _headerMetricChip(Icons.sync, 'Last Sync: $lastSync'),
      ],
    );
  }

  Widget _headerMetricChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: constraints.maxWidth > 400 ? 1.8 : 1.6,
          children: [
            _buildStatCard(
              'Total Readings',
              (_stats['total'] as int? ?? 0).toString(),
              Icons.water_drop,
              Colors.blue,
            ),
            _buildStatCard(
              'Today',
              (_stats['today'] as int? ?? 0).toString(),
              Icons.today,
              Colors.green,
            ),
            _buildStatCard(
              'This Week',
              (_stats['thisWeek'] as int? ?? 0).toString(),
              Icons.date_range,
              Colors.orange,
            ),
            _buildStatCard(
              'This Month',
              (_stats['thisMonth'] as int? ?? 0).toString(),
              Icons.calendar_month,
              Colors.purple,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: HoverBubble(
        intensity: 0.9,
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildSupervisorMetricsGrid() {
    final totalTeamReadings = (_stats['total'] as int? ?? 0); // placeholder; replace with team aggregate when backend exists
    final activeStaffToday = _teamMembers.where((m) => m.status != TeamStatus.offline).length;
    final readingsThisWeek = (_stats['thisWeek'] as int? ?? 0);
    final fieldEfficiency = _calculateFieldEfficiency();
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: constraints.maxWidth > 400 ? 1.8 : 1.6,
          children: [
            _buildStatCard('Total Readings (Team)', totalTeamReadings.toString(), Icons.summarize, Colors.blue),
            _buildStatCard('Active Staff Today', activeStaffToday.toString(), Icons.badge, Colors.green),
            _buildStatCard('Readings This Week', readingsThisWeek.toString(), Icons.date_range, Colors.orange),
            _buildStatCard('Field Efficiency (%)', fieldEfficiency.toStringAsFixed(0), Icons.insights, Colors.purple),
          ],
        );
      },
    );
  }

  double _calculateFieldEfficiency() {
    // Simple heuristic: active/total * 100
    if (_teamMembers.isEmpty) return 0;
    return (_teamMembers.where((m) => m.status == TeamStatus.active).length / _teamMembers.length) * 100;
  }

  Widget _buildTeamSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Team Summary',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._teamMembers.map((m) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(m.name.substring(0, 1))),
                title: Text(m.name),
                subtitle: Text('${m.sitesCoveredToday} sites • Last seen ${m.lastActive}'),
                trailing: _statusChip(m.status),
              ),
            )),
      ],
    );
  }

  Widget _statusChip(TeamStatus status) {
    Color c;
    String label;
    switch (status) {
      case TeamStatus.active:
        c = Colors.green;
        label = 'Active';
        break;
      case TeamStatus.idle:
        c = Colors.orange;
        label = 'Idle';
        break;
      case TeamStatus.offline:
        c = Colors.grey;
        label = 'Offline';
        break;
    }
    return Chip(
      label: Text(label),
      backgroundColor: c.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: c, fontWeight: FontWeight.w700),
      side: BorderSide(color: c),
    );
  }

  Widget _buildAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alerts',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_alerts.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No alerts.'),
            ),
          )
        else
          ..._alerts.map((a) => Card(
                child: ListTile(
                  leading: Icon(Icons.warning_amber_rounded, color: _severityColor(a.severity)),
                  title: Text(a.title),
                  subtitle: Text(a.timeAgo),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              )),
      ],
    );
  }

  Color _severityColor(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.high:
        return Colors.red;
      case AlertSeverity.medium:
        return Colors.orange;
      case AlertSeverity.low:
        return Colors.amber;
    }
  }

  Widget _buildSupervisorQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Assign New Site',
                'Allocate work to staff',
                Icons.assignment_ind,
                Colors.indigo,
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SiteManagerScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Schedule Visit',
                'Plan field visits',
                Icons.event_available,
                Colors.teal,
                () async {
                  final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const ScheduleVisitScreen()),
                  );
                  if (created == true) {
                    setState(() {
                      _scheduledVisits = _groupVisits(VisitsStore.instance.visits.value);
                    });
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Resolve Alerts',
                'Review and close alerts',
                Icons.rule_folder,
                Colors.orange,
                () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Export PDF Summary',
                'Download overview',
                Icons.picture_as_pdf,
                Colors.purple,
                () => _exportData(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (!widget.isSupervisor) ...[
              Expanded(
                child: _buildActionCard(
                  'New Reading',
                  'Capture water level',
                  Icons.camera_alt,
                  Colors.blue,
                  () => _navigateToCapture(),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: _buildActionCard(
                widget.isSupervisor ? 'Agents' : 'View History',
                widget.isSupervisor ? 'Team overview' : 'See all readings',
                widget.isSupervisor ? Icons.group : Icons.history,
                widget.isSupervisor ? Colors.indigo : Colors.green,
                () => widget.isSupervisor ? _navigateToAgents() : _navigateToHistory(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: HoverBubble(
        child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildRecentReadings() {
    final recentReadings = _stats['recentReadings'] as List<_ReadingEntry>? ?? <_ReadingEntry>[];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Readings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (recentReadings.isNotEmpty)
              TextButton(
                onPressed: _navigateToHistory,
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (recentReadings.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No readings yet. Start by capturing your first reading!',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          )
        else
          ...recentReadings.map((reading) => _buildReadingCard(reading)),
      ],
    );
  }

  Widget _buildReadingCard(_ReadingEntry reading) {
    String formattedDate = 'Unknown date';
    try {
      final date = DateTime.parse(reading.timestamp);
      formattedDate = DateFormat('MMM dd, HH:mm').format(date);
    } catch (e) {
      formattedDate = 'Invalid date';
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(
            Icons.water_drop,
            color: Colors.blue.shade700,
          ),
        ),
        title: Text('${reading.level} m'),
        subtitle: Text(formattedDate),
        trailing: reading.photoPath != null
            ? const Icon(Icons.image, color: Colors.green)
            : const Icon(Icons.image_not_supported, color: Colors.grey),
      ),
    );
  }

  Widget _buildPerformanceInsights() {
    final avgReading = _stats['averageReading'] as double? ?? 0.0;
    final totalReadings = _stats['total'] as int? ?? 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Insights',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    const Text(
                      'Average Reading',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  totalReadings > 0 
                      ? '${avgReading.toStringAsFixed(2)} m'
                      : 'No readings yet',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                if (totalReadings > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Based on $totalReadings reading${totalReadings == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _navigateToCapture() {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(1); // For field role only
    }
  }

  void _navigateToHistory() {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(widget.isSupervisor ? 2 : 2); // For supervisor, history is index 2 after removing Capture
    }
  }

  void _navigateToAgents() {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(1); // Agents index for supervisor after removing Capture
    }
  }

  Widget _buildAdditionalFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Features',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                'Sync Data',
                'Upload readings to server',
                Icons.cloud_upload,
                Colors.blue,
                () => _syncData(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeatureCard(
                'Export Data',
                'Download readings',
                Icons.download,
                Colors.green,
                () => _exportData(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                'Settings',
                'App preferences',
                Icons.settings,
                Colors.orange,
                () => _navigateToSettings(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeatureCard(
                'Help & Support',
                'Get assistance',
                Icons.help,
                Colors.purple,
                () => _showHelp(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: HoverBubble(
        child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  void _syncData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sync feature coming soon!')),
    );
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon!')),
    );
  }

  void _navigateToSettings() {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(3); // Settings is index 3
    }
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text(
          'HydroGauge Dashboard Help:\n\n'
          '• Dashboard shows your reading statistics\n'
          '• Quick Actions help you navigate to main features\n'
          '• Recent Readings shows your latest captures\n'
          '• Performance Insights track your average readings\n\n'
          'For technical support, contact your supervisor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upcoming Visits',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TableCalendar<ScheduledVisit>(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    if (!isSameDay(_selectedDay, selectedDay)) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      
                      // Show visit details if there are visits on the selected day
                      final normalizedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
                      final visits = _scheduledVisits[normalizedDay] ?? [];
                      if (visits.isNotEmpty) {
                        _showDayVisitsDialog(selectedDay, visits);
                      }
                    }
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  eventLoader: (day) {
                    // Normalize the date to remove time component for proper matching
                    final normalizedDay = DateTime(day.year, day.month, day.day);
                    final visits = _scheduledVisits[normalizedDay] ?? [];
                    print('Event loader called for ${day.day}/${day.month}/${day.year}: ${visits.length} visits');
                    return visits;
                  },
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    markersMaxCount: 5,
                    markerMargin: const EdgeInsets.symmetric(horizontal: 1),
                    markerDecoration: BoxDecoration(
                      color: Colors.orange.shade600,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: Colors.blue.shade200,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedDay != null && _scheduledVisits[_selectedDay] != null)
                  _buildSelectedDayVisits(_scheduledVisits[_selectedDay]!),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDayVisits(List<ScheduledVisit> visits) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visits on ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        ...visits.map((visit) => _buildVisitCard(visit)),
      ],
    );
  }

  Widget _buildVisitCard(ScheduledVisit visit) {
    Color priorityColor = _getPriorityColor(visit.priority);
    IconData priorityIcon;
    
    switch (visit.priority) {
      case VisitPriority.high:
        priorityIcon = Icons.priority_high;
        break;
      case VisitPriority.medium:
        priorityIcon = Icons.remove;
        break;
      case VisitPriority.low:
        priorityIcon = Icons.keyboard_arrow_down;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showVisitDetails(visit),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: priorityColor.withValues(alpha: 0.1),
                    radius: 16,
                    child: Icon(priorityIcon, color: priorityColor, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visit.siteName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          visit.siteId,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      visit.priority.name.toUpperCase(),
                      style: TextStyle(
                        color: priorityColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    visit.time,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.timer, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    visit.estimatedDuration,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.directions_car, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    visit.distanceFromOffice,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(_getVisitTypeIcon(visit.type), size: 14, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    visit.type.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                visit.description,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getVisitTypeIcon(VisitType type) {
    switch (type) {
      case VisitType.routine:
        return Icons.schedule;
      case VisitType.inspection:
        return Icons.search;
    }
  }

  void _showVisitDetails(ScheduledVisit visit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getVisitTypeIcon(visit.type),
              color: _getPriorityColor(visit.priority),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                visit.siteName,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Priority and Type
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(visit.priority).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      visit.priority.name.toUpperCase(),
                      style: TextStyle(
                        color: _getPriorityColor(visit.priority),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      visit.type.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Time and Duration
              _buildDetailRow(Icons.access_time, 'Scheduled Time', visit.time),
              _buildDetailRow(Icons.timer, 'Estimated Duration', visit.estimatedDuration),
              const SizedBox(height: 12),
              
              // Location Information
              _buildAddressRow(visit.address),
              _buildDetailRow(Icons.directions_car, 'Distance from Office', visit.distanceFromOffice),
              const SizedBox(height: 12),
              
              // Contact Information
              _buildDetailRow(Icons.person, 'Contact Person', visit.contactPerson),
              _buildDetailRow(Icons.phone, 'Contact Number', visit.contactNumber),
              const SizedBox(height: 12),
              
              // Site Information
              _buildDetailRow(Icons.business, 'Site ID', visit.siteId),
              const SizedBox(height: 8),
              
              // Description
              const Text(
                'Description:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(visit.description),
              const SizedBox(height: 12),
              
              // Special Instructions
              if (visit.specialInstructions.isNotEmpty) ...[
                const Text(
                  'Special Instructions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    visit.specialInstructions,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to capture screen for this visit
              if (widget.onNavigateToTab != null) {
                widget.onNavigateToTab!(1);
              }
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Visit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(String address) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Address',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _openMaps(address),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.map,
                          size: 16,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to open in Maps',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMaps(String address) async {
    // Encode the address for URL
    final encodedAddress = Uri.encodeComponent(address);
    
    // Try to open in Google Maps first, then fallback to Apple Maps
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$encodedAddress';
    final appleMapsUrl = 'https://maps.apple.com/?q=$encodedAddress';
    
    try {
      // Try Google Maps first
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
        // Fallback to Apple Maps
        await launchUrl(Uri.parse(appleMapsUrl), mode: LaunchMode.externalApplication);
      } else {
        // Show error if no maps app is available
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No maps application found. Please install Google Maps or Apple Maps.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening maps: $e'),
          ),
        );
      }
    }
  }

  Color _getPriorityColor(VisitPriority priority) {
    switch (priority) {
      case VisitPriority.high:
        return Colors.red;
      case VisitPriority.medium:
        return Colors.orange;
      case VisitPriority.low:
        return Colors.green;
    }
  }

  void _showDayVisitsDialog(DateTime selectedDay, List<ScheduledVisit> visits) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Visits on ${DateFormat('MMM dd, yyyy').format(selectedDay)}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: visits.length,
            itemBuilder: (context, index) {
              final visit = visits[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getPriorityColor(visit.priority).withValues(alpha: 0.1),
                    child: Icon(
                      _getVisitTypeIcon(visit.type),
                      color: _getPriorityColor(visit.priority),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    visit.siteName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${visit.time} • ${visit.type.name.toUpperCase()}'),
                      Text('Distance: ${visit.distanceFromOffice}'),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(visit.priority).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      visit.priority.name.toUpperCase(),
                      style: TextStyle(
                        color: _getPriorityColor(visit.priority),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close the day dialog
                    _showVisitDetails(visit); // Show individual visit details
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ReadingEntry {
  final String timestamp;
  final double lat;
  final double lng;
  final double level;
  final String? photoPath;

  _ReadingEntry(this.timestamp, this.lat, this.lng, this.level, this.photoPath);
}

class ScheduledVisit {
  final String id;
  final String siteName;
  final String siteId;
  final String time;
  final VisitType type;
  final VisitPriority priority;
  final String description;
  final String address;
  final String distanceFromOffice;
  final String estimatedDuration;
  final String contactPerson;
  final String contactNumber;
  final String specialInstructions;

  ScheduledVisit({
    required this.id,
    required this.siteName,
    required this.siteId,
    required this.time,
    required this.type,
    required this.priority,
    required this.description,
    required this.address,
    required this.distanceFromOffice,
    required this.estimatedDuration,
    required this.contactPerson,
    required this.contactNumber,
    required this.specialInstructions,
  });
}

class _TeamMember {
  final String name;
  final int sitesCoveredToday;
  final String lastActive;
  final TeamStatus status;
  const _TeamMember({required this.name, required this.sitesCoveredToday, required this.lastActive, required this.status});
}

enum TeamStatus { active, idle, offline }

class _AlertItem {
  final String title;
  final String timeAgo;
  final AlertSeverity severity;
  const _AlertItem({required this.title, required this.timeAgo, required this.severity});
}

enum AlertSeverity { low, medium, high }
