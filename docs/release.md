# Releasing the shop apps (Google Play)

Every shop is a separate app (its own package name from `clients/<slug>/client.json`) built from the
same code.

## Once

1. **Upload key** (one for all shop apps; Play App Signing keeps each app's real signing key):

   ```bash
   keytool -genkeypair -v -keystore ~/keys/qc-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   Back the `.jks` file and its password up somewhere safe (a password manager); losing it means asking
   Google to reset the upload key.
2. `app/android/key.properties` (gitignored):

   ```properties
   storeFile=/Users/you/keys/qc-upload.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```
3. `app/config/env.prod.json`: `{"ENV": "prod", "API_BASE_URL": "https://api.your-domain.in"}`
   (production builds refuse `http://`).
4. Google Play Console developer account (one-time fee; identity verification takes a few days).

## Each release

1. Bump `build.version` in the shop's `client.json` (`1.0.1+2`: name + version code; the code must grow
   with every upload).
2. Firebase (push): the shop's `google-services.json` in `clients/<slug>/` (see `docs/deploy.md`, section 7).
3. Build (from `app/`):

   ```bash
   ./tool/build_release.sh                 # every shop
   ./tool/build_release.sh sharma_kirana   # one shop
   ```

   Output: `build/release/<slug>.aab`. Keep `build/symbols/<slug>/` for that version: it turns
   obfuscated crash stack traces back into readable ones (`flutter symbolize`).
4. Play Console → the shop's app → Testing → Internal testing → upload the `.aab`, add testers (the
   owner, riders), roll out. Promote to Production after the pilot.

## First upload of a new shop app

- Create the app in Play Console with the shop's name; package name = `build.androidPackage`.
- Store listing: short and full description (English, Gujarati, Hindi), icon 512 px (`clients/<slug>/icon.png`
  scaled up), at least 2 phone screenshots, feature graphic 1024×500.
- App content:
  - Privacy policy URL (required): host one page per shop or a shared one naming the shop.
  - Data safety: phone number (login), name and address (delivery), approximate and precise location
    (riders only, while delivering), photos (prescriptions / lists / return photos, only when the customer
    adds them), purchase history. Data is encrypted in transit; users can ask for deletion.
  - Permissions: location in the background is not used (riders share location only through a
    foreground service with a visible notification while the app is in use).
  - Target audience: 18+; no ads.
- Content rating questionnaire (shopping app).

## Size

The release APK contains every CPU type (~55 MB); Play delivers per-device splits from the bundle, so the
download is much smaller. Code is shrunk and obfuscated (`proguard-rules.pro` keeps Razorpay classes).
