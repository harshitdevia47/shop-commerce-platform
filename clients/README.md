# Clients

One folder per client shop. The folder name must equal `slug` in `client.json`.

```
clients/<slug>/
├── client.json            all client-specific settings (validated by backend/packages/config-schema)
├── logo.png               shown in the app (512x512 PNG, transparent background recommended)
├── icon.png               launcher icon source (1024x1024 PNG, no transparency)
└── google-services.json   Firebase Android config for this app (not committed)
```

`client.json` is deep-merged on top of the preset for its `shop.businessType`
(`backend/packages/config-schema/src/presets.ts`), so only values that differ need to be set.
Arrays replace preset arrays; objects merge.

## Adding a client

1. Copy `clients/_template/` to `clients/<slug>/` and edit `client.json` + images.
2. `cd backend && npm run client -- validate <slug>`
3. `npm run client -- sync <slug>` (creates/updates the shop in the tenant service DB)
4. `cd app && dart run tool/gen_flavors.dart`
5. `flutter build apk --flavor <slug> --dart-define-from-file=config/clients/<slug>.json --dart-define-from-file=config/env.prod.json`
