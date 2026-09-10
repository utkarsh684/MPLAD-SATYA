import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/services/device_id.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/dashboard.dart';
import '../../data/models/evidence.dart';
import '../../data/repositories/field_repository.dart';
import '../../providers/outbox_provider.dart';
import '../../widgets/async_view.dart';
import 'measurement_screen.dart';

/// The actual field capture flow: real camera, real GPS, real upload.
///
/// Everything the officer records here is an immutable fact keyed by a
/// client-generated uuid, so replaying it after an offline period can never
/// double-count.
class VerifyWorkScreen extends StatefulWidget {
  const VerifyWorkScreen({super.key, required this.assignment});
  final Assignment assignment;

  @override
  State<VerifyWorkScreen> createState() => _VerifyWorkScreenState();
}

class _VerifyWorkScreenState extends State<VerifyWorkScreen> {
  final _notes = TextEditingController();
  final _picker = ImagePicker();

  Position? _position;
  bool _locating = true;
  String? _observedStatus;
  MeasurementResult? _measurement;
  final List<Evidence> _uploaded = [];
  final List<String> _queued = [];
  bool _uploading = false;
  bool _submitting = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _locate();
    _markStarted();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _markStarted() async {
    try {
      await context.read<FieldRepository>().start(widget.assignment.id);
      if (mounted) setState(() => _started = true);
    } catch (_) {
      // Not fatal — the officer can still capture and submit.
    }
  }

  Future<void> _locate() async {
    final position = await LocationService.instance.current();
    if (!mounted) return;
    setState(() {
      _position = position;
      _locating = false;
    });
  }

  double? get _distanceToSite {
    final work = widget.assignment.work;
    final position = _position;
    if (position == null || !work.hasLocation) return null;
    return LocationService.instance.distanceBetween(
      position.latitude,
      position.longitude,
      work.lat!,
      work.lon!,
    );
  }

  bool get _isOnSite {
    final d = _distanceToSite;
    return d != null && d <= AppConfig.onSiteRadiusMetres;
  }

  Future<void> _capturePhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      // Keep the upload small enough for a rural link while leaving enough
      // detail for the server's pHash and face detection to work.
      maxWidth: 1600,
      imageQuality: 82,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final outbox = context.read<OutboxProvider>();
      if (!outbox.online) {
        await outbox.uploadEvidence(
          workCode: widget.assignment.work.workCode,
          filePath: file.path,
          isMockLocation: LocationService.instance.isMocked(_position),
          claimedAccuracyM: _position?.accuracy,
        );
        if (!mounted) return;
        setState(() => _queued.add(file.path));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Offline — photo queued and will upload on sync.')),
        );
        return;
      }

      final evidence = await context.read<FieldRepository>().uploadEvidence(
            workCode: widget.assignment.work.workCode,
            photo: File(file.path),
            // Idempotency key: a retry of this exact upload is deduplicated
            // server-side rather than creating a second evidence row.
            clientUuid: DeviceId.newUuid(),
            isMockLocation: LocationService.instance.isMocked(_position),
            claimedAccuracyM: _position?.accuracy,
          );
      if (!mounted) return;
      setState(() => _uploaded.add(evidence));
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openMeasurement() async {
    final work = widget.assignment.work;
    final result = await Navigator.of(context).push<MeasurementResult>(
      MaterialPageRoute(
        builder: (_) => MeasurementScreen(
          args: MeasurementArgs(
            workCode: work.workCode,
            expectedValue: null,
            expectedUnit: null,
          ),
        ),
      ),
    );
    if (result != null && mounted) setState(() => _measurement = result);
  }

  Future<void> _submit() async {
    final status = _observedStatus;
    if (status == null) return;

    setState(() => _submitting = true);
    try {
      final outbox = context.read<OutboxProvider>();
      final sent = await outbox.submitVerification(
        verificationId: widget.assignment.id,
        observedStatus: status,
        measuredValue: _measurement?.value,
        measuredUnit: _measurement?.unit,
        measureMethod: _measurement?.method,
        measureAccuracyM: _measurement?.accuracyM,
        lat: _position?.latitude,
        lon: _position?.longitude,
        notes: _notes.text,
        evidenceIds: _uploaded.map((e) => e.id).toList(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              sent ? AppColors.indiaGreen : AppColors.saffronDark,
          content: Text(sent
              ? 'Verification submitted.'
              : 'Offline — verification queued and will sync automatically.'),
        ),
      );
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final work = widget.assignment.work;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field verification'),
        actions: [
          IconButton(
            tooltip: 'Refresh location',
            icon: const Icon(Icons.my_location_rounded),
            onPressed: _locate,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(work.title,
                    style: GoogleFonts.inter(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(work.workCode,
                    style: GoogleFonts.robotoMono(fontSize: 11)),
                const SizedBox(height: 12),
                _LocationStatus(
                  locating: _locating,
                  position: _position,
                  distance: _distanceToSite,
                  onSite: _isOnSite,
                  hasSiteLocation: work.hasLocation,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle('1 · What did you find on site?'),
          const SizedBox(height: 10),
          _StatusChoices(
            selected: _observedStatus,
            onSelect: (v) => setState(() => _observedStatus = v),
          ),
          const SizedBox(height: 24),
          _SectionTitle('2 · Photograph the site'),
          const SizedBox(height: 6),
          Text(
            'Faces are automatically blurred by the server before the photo is '
            'stored or shown to anyone.',
            style: GoogleFonts.inter(
                fontSize: 11,
                color: theme.textTheme.bodySmall?.color,
                height: 1.4),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _capturePhoto,
            icon: _uploading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.camera_alt_rounded),
            label: Text(_uploading ? 'Uploading…' : 'Capture photo'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
          ),
          if (_uploaded.isNotEmpty || _queued.isNotEmpty) ...[
            const SizedBox(height: 12),
            _CapturedStrip(uploaded: _uploaded, queuedCount: _queued.length),
          ],
          const SizedBox(height: 24),
          _SectionTitle('3 · Measure (optional)'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openMeasurement,
            icon: const Icon(Icons.straighten_rounded),
            label: Text(_measurement == null
                ? 'Record a measurement'
                : '${_measurement!.value} ${_measurement!.unit} · ${_measurement!.methodLabel}'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 24),
          _SectionTitle('4 · Notes'),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Anything the photographs do not show',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed:
                _observedStatus == null || _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.indiaGreen,
              minimumSize: const Size.fromHeight(50),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Submit verification'),
          ),
          const SizedBox(height: 12),
          Text(
            _started
                ? 'This assignment is marked in progress.'
                : 'Working offline — status will sync later.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
      );
}

class _LocationStatus extends StatelessWidget {
  const _LocationStatus({
    required this.locating,
    required this.position,
    required this.distance,
    required this.onSite,
    required this.hasSiteLocation,
  });

  final bool locating;
  final Position? position;
  final double? distance;
  final bool onSite;
  final bool hasSiteLocation;

  @override
  Widget build(BuildContext context) {
    if (locating) {
      return Row(
        children: [
          const SizedBox(
              height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Text('Getting your location…',
              style: GoogleFonts.inter(fontSize: 13)),
        ],
      );
    }

    if (position == null) {
      return _line(Icons.location_off_outlined, AppColors.error,
          'Location unavailable — enable GPS to record an on-site check');
    }
    if (!hasSiteLocation) {
      return _line(Icons.help_outline, AppColors.textSecondary,
          'This work has no recorded location to compare against');
    }

    final metres = distance!;
    final text = metres < 1000
        ? '${metres.round()} m from the recorded site'
        : '${(metres / 1000).toStringAsFixed(1)} km from the recorded site';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(
          onSite ? Icons.gps_fixed : Icons.gps_not_fixed,
          onSite ? AppColors.indiaGreen : AppColors.saffronDark,
          text,
        ),
        const SizedBox(height: 4),
        Text(
          'Fix accurate to ±${position!.accuracy.round()} m'
          '${position!.isMocked ? ' · MOCK LOCATION DETECTED' : ''}',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: position!.isMocked
                ? AppColors.error
                : AppColors.textTertiary,
            fontWeight:
                position!.isMocked ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _line(IconData icon, Color color, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ),
        ],
      );
}

class _StatusChoices extends StatelessWidget {
  const _StatusChoices({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String> onSelect;

  // Exactly the server's `observed_status` literal set.
  static const _options = [
    ('not_started', 'Not started', Icons.block_outlined),
    ('partial', 'Partially complete', Icons.timelapse_outlined),
    ('complete', 'Complete', Icons.check_circle_outline),
    ('different_work', 'Different work here', Icons.swap_horiz_outlined),
    ('inaccessible', 'Could not access', Icons.do_not_disturb_on_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        for (final (value, label, icon) in _options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onSelect(value),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                decoration: BoxDecoration(
                  color: selected == value
                      ? AppColors.govBlue.withValues(alpha: 0.1)
                      : Colors.transparent,
                  border: Border.all(
                    color: selected == value
                        ? AppColors.govBlue
                        : (isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(icon,
                        size: 20,
                        color: selected == value
                            ? AppColors.govBlue
                            : AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(label,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: selected == value
                                  ? FontWeight.w700
                                  : FontWeight.w500)),
                    ),
                    if (selected == value)
                      const Icon(Icons.check,
                          size: 20, color: AppColors.govBlue),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CapturedStrip extends StatelessWidget {
  const _CapturedStrip({required this.uploaded, required this.queuedCount});

  final List<Evidence> uploaded;
  final int queuedCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${uploaded.length} uploaded'
          '${queuedCount > 0 ? ' · $queuedCount queued offline' : ''}',
          style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: uploaded.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final e = uploaded[i];
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      e.absoluteUrl,
                      height: 88,
                      width: 88,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 88,
                        width: 88,
                        color: AppColors.surfaceVariant,
                        child: const Icon(Icons.image_outlined),
                      ),
                    ),
                  ),
                  if (e.facesBlurred > 0)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${e.facesBlurred} blurred',
                            style: GoogleFonts.inter(
                                fontSize: 8, color: Colors.white)),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
