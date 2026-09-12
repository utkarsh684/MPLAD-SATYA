import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';

class MeasurementArgs {
  const MeasurementArgs({
    required this.workCode,
    this.expectedValue,
    this.expectedUnit,
  });

  final String workCode;
  final double? expectedValue;
  final String? expectedUnit;
}

class MeasurementResult {
  const MeasurementResult({
    required this.value,
    required this.unit,
    required this.method,
    this.accuracyM,
  });

  final double value;
  final String unit;

  /// One of the server's `MEASURE_METHODS`.
  final String method;
  final double? accuracyM;

  String get methodLabel => switch (method) {
        'gps_walk' => 'GPS walk',
        'tape' => 'Tape measure',
        'odometer' => 'Odometer',
        'ar_arcore' => 'AR (ARCore)',
        'ar_arkit' => 'AR (ARKit)',
        _ => method,
      };
}

/// Records a real measurement.
///
/// This replaces a mocked "AR" screen that displayed fixed numbers over a grey
/// rectangle. There is no AR plugin in this build, so rather than fake one, the
/// screen offers the two methods that genuinely work on any handset: walking
/// the length with GPS, and entering a tape or odometer reading. Both map onto
/// `measure_method` values the backend already accepts, and the accuracy of a
/// GPS walk is reported honestly rather than hidden.
class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({super.key, this.args});
  final MeasurementArgs? args;

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  final _manualValue = TextEditingController();
  String _manualMethod = 'tape';
  String _unit = 'm';

  StreamSubscription<Position>? _sub;
  final List<Position> _track = [];
  double _walked = 0;
  bool _walking = false;
  double? _worstAccuracy;

  static const _units = ['m', 'm²', 'km', 'nos'];

  @override
  void dispose() {
    _sub?.cancel();
    _manualValue.dispose();
    super.dispose();
  }

  Future<void> _startWalk() async {
    final start = await LocationService.instance.current();
    if (start == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Location unavailable — grant GPS permission.')),
      );
      return;
    }

    setState(() {
      _track
        ..clear()
        ..add(start);
      _walked = 0;
      _worstAccuracy = start.accuracy;
      _walking = true;
    });

    _sub = LocationService.instance.track().listen((position) {
      if (!mounted) return;
      final previous = _track.last;
      final step = LocationService.instance.distanceBetween(
        previous.latitude,
        previous.longitude,
        position.latitude,
        position.longitude,
      );
      // Ignore jitter below the fix accuracy: standing still must not
      // accumulate phantom metres.
      if (step < position.accuracy.clamp(3, 15)) return;
      setState(() {
        _track.add(position);
        _walked += step;
        if (position.accuracy > (_worstAccuracy ?? 0)) {
          _worstAccuracy = position.accuracy;
        }
      });
    });
  }

  void _stopWalk() {
    _sub?.cancel();
    _sub = null;
    setState(() => _walking = false);
  }

  void _submitWalk() {
    _stopWalk();
    Navigator.pop(
      context,
      MeasurementResult(
        value: double.parse(_walked.toStringAsFixed(1)),
        unit: 'm',
        method: 'gps_walk',
        accuracyM: _worstAccuracy,
      ),
    );
  }

  void _submitManual() {
    final value = double.tryParse(_manualValue.text.trim());
    if (value == null || value <= 0) return;
    Navigator.pop(
      context,
      MeasurementResult(
        value: value,
        unit: _unit,
        method: _manualMethod,
        // A tape reading has no GPS error term; the server treats null as
        // "not applicable" rather than "perfectly accurate".
        accuracyM: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Record measurement'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.directions_walk_rounded), text: 'GPS walk'),
              Tab(icon: Icon(Icons.straighten_rounded), text: 'Manual entry'),
            ],
          ),
        ),
        body: TabBarView(
          physics: _walking
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          children: [_buildWalkTab(), _buildManualTab()],
        ),
      ),
    );
  }

  Widget _buildWalkTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Walk from one end of the work to the other holding the phone. '
          'Distance is accumulated from the GPS track.',
          style: GoogleFonts.inter(fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 28),
        Center(
          child: Column(
            children: [
              Text(
                _walked.toStringAsFixed(1),
                style: GoogleFonts.inter(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: AppColors.govBlue,
                  height: 1,
                ),
              ),
              Text('metres',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.textTertiary)),
              const SizedBox(height: 12),
              if (_worstAccuracy != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.saffron.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Worst fix accuracy ±${_worstAccuracy!.round()} m · '
                    '${_track.length} points',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.saffronDark),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        if (!_walking)
          FilledButton.icon(
            onPressed: _startWalk,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(_track.isEmpty ? 'Start walking' : 'Restart'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.indiaGreen,
              minimumSize: const Size.fromHeight(50),
            ),
          )
        else
          FilledButton.icon(
            onPressed: _stopWalk,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Stop'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _walked > 0 && !_walking ? _submitWalk : null,
          style:
              OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: const Text('Use this measurement'),
        ),
        const SizedBox(height: 20),
        Text(
          'GPS walk is accurate to roughly the fix accuracy shown above. For '
          'short lengths a tape measure is more reliable — use the other tab.',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: AppColors.textTertiary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildManualTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Enter what you measured on site.',
            style: GoogleFonts.inter(fontSize: 13, height: 1.5)),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _manualValue,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                style: GoogleFonts.inter(
                    fontSize: 24, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  labelText: 'Measured value',
                  hintText: '0.0',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _unit,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: [
                  for (final u in _units)
                    DropdownMenuItem(value: u, child: Text(u)),
                ],
                onChanged: (v) => setState(() => _unit = v ?? 'm'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Method',
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        // Flutter 3.32 moved selection state onto a RadioGroup ancestor; the
        // per-tile groupValue/onChanged pair is deprecated and will be removed.
        RadioGroup<String>(
          groupValue: _manualMethod,
          onChanged: (v) => setState(() => _manualMethod = v ?? _manualMethod),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (value, label, icon) in const [
                ('tape', 'Tape measure', Icons.straighten_rounded),
                ('odometer', 'Vehicle odometer', Icons.speed_rounded),
              ])
                RadioListTile<String>(
                  value: value,
                  title: Row(
                    children: [
                      Icon(icon, size: 18),
                      const SizedBox(width: 10),
                      Text(label, style: GoogleFonts.inter(fontSize: 14)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: (double.tryParse(_manualValue.text.trim()) ?? 0) > 0
              ? _submitManual
              : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
          child: const Text('Use this measurement'),
        ),
      ],
    );
  }
}
