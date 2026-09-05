import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../data/mock/mock_investigations.dart';
import '../../widgets/investigation_card.dart';

class InvestigationListScreen extends StatefulWidget {
  const InvestigationListScreen({super.key});

  @override
  State<InvestigationListScreen> createState() => _InvestigationListScreenState();
}

class _InvestigationListScreenState extends State<InvestigationListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedSort = 'Highest Risk';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    // Sort and filter investigations
    var investigations = List.of(MockInvestigations.all);
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      investigations = investigations.where((i) {
        return i.project.id.toLowerCase().contains(q) ||
               i.project.name.toLowerCase().contains(q) ||
               i.project.village.toLowerCase().contains(q);
      }).toList();
    }
    
    // Default sorting by risk descending
    investigations.sort((a, b) => b.riskScore.compareTo(a.riskScore));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.investigationCenter),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.horizontalPadding(context),
              vertical: 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: l10n.searchPlaceholder,
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.filter_list_rounded),
                    onPressed: () {
                      // Filter bottom sheet logic mock
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView.separated(
        padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
        itemCount: investigations.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          return InvestigationCard(
            investigation: investigations[index],
            onTap: () => context.push('/investigations/${investigations[index].id}'),
          );
        },
      ),
    );
  }
}
