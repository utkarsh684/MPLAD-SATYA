# Build configurations

Flutter's own mechanism for build-time configuration, `--dart-define-from-file`
(Flutter 3.7+). These are *not* secrets and *not* a runtime `.env`: the values
are compiled into the binary, which is why the endpoint can never be silently
wrong at runtime.

```bash
flutter run   --dart-define-from-file=config/render.json     # deployed API
flutter run   --dart-define-from-file=config/local.json      # emulator -> host
flutter run   --dart-define-from-file=config/hotspot.json    # phone -> laptop
flutter build apk --release --dart-define-from-file=config/render.json
```

| File | Points at | Cleartext? |
|---|---|---|
| `render.json` | the deployed Render service | no — HTTPS |
| `local.json` | `10.0.2.2:8000`, the host as seen from the Android emulator | debug builds only |
| `hotspot.json` | a laptop on the demo hotspot — **edit the IP to match** | debug builds only |

`render.json` is the default target, and `AppConfig.apiBaseUrl` already falls
back to it, so a plain `flutter build apk` produces a working demo build.

The two HTTP files only work in **debug** builds: the release network security
config denies cleartext, so a signed APK cannot send a session token or a site
photograph over plaintext. That is deliberate and must not be "fixed" by
relaxing the release policy.

Whatever is compiled in is shown on the login screen and in Settings → Server,
so a device pointed at the wrong host is visible immediately.
