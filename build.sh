#!/bin/bash
# Vercel web build. Supabase credentials come from Vercel project env vars;
# if unset, AppConfig falls back to its compiled-in defaults.
set -e

FLUTTER_DIR="/tmp/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth=1 "$FLUTTER_DIR"
fi

export PATH="$PATH:$FLUTTER_DIR/bin"

flutter config --enable-web
flutter pub get

DEFINES=""
[ -n "$SUPABASE_URL" ]      && DEFINES="$DEFINES --dart-define=SUPABASE_URL=$SUPABASE_URL"
[ -n "$SUPABASE_ANON_KEY" ] && DEFINES="$DEFINES --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
[ -n "$WEB_ORIGIN" ]        && DEFINES="$DEFINES --dart-define=WEB_ORIGIN=$WEB_ORIGIN"

flutter build web --release $DEFINES

# Android App Links verification file. Fill in the SHA-256 fingerprint of your
# upload keystore, then this lets https://<domain>/bidet/<id> open the APK:
#   keytool -list -v -keystore upload-keystore.jks -alias upload
mkdir -p build/web/.well-known
if [ -n "$ANDROID_CERT_SHA256" ]; then
  cat > build/web/.well-known/assetlinks.json <<JSON
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "ph.sanbidet.cebu",
    "sha256_cert_fingerprints": ["$ANDROID_CERT_SHA256"]
  }
}]
JSON
fi
