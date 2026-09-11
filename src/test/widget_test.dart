import 'package:flutter_test/flutter_test.dart';
import 'package:mplad_satya/core/services/geocoding_service.dart';
import 'package:mplad_satya/core/theme/risk_band.dart';
import 'package:mplad_satya/data/api/api_exception.dart';
import 'package:mplad_satya/data/models/analytics.dart';
import 'package:mplad_satya/data/models/money.dart';
import 'package:mplad_satya/data/models/risk.dart';
import 'package:mplad_satya/data/models/satellite.dart';
import 'package:mplad_satya/data/models/work.dart';

void main() {
  group('RiskBand', () {
    test('maps the server bands, never inventing a fourth', () {
      expect(RiskBand.fromWire('green'), RiskBand.green);
      expect(RiskBand.fromWire('yellow'), RiskBand.yellow);
      expect(RiskBand.fromWire('red'), RiskBand.red);
    });

    test('the band string wins over the score', () {
      // A score of 75 with an explicit green band must render green: the
      // server is the authority, not a client-side threshold.
      expect(RiskBand.fromWire('green', score: 75), RiskBand.green);
    });

    test('score fallback uses weights.yaml thresholds (31 and 71)', () {
      expect(RiskBand.fromWire(null, score: 30), RiskBand.green);
      expect(RiskBand.fromWire(null, score: 31), RiskBand.yellow);
      expect(RiskBand.fromWire(null, score: 70), RiskBand.yellow);
      expect(RiskBand.fromWire(null, score: 71), RiskBand.red);
      // Regression guard: the old UI called 75 "High" and reserved a
      // "Critical" tier for 81+, disagreeing with the engine's own band.
      expect(RiskBand.fromWire(null, score: 75), RiskBand.red);
    });

    test('an unscored work is not a low-risk work', () {
      expect(RiskBand.fromWire(null), RiskBand.unscored);
      expect(RiskBand.fromWire(null).isScored, isFalse);
    });
  });

  group('Money', () {
    test('uses the server display string verbatim', () {
      final money = Money.fromJson({'paise': 156000000, 'display': '₹15.60 L'});
      expect(money.paise, 156000000);
      expect(money.display, '₹15.60 L');
    });

    test('formats locally only when given bare paise', () {
      // Some endpoints send integer paise rather than a Money object.
      expect(Money.fromJson(156000000).display, '₹15.60 L');
      expect(Money.fromJson(1500000000).display, '₹1.50 Cr');
    });

    test('never loses precision to floating point', () {
      expect(Money.fromJson(156000000).paise, 156000000);
    });
  });

  group('RiskAssessment', () {
    test('parses reasons and their points sum to the score', () {
      // Mirrors the apportionment contract: displayed points add up exactly.
      final assessment = RiskAssessment.fromJson({
        'id': 'a1',
        'work_id': 'w1',
        'work_code': 'MP/2026/1142',
        'score': 78,
        'band': 'red',
        'band_label': 'HIGH RISK',
        'recommended_action': 'hold_field_verify',
        'action_label': 'HOLD RELEASE FOR FIELD REVIEW',
        'disclaimer': 'AI recommendation - final decision by authorised officer.',
        'consistency_pct': 42,
        'subscores': {'rule': 24, 'anomaly': 18},
        'engine_version': '1.0.0',
        'rules_sha256': 'abc123',
        'reasons': [
          _reason('COST_ZSCORE_OUTLIER', 24),
          _reason('GEO_DUPLICATE', 18),
          _reason('SAME_PHOTO_CROSS_AGENCY', 16),
          _reason('MEASUREMENT_MISMATCH', 15),
          _reason('TIMELINE_SLIP', 5),
        ],
      });

      expect(assessment.score, 78);
      expect(assessment.reasons, hasLength(5));
      expect(assessment.reasonPointsTotal, 78);
      expect(assessment.disclaimer, isNotEmpty);
    });
  });

  group('SourceCard', () {
    test('only match and mismatch count as informative', () {
      expect(_source('match').isInformative, isTrue);
      expect(_source('mismatch').isInformative, isTrue);
      // An inconclusive satellite read is not evidence of wrongdoing.
      expect(_source('inconclusive').isInformative, isFalse);
      expect(_source('unavailable').isInformative, isFalse);
    });
  });

  group('WorkSummary', () {
    test('a missing risk score stays null rather than becoming zero', () {
      final work = WorkSummary.fromJson({
        'id': 'w1',
        'work_code': 'MP/2026/0001',
        'title': 'Ward road',
        'category': 'roads',
        'status': 'in_progress',
        'sanctioned_amount': {'paise': 100000, 'display': '₹1,000'},
        'risk_score': null,
        'risk_band': null,
      });
      expect(work.riskScore, isNull);
      expect(work.isScored, isFalse);
    });

    test('survives a field the server did not send', () {
      final work = WorkSummary.fromJson({
        'id': 'w1',
        'work_code': 'MP/2026/0002',
        'title': 'Drain',
        'category': 'drainage',
        'status': 'sanctioned',
        'sanctioned_amount': {'paise': 1, 'display': '₹0.01'},
      });
      expect(work.districtName, isNull);
      expect(work.hasLocation, isFalse);
    });
  });

  group('AnalyticsOverview', () {
    test('the pie is drawn over assessed works, not the total', () {
      final overview = AnalyticsOverview.fromJson({
        'total_works': 2000,
        'by_band': {'green': 100, 'yellow': 50, 'red': 25},
        'average_risk_score': 33.4,
        'total_sanctioned_paise': 271500000000,
        'pending_fund_releases': 12,
        'total_evidence_items': 300,
        'total_decisions': 40,
      });
      expect(overview.totalWorks, 2000);
      expect(overview.assessedWorks, 175);
      expect(overview.hasAssessments, isTrue);
    });
  });

  _satelliteAndEsakshiTests();

  group('ApiException', () {
    test('unwraps the server error envelope', () {
      final error = ApiException.fromResponse(404, {
        'error': {'code': 'WORK_NOT_FOUND', 'message': 'No work with that code.'}
      });
      expect(error.code, 'WORK_NOT_FOUND');
      expect(error.message, 'No work with that code.');
      expect(error.statusCode, 404);
    });

    test('distinguishes transport failure from server rejection', () {
      expect(ApiException.timeout().isNetwork, isTrue);
      expect(ApiException.fromResponse(403, null).isNetwork, isFalse);
    });

    test('a database outage is retryable, not a permanent rejection', () {
      // The server answers 503 DATABASE_UNAVAILABLE when it cannot reach
      // Postgres. The outbox discards anything permanent, so treating this as
      // one would throw away an officer's field verification during a
      // transient Neon blip.
      final outage = ApiException.fromResponse(503, {
        'error': {
          'code': 'DATABASE_UNAVAILABLE',
          'message': 'The service cannot reach its database right now.'
        }
      });
      expect(outage.isRetryable, isTrue);
      expect(outage.isDependencyOutage, isTrue);
      // ...but it is NOT a phone connectivity problem, and must not be shown
      // to the officer as one.
      expect(outage.isNetwork, isFalse);
    });

    test('gateway errors are retryable too', () {
      for (final status in [502, 503, 504]) {
        expect(ApiException.fromResponse(status, null).isRetryable, isTrue,
            reason: '$status should survive a retry');
      }
    });

    test('a real rejection is never retried', () {
      for (final status in [400, 401, 403, 404, 409, 413, 415, 422]) {
        expect(ApiException.fromResponse(status, null).isRetryable, isFalse,
            reason: '$status would retry forever');
      }
    });
  });
}

Map<String, dynamic> _reason(String code, int points) => {
      'rank': 1,
      'code': code,
      'category': 'rule',
      'severity': 'HIGH',
      'title': code,
      'points': points,
      'explanation': 'because',
      'provenance': 'test',
      'refs': <String, dynamic>{},
    };

SourceCard _source(String status) => SourceCard.fromJson({
      'source': 'satellite',
      'status': status,
      'headline': 'headline',
      'report_count': 0,
    });

/// Added with the Bhuvan/eSAKSHI wiring.
void _satelliteAndEsakshiTests() {
  group('SatelliteResult', () {
    test('names the adapter that produced the reading', () {
      final live = SatelliteResult.fromJson({
        'status': 'inconclusive',
        'confidence': 0.68,
        'method': 'ndbi_delta',
        'resolution_m': 2.5,
        'reason': 'target below sensor resolution',
        'adapter': 'bhuvan',
      });
      expect(live.isLive, isTrue);
      expect(live.sourceLabel, contains('Bhuvan'));

      final fixture = SatelliteResult.fromJson({
        'status': 'match',
        'confidence': 0.9,
        'method': 'fixture',
        'resolution_m': 2.5,
        'reason': 'seeded',
        'adapter': 'fixture',
      });
      expect(fixture.isLive, isFalse);
    });

    test('history rows without detectability do not fake a zero', () {
      // A stored observation carries no min_detectable_m. Defaulting it to 0
      // would render as "everything is detectable", which is a false claim.
      final history = SatelliteResult.fromJson({
        'status': 'inconclusive',
        'confidence': 0.68,
        'method': 'ndbi_delta',
        'resolution_m': 2.5,
        'reason': 'stored',
        'provider': 'bhuvan_cartosat_live',
      });
      expect(history.minDetectableM, isNull);
      expect(history.hasDetectability, isFalse);
      expect(history.isLive, isTrue);
    });

    test('inconclusive is a first-class verdict, not a failure', () {
      final r = SatelliteResult.fromJson({
        'status': 'inconclusive',
        'confidence': 0.68,
        'method': 'ndbi_delta',
        'resolution_m': 2.5,
        'reason': 'sub-resolution',
      });
      expect(r.isInconclusive, isTrue);
      expect(r.statusLabel, 'Below sensor resolution');
    });
  });

  group('EsakshiVerification', () {
    test('parses per-field checks and discrepancy list', () {
      final v = EsakshiVerification.fromJson({
        'matches': false,
        'amount_match': false,
        'status_match': true,
        'agency_match': true,
        'discrepancies': ['Sanctioned amount differs by ₹2.10 L'],
      });
      expect(v.matches, isFalse);
      expect(v.amountMatch, isFalse);
      expect(v.statusMatch, isTrue);
      expect(v.discrepancies, hasLength(1));
    });
  });

  group('GeoPlace', () {
    test('splits a Nominatim display name into name and context', () {
      const place = GeoPlace(
        displayName: 'Kolar Road, Bhopal, Madhya Pradesh, 462042, India',
        lat: 23.2,
        lon: 77.4,
      );
      expect(place.shortName, 'Kolar Road, Bhopal');
      expect(place.context, contains('Madhya Pradesh'));
    });
  });
}
