#!/bin/sh
# Builds a Play Store bundle (.aab) for every client (or the slugs given), signed with
# android/key.properties, against config/env.prod.json. Obfuscated; symbols kept per client for
# crash stack traces. Run from app/:  ./tool/build_release.sh [slug ...]
set -eu

cd "$(dirname "$0")/.."
[ -f config/env.prod.json ] || { echo "config/env.prod.json missing" >&2; exit 1; }
grep -q 'api.example.in' config/env.prod.json && { echo "Set API_BASE_URL in config/env.prod.json first" >&2; exit 1; }
[ -f android/key.properties ] || echo "WARNING: android/key.properties missing: bundles are signed with the debug key (not uploadable)" >&2

dart run tool/gen_flavors.dart
SLUGS="${*:-$(ls config/clients | sed 's/\.json$//')}"
mkdir -p build/release
for slug in $SLUGS; do
  echo "== $slug"
  flutter build appbundle --release --flavor "$slug" \
    --dart-define-from-file="config/clients/$slug.json" \
    --dart-define-from-file=config/env.prod.json \
    --obfuscate --split-debug-info="build/symbols/$slug"
  cp "build/app/outputs/bundle/${slug}Release/app-${slug}-release.aab" "build/release/$slug.aab"
done
ls -lh build/release
