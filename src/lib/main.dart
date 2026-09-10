import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/api/api_client.dart';
import 'data/repositories/analytics_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/decisions_repository.dart';
import 'data/repositories/field_repository.dart';
import 'data/repositories/works_repository.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/outbox_provider.dart';
import 'providers/server_status_provider.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiClient();
  await api.init();

  final auth = AuthProvider(api, AuthRepository(api));
  final analytics = AnalyticsRepository(api);
  final field = FieldRepository(api);
  final outbox = OutboxProvider(field);

  // Kick off session restore and the server handshake in parallel with the
  // splash animation, so the first frame after splash already has real state.
  final serverStatus = ServerStatusProvider(analytics);
  unawaited(auth.restore());
  unawaited(serverStatus.refresh());
  unawaited(outbox.init());

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider<WorksRepository>(create: (_) => WorksRepository(api)),
        Provider<FieldRepository>.value(value: field),
        Provider<DecisionsRepository>(create: (_) => DecisionsRepository(api)),
        Provider<AnalyticsRepository>.value(value: analytics),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: serverStatus),
        ChangeNotifierProvider.value(value: outbox),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const MpladSatyaApp(),
    ),
  );
}

/// Fire-and-forget without dragging in dart:async at the call site.
void unawaited(Future<void> future) {
  future.catchError((_) {});
}
