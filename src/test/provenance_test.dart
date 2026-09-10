import 'package:flutter_test/flutter_test.dart';
import 'package:mplad_satya/data/models/risk.dart';
import 'package:mplad_satya/data/models/satellite.dart';
import 'package:mplad_satya/widgets/provenance.dart';

/// These guard the claims the UI makes about where a number came from.
/// If one fails, the app is asserting something the data does not support.
void main() {
  group('SourceState', () {
    test('only genuinely evidential states may support a conclusion', () {
      expect(SourceState.live.isEvidential, isTrue);
      expect(SourceState.local.isEvidential, isTrue);
      expect(SourceState.official.isEvidential, isTrue);

      // A fixture is a stand-in, and a demo adapter is not independent of us.
      expect(SourceState.fixture.isEvidential, isFalse);
      expect(SourceState.demoAdapter.isEvidential, isFalse);
      expect(SourceState.inconclusive.isEvidential, isFalse);
      expect(SourceState.unavailable.isEvidential, isFalse);
      expect(SourceState.failed.isEvidential, isFalse);
      expect(SourceState.unknown.isEvidential, isFalse);
    });

    test('no state is labelled in a way that implies corroboration', () {
      // "Verified" would be the dangerous label: it reads as independent
      // confirmation regardless of what actually produced the value.
      for (final s in SourceState.values) {
        expect(s.label.toUpperCase(), isNot(contains('VERIFIED')));
      }
    });
  });

  group('SatelliteResult provenance', () {
    SatelliteResult build(Map<String, dynamic> extra) =>
        SatelliteResult.fromJson({
          'status': 'inconclusive',
          'confidence': 0.4,
          'method': 'visual_brightness_single_pass',
          'resolution_m': 2.5,
          'reason': 'r',
          ...extra,
        });

    test('a single-pass observation says it cannot confirm', () {
      final r = build({'adapter': 'bhuvan', 'is_temporal_comparison': false});
      expect(r.isLive, isTrue);
      expect(r.isTemporalComparison, isFalse);
      expect(r.plainVerdict, 'Cannot confirm from a single image');
      expect(r.limitation, contains('single-date'));
    });

    test('an outage is stated as an outage, not as a finding', () {
      final r = build({
        'status': 'unavailable',
        'adapter': 'bhuvan',
        'confidence': 0.0,
      });
      expect(r.plainVerdict, 'No imagery available');
      expect(r.limitation, contains('not a finding'));
    });

    test('fixture output is never reported as live', () {
      final r = build({'adapter': 'fixture'});
      expect(r.isLive, isFalse);
      expect(r.sourceLabel, contains('fixture'));
    });

    test('detectability below the sensor limit is labelled as such', () {
      final r = build({
        'target_dimension_m': 3.0,
        'min_detectable_m': 7.5,
        'detectability_ratio': 0.4,
      });
      expect(r.detectabilityLabel, 'BELOW SENSOR LIMIT');
      expect(r.hasDetectability, isTrue);
    });

    test('absent detectability yields no label rather than a fake one', () {
      final r = build({});
      expect(r.detectabilityRatio, isNull);
      expect(r.detectabilityLabel, isNull);
      expect(r.hasDetectability, isFalse);
    });

    test('brightness index is never surfaced under the NDBI name', () {
      // The server stopped sending ndbi_delta; if it ever reappears we must
      // not silently start rendering it as a built-up index again.
      final r = build({'brightness_index': 0.21});
      expect(r.brightnessIndex, closeTo(0.21, 1e-9));
    });
  });

  group('Evidence consistency', () {
    RiskAssessment build(dynamic consistency) => RiskAssessment.fromJson({
          'id': 'a',
          'work_id': 'w',
          'work_code': 'MP/2026/1',
          'score': 40,
          'band': 'yellow',
          'band_label': 'REVIEW REQUIRED',
          'recommended_action': 'manual_review',
          'action_label': 'SEND FOR REVIEW',
          'disclaimer': 'd',
          'consistency_pct': consistency,
          'subscores': <String, dynamic>{},
          'reasons': <dynamic>[],
          'engine_version': '1',
          'rules_sha256': 'x',
        });

    test('null stays null and is never coerced to zero', () {
      // 0 % means every source contradicted the record; null means nothing
      // could be checked. Collapsing them invents disagreement.
      expect(build(null).consistencyPct, isNull);
    });

    test('a genuine zero survives as zero', () {
      expect(build(0).consistencyPct, 0);
    });
  });
}
