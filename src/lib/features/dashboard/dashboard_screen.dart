import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/investigation_card.dart';
import '../../widgets/risk_score_indicator.dart';
import '../../data/mock/mock_investigations.dart';
import '../../data/mock/mock_projects.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDesktop = Responsive.isDesktop(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.districtOverview),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.goodMorning,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            
            // Stats Grid
            _buildStatsGrid(context),
            const SizedBox(height: 32),
            
            // Charts & Priority Queue
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _buildRiskDistributionCard(context),
                        const SizedBox(height: 24),
                        _buildRiskTrendCard(context),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: _buildPriorityInvestigations(context),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildRiskDistributionCard(context),
                  const SizedBox(height: 24),
                  _buildRiskTrendCard(context),
                  const SizedBox(height: 24),
                  _buildPriorityInvestigations(context),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cols = Responsive.gridColumns(context);
    
    // Mock counts based on overall data
    final total = MockProjects.all.length * 50; // just multiplying for display demo
    final highRisk = MockProjects.all.where((p) => p.riskScore >= 61).length * 20;
    final critical = MockProjects.all.where((p) => p.riskScore >= 81).length * 5;
    
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.5,
      children: [
        StatCard(
          title: l10n.totalProjects,
          value: total.toString(),
          icon: Icons.folder_open_rounded,
          color: AppColors.govBlue,
        ),
        StatCard(
          title: l10n.highRisk,
          value: highRisk.toString(),
          icon: Icons.warning_amber_rounded,
          color: AppColors.riskHigh,
        ),
        StatCard(
          title: l10n.critical,
          value: critical.toString(),
          icon: Icons.error_outline_rounded,
          color: AppColors.riskCritical,
        ),
        StatCard(
          title: l10n.pendingVerification,
          value: '143',
          icon: Icons.pending_actions_rounded,
          color: AppColors.saffronDark,
        ),
      ],
    );
  }

  Widget _buildRiskDistributionCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.riskDistribution,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 60,
                    startDegreeOffset: 270,
                    sections: [
                      PieChartSectionData(
                        value: 65,
                        color: AppColors.riskLow,
                        radius: 20,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 20,
                        color: AppColors.riskMedium,
                        radius: 25,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 10,
                        color: AppColors.riskHigh,
                        radius: 30,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 5,
                        color: AppColors.riskCritical,
                        radius: 35,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
                const RiskScoreIndicator(
                  score: 42,
                  size: 90,
                  label: 'AVG RISK',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildLegendRow(),
        ],
      ),
    );
  }

  Widget _buildLegendRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem('Low', AppColors.riskLow),
        _buildLegendItem('Medium', AppColors.riskMedium),
        _buildLegendItem('High', AppColors.riskHigh),
        _buildLegendItem('Critical', AppColors.riskCritical),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRiskTrendCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.riskTrend,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 15),
                      FlSpot(1, 18),
                      FlSpot(2, 12),
                      FlSpot(3, 25),
                      FlSpot(4, 20),
                      FlSpot(5, 32),
                    ],
                    isCurved: true,
                    color: AppColors.riskHigh,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.riskHigh.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityInvestigations(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final investigations = MockInvestigations.all.take(5).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.highPriorityInvestigations,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/investigations'),
              child: Text(l10n.viewAll),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: investigations.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return InvestigationCard(
              investigation: investigations[index],
              onTap: () => context.push('/investigations/${investigations[index].id}'),
            );
          },
        ),
      ],
    );
  }
}
