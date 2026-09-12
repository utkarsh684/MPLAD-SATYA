import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/services/geocoding_service.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/risk_band.dart';
import '../../data/models/work.dart';
import '../../data/repositories/works_repository.dart';
import '../../widgets/async_view.dart';
import '../../widgets/work_card.dart';

/// Real marker feed from `/map/works`, centred on the data rather than on a
/// hardcoded point.
class WorkMapScreen extends StatefulWidget {
  const WorkMapScreen({super.key});

  @override
  State<WorkMapScreen> createState() => _WorkMapScreenState();
}

class _WorkMapScreenState extends State<WorkMapScreen> {
  /// Markers rendered at once.
  ///
  /// Each marker is a decorated container, so a few thousand of them stutter
  /// badly on a mid-range phone. The cap is also a truthfulness problem, not
  /// only a performance one: the screen previously drew the first 500 of 2000
  /// works with nothing to say so, and an officer would reasonably read an
  /// empty area as "no works here" rather than "not loaded".
  static const int _markerLimit = 300;

  final _mapController = MapController();
  final _searchController = TextEditingController();
  late Future<List<WorkSummary>> _future;
  LatLng? _myLocation;

  List<GeoPlace> _places = const [];
  bool _searching = false;
  bool _searchOpen = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _future = context.read<WorksRepository>().mapWorks(limit: _markerLimit);
    _locate();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    final position = await LocationService.instance.current();
    if (position != null && mounted) {
      setState(() =>
          _myLocation = LatLng(position.latitude, position.longitude));
    }
  }

  /// Nominatim asks for at most one request per second, so the query only
  /// fires once the officer stops typing.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _places = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      setState(() => _searching = true);
      final results = await GeocodingService.instance.search(value);
      if (!mounted) return;
      setState(() {
        _places = results;
        _searching = false;
      });
    });
  }

  void _goTo(GeoPlace place) {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchOpen = false;
      _places = const [];
      _searchController.clear();
    });
    final bbox = place.boundingBox;
    if (bbox != null) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(LatLng(bbox[0], bbox[2]), LatLng(bbox[1], bbox[3])),
          padding: const EdgeInsets.all(48),
        ),
      );
    } else {
      _mapController.move(LatLng(place.lat, place.lon), 14);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Works map'),
        actions: [
          IconButton(
            tooltip: 'Search a place',
            icon: Icon(_searchOpen ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () => setState(() {
              _searchOpen = !_searchOpen;
              if (!_searchOpen) {
                _places = const [];
                _searchController.clear();
              }
            }),
          ),
          IconButton(
            tooltip: 'Centre on me',
            icon: const Icon(Icons.my_location_rounded),
            onPressed: _myLocation == null
                ? null
                : () => _mapController.move(_myLocation!, 14),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildMap(),
          if (_searchOpen) _buildSearchOverlay(),
        ],
      ),
    );
  }

  Widget _buildSearchOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: 8,
      left: 12,
      right: 12,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        color: isDark ? AppColors.darkSurface : AppColors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search a village, ward or district',
                prefixIcon: const Icon(Icons.place_rounded),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            if (_places.isNotEmpty) const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _places.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final place = _places[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on_rounded, size: 20),
                    title: Text(place.shortName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: place.context.isEmpty
                        ? null
                        : Text(place.context,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 11)),
                    onTap: () => _goTo(place),
                  );
                },
              ),
            ),
            if (_places.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Row(
                  children: [
                    Text('Geocoding by OpenStreetMap Nominatim',
                        style: GoogleFonts.inter(
                            fontSize: 9, color: AppColors.textTertiary)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return AsyncView<List<WorkSummary>>(
        future: _future,
        onRetry: () => setState(() => _future =
            context.read<WorksRepository>().mapWorks(limit: _markerLimit)),
        isEmpty: (works) => works.where((w) => w.hasLocation).isEmpty,
        emptyTitle: 'No mapped works',
        emptyMessage: 'Works in your scope have no location recorded.',
        emptyIcon: Icons.map_rounded,
        builder: (context, works) {
          final located = works.where((w) => w.hasLocation).toList();
          final truncated = works.length >= _markerLimit;
          return Stack(children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centroid(located),
              initialZoom: 10,
              // Frame whatever was actually returned rather than assuming a
              // district-sized view. Works span the country, and a fixed zoom
              // of 10 opens about 50 km across - an officer would see an empty
              // map and reasonably conclude there were no works.
              initialCameraFit: located.length > 1
                  ? CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints([
                        for (final w in located) LatLng(w.lat!, w.lon!),
                      ]),
                      padding: const EdgeInsets.all(40),
                    )
                  : null,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mpladsatya.mplad_satya',
              ),
              MarkerLayer(
                markers: [
                  for (final work in located)
                    Marker(
                      point: LatLng(work.lat!, work.lon!),
                      width: 36,
                      height: 36,
                      child: _WorkMarker(work: work),
                    ),
                  if (_myLocation != null)
                    Marker(
                      point: _myLocation!,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.govBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              // OSM's licence requires visible attribution.
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          if (truncated)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(10),
                color: AppColors.saffron.withValues(alpha: 0.95),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(
                    children: [
                      const Icon(Icons.layers_rounded,
                          size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Showing the first ${located.length} works. Search a '
                          'place or use the works list to find a specific one.',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]);
        },
    );
  }

  LatLng _centroid(List<WorkSummary> works) {
    if (works.isEmpty) return const LatLng(23.2599, 77.4126); // Bhopal
    final lat =
        works.map((w) => w.lat!).reduce((a, b) => a + b) / works.length;
    final lon =
        works.map((w) => w.lon!).reduce((a, b) => a + b) / works.length;
    return LatLng(lat, lon);
  }
}

class _WorkMarker extends StatelessWidget {
  const _WorkMarker({required this.work});
  final WorkSummary work;

  @override
  Widget build(BuildContext context) {
    final band = RiskBand.fromWire(work.riskBand, score: work.riskScore);

    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WorkCard(
                work: work,
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRouter.workDetailPath(work.workCode));
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: band.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          work.isScored ? '${work.riskScore}' : '?',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
