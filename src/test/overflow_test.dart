/// Layout under the conditions this app actually meets.
///
/// A field officer's phone is often 320-360 logical pixels wide, the ward and
/// agency names in MPLADS records are long, and Hindi runs longer than English
/// for the same content. Flutter reports a RenderFlex overflow as a test
/// failure, so rendering the real widgets at the narrow end with long values
/// is the check - no screenshot required.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mplad_satya/data/models/money.dart';
import 'package:mplad_satya/data/models/work.dart';
import 'package:mplad_satya/data/models/evidence.dart';
import 'package:mplad_satya/data/models/risk.dart';
import 'package:mplad_satya/widgets/evidence_tile.dart';
import 'package:mplad_satya/widgets/provenance.dart';
import 'package:mplad_satya/widgets/source_card_tile.dart';
import 'package:mplad_satya/widgets/work_card.dart';

/// Narrowest phone the app is expected to serve.
const _narrow = Size(320, 640);

Future<void> _pumpAt(WidgetTester tester, Widget child, {Size size = _narrow}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ));
}

WorkSummary _work({
  String title = 'Road Construction',
  String? ward,
  String? district,
  String display = '₹15.60 L',
  int? score = 80,
  String? band = 'red',
  String? distanceLabel,
}) =>
    WorkSummary(
      id: 'w1',
      workCode: 'MP/2026/1142',
      title: title,
      category: 'road',
      status: 'in_progress',
      sanctionedAmount: Money(paise: 1560000000, display: display),
      ward: ward,
      districtName: district,
      riskScore: score,
      riskBand: band,
      bandLabel: 'HIGH RISK',
      distanceLabel: distanceLabel,
    );

void main() {
  group('WorkCard on a 320px screen', () {
    testWidgets('an ordinary work fits', (tester) async {
      await _pumpAt(tester, WorkCard(work: _work(ward: 'Ward 12')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long real-world title and ward fit', (tester) async {
      // Verbatim shape of a genuine MPLADS entry: these are not padded.
      await _pumpAt(
        tester,
        WorkCard(
          work: _work(
            title: 'Construction of CC Road from Shri Ram Mandir to '
                'Primary Health Centre including side drain, Ward 12',
            ward: 'Kolar Road Ward 12 (Bagh Mugaliya Extension)',
            district: 'Bhopal',
            display: '₹1,23,45,678.00',
            distanceLabel: '12.4 km away',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Hindi, which runs longer than English, fits', (tester) async {
      await _pumpAt(
        tester,
        WorkCard(
          work: _work(
            title: 'प्राथमिक स्वास्थ्य केंद्र तक सीसी रोड का निर्माण, वार्ड १२',
            ward: 'कोलार रोड वार्ड १२',
            district: 'भोपाल',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unscored work shows no score without collapsing',
        (tester) async {
      await _pumpAt(
        tester,
        WorkCard(work: _work(score: null, band: null, ward: 'Ward 7')),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Source cards on a 320px screen', () {
    SourceCard card(String headline, {String status = 'mismatch'}) => SourceCard(
          source: 'citizen',
          status: status,
          headline: headline,
          reportCount: 3,
          confidence: 68,
          observedValue: 52,
          expectedValue: 100,
          observedUnit: 'm',
        );

    testWidgets('a short headline fits', (tester) async {
      await _pumpAt(tester, SourceCardTile(source: card('3 mismatch reports')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a full-sentence headline fits', (tester) async {
      // Headlines are server-authored sentences, not labels.
      await _pumpAt(
        tester,
        SourceCardTile(
          source: card('Three residents reported the road as not constructed, '
              'the most recent 4 days ago, all within 60 m of the site'),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unavailable source states the outage', (tester) async {
      await _pumpAt(
        tester,
        SourceCardTile(
          source: card(
            'Bhuvan returned no imagery for this location; the service is '
            'reachable but serves thematic layers rather than per-site tiles',
            status: 'unavailable',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Evidence tiles on a 320px screen', () {
    Evidence ev({List<String> flags = const []}) => Evidence(
          id: 'e1',
          workId: 'w1',
          source: 'field_officer',
          kind: 'photo',
          storageUrl: 'https://example.invalid/e1.jpg',
          sha256: 'a' * 64,
          facesBlurred: 2,
          gpsTrust: 40,
          gpsFlags: flags,
          capturedAt: DateTime.utc(2026, 9, 12, 11, 4),
          phashHex: 'ff00ab12cd34ef56',
        );

    testWidgets('a clean capture fits', (tester) async {
      await _pumpAt(tester, EvidenceTile(evidence: ev()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('every spoof flag at once still fits', (tester) async {
      // The worst real case: a photo that tripped every GPS heuristic.
      await _pumpAt(
        tester,
        EvidenceTile(
          evidence: ev(flags: const [
            'mock_location_flag',
            'gps_offset_41207m',
            'accuracy_implausibly_precise',
            'capture_upload_skew_9d',
            'work_location_unknown',
          ]),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Provenance on a 320px screen', () {
    testWidgets('a chip with a long source name fits', (tester) async {
      await _pumpAt(
        tester,
        const ProvenanceChip(
          state: SourceState.official,
          detail: 'CPWD Delhi Schedule of Rates 2023, item 4.2 (bituminous)',
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a block with a long limitation fits', (tester) async {
      await _pumpAt(
        tester,
        const ProvenanceBlock(
          state: SourceState.fixture,
          source: 'ISRO Bhuvan (Cartosat-2S, 2.5 m panchromatic)',
          isIndependent: false,
          observedAt: '2026-09-12T04:11:00Z',
          limitation: 'Cartosat resolves about 2.5 m and a ward drain is about '
              '1 m wide, so this sensor cannot confirm or contradict works of '
              'this size; the verdict is inconclusive by design.',
          reference: 'bhuvan.nrsc.gov.in',
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
