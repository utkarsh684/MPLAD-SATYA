import '../../core/config.dart';
import 'json.dart';

/// Mirrors `EvidenceOut` — one uploaded photo with its forensic metadata.
class Evidence {
  final String id;
  final String workId;
  final String source;
  final String kind;
  final String storageUrl;
  final String sha256;
  final String? mime;
  final int? bytesLen;
  final int? width;
  final int? height;
  final DateTime? capturedAt;

  /// 0-100. Computed server-side from EXIF GPS against the work location.
  final int? gpsTrust;
  final List<String> gpsFlags;

  /// DPDP compliance: faces are blurred on ingest, before the file is served.
  final int facesBlurred;
  final String? phashHex;
  final String? clientUuid;
  final DateTime? createdAt;

  const Evidence({
    required this.id,
    required this.workId,
    required this.source,
    required this.kind,
    required this.storageUrl,
    required this.sha256,
    required this.facesBlurred,
    this.mime,
    this.bytesLen,
    this.width,
    this.height,
    this.capturedAt,
    this.gpsTrust,
    this.gpsFlags = const [],
    this.phashHex,
    this.clientUuid,
    this.createdAt,
  });

  factory Evidence.fromJson(Map<String, dynamic> json) => Evidence(
        id: asString(json['id']),
        workId: asString(json['work_id']),
        source: asString(json['source']),
        kind: asString(json['kind']),
        storageUrl: asString(json['storage_url']),
        sha256: asString(json['sha256']),
        mime: asStringOrNull(json['mime']),
        bytesLen: asIntOrNull(json['bytes_len']),
        width: asIntOrNull(json['width']),
        height: asIntOrNull(json['height']),
        capturedAt: asDate(json['captured_at']),
        gpsTrust: asIntOrNull(json['gps_trust']),
        gpsFlags: asStringList(json['gps_flags']),
        facesBlurred: asInt(json['faces_blurred']),
        phashHex: asStringOrNull(json['phash_hex']),
        clientUuid: asStringOrNull(json['client_uuid']),
        createdAt: asDate(json['created_at']),
      );

  /// The server returns a path under /media; make it absolute for Image.network.
  String get absoluteUrl => storageUrl.startsWith('http')
      ? storageUrl
      : AppConfig.rootUri(storageUrl).toString();

  String get trustLabel {
    final t = gpsTrust;
    if (t == null) return 'No GPS data';
    if (t >= 80) return 'GPS verified';
    if (t >= 50) return 'GPS partially verified';
    return 'GPS unreliable';
  }
}
