import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/risk_band.dart';
import '../../core/utils/responsive.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/work.dart';
import '../../data/repositories/works_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/async_view.dart';
import '../../widgets/profile_menu.dart';
import '../../widgets/work_card.dart';

/// Server-side search, server-side filtering, cursor pagination.
class WorkListScreen extends StatefulWidget {
  const WorkListScreen({super.key});

  @override
  State<WorkListScreen> createState() => _WorkListScreenState();
}

class _WorkListScreenState extends State<WorkListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  final List<WorkSummary> _works = [];
  String? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  String _query = '';
  String? _band;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  /// Typing fires one request when the officer stops, not one per keystroke.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (value == _query) return;
      _query = value;
      _reload();
    });
  }

  Future<void> _reload() async {
    setState(() {
      _works.clear();
      _cursor = null;
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final page = await context.read<WorksRepository>().list(
            q: _query.isEmpty ? null : _query,
            band: _band,
            cursor: _cursor,
            limit: 25,
          );
      if (!mounted) return;
      setState(() {
        _works.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore && page.nextCursor != null;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.projects),
        actions: [
          IconButton(
            tooltip: 'Map',
            icon: const Icon(Icons.map_rounded),
            onPressed: () => context.push('/map'),
          ),
          const ProfileMenuButton(),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Responsive.horizontalPadding(context),
              0,
              Responsive.horizontalPadding(context),
              8,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search by title or work code',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _query = '';
                              _reload();
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _BandChip(
                        label: 'All',
                        selected: _band == null,
                        color: AppColors.govBlue,
                        onTap: () => setState(() {
                          _band = null;
                          _reload();
                        }),
                      ),
                      for (final band in [
                        RiskBand.red,
                        RiskBand.yellow,
                        RiskBand.green
                      ])
                        _BandChip(
                          label: band.defaultLabel,
                          selected: _band == band.wire,
                          color: band.color,
                          onTap: () => setState(() {
                            _band = band.wire;
                            _reload();
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_works.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_works.isEmpty && _error != null) {
      return ErrorState(error: _error!, onRetry: _reload);
    }
    if (_works.isEmpty) {
      return EmptyState(
        title: _query.isEmpty ? 'No works in your scope' : 'No matches',
        message: _query.isEmpty
            ? 'Works assigned to your district will appear here.'
            : 'Nothing matched "$_query".',
        icon: Icons.search_off_rounded,
        onRetry: _reload,
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
        itemCount: _works.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= _works.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final work = _works[index];
          return WorkCard(
            work: work,
            onTap: () =>
                context.push(AppRouter.workDetailPath(work.workCode)),
          );
        },
      ),
    );
  }
}

class _BandChip extends StatelessWidget {
  const _BandChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : color,
            )),
        selected: selected,
        showCheckmark: false,
        selectedColor: color,
        backgroundColor: color.withValues(alpha: 0.08),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
