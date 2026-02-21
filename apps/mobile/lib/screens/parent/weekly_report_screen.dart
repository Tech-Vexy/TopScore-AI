import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/report_service.dart';

class WeeklyReportScreen extends StatelessWidget {
  final String childUid;
  final String childName;

  const WeeklyReportScreen({
    super.key,
    required this.childUid,
    required this.childName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "$childName's Weekly Report",
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: FutureBuilder<WeeklyReport>(
        future: ReportService().generateWeeklyReport(childUid, childName),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData) {
            return const Center(child: Text('No data available yet.'));
          }
          final report = snap.data!;
          return _ReportBody(report: report, theme: theme);
        },
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final WeeklyReport report;
  final ThemeData theme;

  const _ReportBody({required this.report, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards row
          Row(
            children: [
              _buildStatCard(
                  '📅', '${report.daysActive}', 'Days Active', Colors.blue),
              const SizedBox(width: 12),
              _buildStatCard('🤖', '${report.aiSessionCount}', 'AI Sessions',
                  Colors.purple),
              const SizedBox(width: 12),
              _buildStatCard(
                  '📖', '${report.resourcesOpened}', 'Resources', Colors.green),
            ],
          ),

          const SizedBox(height: 28),

          // Activity chart
          Text(
            'Activity This Week',
            style:
                GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
              height: 180,
              child: _ActivityBarChart(activityByDay: report.activityByDay)),

          const SizedBox(height: 28),

          // Top topics
          if (report.topTopics.isNotEmpty) ...[
            Text(
              'Most Studied Topics',
              style:
                  GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...report.topTopics.asMap().entries.map((e) {
              final medals = ['🥇', '🥈', '🥉'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(medals[e.key], style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Text(
                      e.value,
                      style: GoogleFonts.nunito(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 16),
          Center(
            child: Text(
              'Generated ${_formatDate(report.generatedAt)}',
              style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String emoji, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(label,
                style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year} at ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _ActivityBarChart extends StatelessWidget {
  final Map<String, int> activityByDay;
  const _ActivityBarChart({required this.activityByDay});

  @override
  Widget build(BuildContext context) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxY = activityByDay.values.isEmpty
        ? 5.0
        : activityByDay.values.reduce((a, b) => a > b ? a : b).toDouble() + 2;

    return BarChart(
      BarChartData(
        maxY: maxY,
        barGroups: List.generate(days.length, (i) {
          final count = (activityByDay[days[i]] ?? 0).toDouble();
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: count,
                color: const Color(0xFF667EEA),
                width: 20,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) => Text(
                days[value.toInt()],
                style: GoogleFonts.nunito(fontSize: 12),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
    );
  }
}
