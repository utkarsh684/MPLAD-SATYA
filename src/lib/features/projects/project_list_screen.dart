import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../data/mock/mock_projects.dart';
import '../../widgets/project_card.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    var projects = List.of(MockProjects.all);
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      projects = projects.where((p) {
        return p.id.toLowerCase().contains(q) ||
               p.name.toLowerCase().contains(q) ||
               p.village.toLowerCase().contains(q);
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.projects),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_rounded),
            onPressed: () => context.push('/map'),
          ),
        ],
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
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView.separated(
        padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
        itemCount: projects.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          return ProjectCard(
            project: projects[index],
            onTap: () {
              // Usually goes to project detail, but in this prototype
              // we focus on investigations.
            },
          );
        },
      ),
    );
  }
}
