import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../data/mock/mock_projects.dart';
import '../../widgets/project_card.dart';

class ProjectMapScreen extends StatelessWidget {
  const ProjectMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final projects = MockProjects.all;

    // Centered roughly on India
    final initialCenter = const LatLng(22.0, 79.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.projectMap),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: initialCenter,
          initialZoom: 5.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.mpladsatya.app',
          ),
          MarkerLayer(
            markers: projects.map((p) {
              final color = AppColors.riskColor(p.riskScore);
              return Marker(
                point: LatLng(p.latitude, p.longitude),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ProjectCard(project: p),
                      ),
                    );
                  },
                  child: Icon(
                    Icons.location_on,
                    size: 40,
                    color: color,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
