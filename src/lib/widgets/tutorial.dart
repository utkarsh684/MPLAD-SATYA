import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';

/// One step of the guided tour.
///
/// [anchor] is the key of the real widget to spotlight. When it is null, or
/// the widget is not on screen, the step still shows as a centred card rather
/// than being skipped — an officer who was promised a tour should not silently
/// lose half of it because a tile scrolled out of view.
class TourStep {
  const TourStep({
    required this.title,
    required this.body,
    this.anchor,
    this.icon,
  });

  final String title;
  final String body;
  final GlobalKey? anchor;
  final IconData? icon;
}

/// Whether this device has already been offered the tour.
///
/// Stored per install, so it is offered once rather than on every sign-in.
class TourPreference {
  static const _key = 'tutorial_seen_v1';

  static Future<bool> hasSeen() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_key) ?? false;
    } catch (_) {
      // A device that cannot read preferences should not be blocked; treat it
      // as already seen rather than nagging on every launch.
      return true;
    }
  }

  static Future<void> markSeen() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, true);
    } catch (_) {
      // Nothing to do: worst case the offer reappears next launch.
    }
  }

  /// Lets Settings offer "replay the tour".
  static Future<void> reset() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {}
  }
}

/// The opening ask: take the tour now, or not.
///
/// Deliberately a choice rather than an auto-start. An officer opening the app
/// to check one work should not be trapped in a walkthrough.
Future<bool> askToStartTour(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.school_rounded,
          size: 36, color: AppColors.govBlue),
      title: const Text('First time here?'),
      content: Text(
        'A two-minute tour shows what each screen is for, how to read a risk '
        'score, and where the evidence behind it comes from.\n\n'
        'You can leave the tour at any point.',
        style: GoogleFonts.inter(fontSize: 13.5, height: 1.55),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Maybe later'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text('Take the tour'),
        ),
      ],
    ),
  );
  await TourPreference.markSeen();
  return accepted ?? false;
}

/// Runs the tour as a full-screen overlay above the live app.
///
/// The app underneath stays real — this dims and spotlights it rather than
/// replacing it with screenshots, so what the officer is shown is the data
/// they actually have.
Future<void> runTour(BuildContext context, List<TourStep> steps) async {
  if (steps.isEmpty) return;
  await Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      pageBuilder: (_, __, ___) => _TourOverlay(steps: steps),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _TourOverlay extends StatefulWidget {
  const _TourOverlay({required this.steps});
  final List<TourStep> steps;

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay> {
  int _index = 0;

  TourStep get _step => widget.steps[_index];
  bool get _isLast => _index == widget.steps.length - 1;

  /// Screen rectangle of the widget this step points at, if it is laid out.
  Rect? get _spotlight {
    final key = _step.anchor;
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      origin.dx, origin.dy, box.size.width, box.size.height,
    ).inflate(6);
  }

  void _next() {
    if (_isLast) {
      Navigator.of(context).pop();
    } else {
      setState(() => _index++);
    }
  }

  void _back() {
    if (_index > 0) setState(() => _index--);
  }

  @override
  Widget build(BuildContext context) {
    final hole = _spotlight;
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // The dimmed layer with a hole cut out of it. Tapping the dim area
          // advances, which is what people try first.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _next,
            child: CustomPaint(
              size: Size(media.size.width, media.size.height),
              painter: _SpotlightPainter(hole: hole),
            ),
          ),
          _buildCard(hole, media),
        ],
      ),
    );
  }

  Widget _buildCard(Rect? hole, MediaQueryData media) {
    // Put the card on whichever side of the spotlight has more room, so it
    // never covers the thing it is describing.
    final below = hole == null || hole.bottom < media.size.height * 0.55;
    return Positioned(
      left: 16,
      right: 16,
      top: below ? (hole == null ? null : hole.bottom + 16) : null,
      // No null check needed: `below` is a final local, so flow analysis
      // carries `below == false` back to `hole != null` from its definition.
      bottom: below ? null : media.size.height - (hole.top - 16),
      child: Align(
        alignment: hole == null ? Alignment.center : Alignment.topCenter,
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurface
              : AppColors.white,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_step.icon != null) ...[
                      Icon(_step.icon, size: 20, color: AppColors.govBlue),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        _step.title,
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${_index + 1}/${widget.steps.length}',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _step.body,
                  style: GoogleFonts.inter(fontSize: 13.5, height: 1.55),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    // Always available, on every step. A tour you cannot leave
                    // is a trap, not an onboarding.
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Skip tour'),
                    ),
                    const Spacer(),
                    if (_index > 0)
                      TextButton(onPressed: _back, child: const Text('Back')),
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed: _next,
                      child: Text(_isLast ? 'Done' : 'Next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dims everything except the spotlight rectangle.
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({this.hole});
  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    // Deep enough that the rest of the screen reads as inactive rather than
    // merely tinted - the step should leave no doubt about where to look.
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.78);
    final screen = Rect.fromLTWH(0, 0, size.width, size.height);

    // Bound to a local because Dart promotes local variables but not public
    // final fields, so the null check below would not narrow the field itself.
    final hole = this.hole;
    if (hole == null) {
      canvas.drawRect(screen, dim);
      return;
    }

    final rrect = RRect.fromRectAndRadius(hole, const Radius.circular(14));

    // Even-odd fill punches the rounded rect out of the full-screen rect in a
    // single layer, which keeps the dim uniform rather than double-painting
    // where the shapes would otherwise overlap.
    final path = Path()
      ..addRect(screen)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, dim);

    // The edge is lit, not outlined.
    //
    // A hard coloured rectangle around a control is the visual language of a
    // validation error, and an officer being shown their own dashboard for the
    // first time should not be looking at something that reads as a warning.
    // A soft falloff says "look here" without saying "this is wrong", and it
    // survives whatever colours the widget underneath happens to use.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = Colors.white.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.hole != hole;
}
