# qc_app (Flutter)

One codebase, one Android flavor per client shop. See `../CLAUDE.md` for architecture and conventions.

## First-time setup

```sh
flutter pub get
dart run tool/gen_flavors.dart      # flavors, flavor assets, build defines from ../clients/*
dart run flutter_launcher_icons     # per-flavor launcher icons
```

Re-run `gen_flavors` whenever a client is added or its `client.json`/images change.

## Run / build

```sh
# Android emulator talking to the local gateway (10.0.2.2 = host machine)
flutter run --flavor sharma_kirana \
  --dart-define-from-file=config/clients/sharma_kirana.json \
  --dart-define-from-file=config/env.dev.json

# Release APK for a client
flutter build apk --release --flavor sharma_kirana \
  --dart-define-from-file=config/clients/sharma_kirana.json \
  --dart-define-from-file=config/env.prod.json
```

## Test

```sh
flutter analyze && flutter test
```
