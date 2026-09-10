import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/json.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../widgets/async_view.dart';

/// The entire rulebook, straight from `GET /admin/rules`.
///
/// This replaces a chat screen that returned a hardcoded paragraph about a
/// project that did not exist. Radical transparency is the better answer to
/// "how does it decide?": every rule, its condition, its points, and the
/// SHA-256 of the exact rulebook the server is running.
class RulebookScreen extends StatefulWidget {
  const RulebookScreen({super.key});

  @override
  State<RulebookScreen> createState() => _RulebookScreenState();
}

class _RulebookScreenState extends State<RulebookScreen> {
  late Future<Map<String, dynamic>> _future;
  String _query = '';
  String? _category;

  @override
  void initState() {
    super.initState();
    _future = context.read<AnalyticsRepository>().rulebook();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rulebook')),
      body: AsyncView<Map<String, dynamic>>(
        future: _future,
        onRetry: () => setState(() =>
            _future = context.read<AnalyticsRepository>().rulebook()),
        builder: (context, data) {
          final rules = asMapList(data['rules']);
          final categories = {
            for (final r in rules) asString(r['category'])
          }.toList()
            ..sort();

          var visible = rules;
          if (_category != null) {
            visible = visible
                .where((r) => asString(r['category']) == _category)
                .toList();
          }
          if (_query.isNotEmpty) {
            final q = _query.toLowerCase();
            visible = visible.where((r) {
              return asString(r['code']).toLowerCase().contains(q) ||
                  asString(r['title']).toLowerCase().contains(q) ||
                  asString(r['when']).toLowerCase().contains(q);
            }).toList();
          }

          return ListView(
            padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
            children: [
              _DigestCard(
                ruleCount: asInt(data['rule_count'], rules.length),
                rulesSha: asString(data['engine_rules_sha256']),
                weightsSha: asString(data['weights_sha256']),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search rules',
                  prefixIcon: Icon(Icons.search_rounded),
                  filled: true,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: _category == null,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _category = null),
                      ),
                    ),
                    for (final c in categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c),
                          selected: _category == c,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (visible.isEmpty)
                const EmptyState(
                  title: 'No matching rules',
                  icon: Icons.search_off_rounded,
                )
              else
                for (final rule in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RuleCard(rule: rule),
                  ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _DigestCard extends StatelessWidget {
  const _DigestCard({
    required this.ruleCount,
    required this.rulesSha,
    required this.weightsSha,
  });

  final int ruleCount;
  final String rulesSha;
  final String weightsSha;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.govBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.govBlue.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fingerprint_rounded,
                  size: 20, color: AppColors.govBlue),
              const SizedBox(width: 10),
              Text('$ruleCount rules in force',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Any score this server produces can be reproduced from exactly '
            'these digests, even after the rules later change.',
            style: GoogleFonts.inter(fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 12),
          Text('rules', style: GoogleFonts.inter(fontSize: 10)),
          SelectableText(rulesSha,
              style: GoogleFonts.robotoMono(fontSize: 10)),
          const SizedBox(height: 6),
          Text('weights', style: GoogleFonts.inter(fontSize: 10)),
          SelectableText(weightsSha,
              style: GoogleFonts.robotoMono(fontSize: 10)),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule});
  final Map<String, dynamic> rule;

  Color get _severityColor => switch (asString(rule['severity']).toUpperCase()) {
        'CRITICAL' => AppColors.riskCritical,
        'HIGH' => AppColors.riskHigh,
        'MEDIUM' => AppColors.riskMedium,
        _ => AppColors.riskLow,
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(asString(rule['code']),
                    style: GoogleFonts.robotoMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.govBlue)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _severityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(asString(rule['severity']),
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _severityColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(asString(rule['title']),
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceVariant
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('fires when',
                    style: GoogleFonts.inter(
                        fontSize: 9, color: AppColors.textTertiary)),
                const SizedBox(height: 2),
                SelectableText(asString(rule['when']),
                    style: GoogleFonts.robotoMono(fontSize: 11, height: 1.4)),
                const SizedBox(height: 8),
                Text('points',
                    style: GoogleFonts.inter(
                        fontSize: 9, color: AppColors.textTertiary)),
                const SizedBox(height: 2),
                SelectableText(asString(rule['points']),
                    style: GoogleFonts.robotoMono(fontSize: 11)),
              ],
            ),
          ),
          if (asString(rule['provenance']).isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.source_rounded,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(asString(rule['provenance']),
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textTertiary)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
