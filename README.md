# SanBidet Cebu

Crowdsourced bidet locations across Cebu — mapped, rated and verified by the
community. One Flutter codebase ships as a **web app** (Vercel) and an
**Android APK**.

## Architecture

```
lib/
  main.dart              Bootstrap: init Supabase, construct repositories
  app.dart               Root widget, owns SessionController + GoRouter
  core/
    app_config.dart      Build-time config (--dart-define)
    theme.dart           shadcn slate theme (light + dark), spacing tokens
    app_scope.dart       DI via InheritedWidget, plus SessionController
    router.dart          go_router routes, guards and deep links
  data/
    models/bidet.dart    Bidet, BidetType, BidetStatus, BidetRating
    bidet_repository.dart  BidetRepository interface + Supabase impl
    auth_repository.dart   AuthRepository interface + Supabase impl
  features/              One folder per screen (incl. dashboard)
    map/                 flutter_map + Mapbox 3D (web_map / mobile_map)
  services/              Location, GIS export, platform file download
  widgets/               Shared UI (AppTextField, EmptyState, StarRow, …)
supabase/migrations/     SQL: ratings, RLS, storage, timestamptz
```

Screens depend on the repository **interfaces**, never on Supabase directly.
They resolve them from `AppScope` (`context.bidets`, `context.auth`,
`context.session`, `context.location`), which is what makes them testable and
what would make a backend swap a single-class change.

## Setup

### 1. Database

Run the migrations in `supabase/migrations/` in order, in the Supabase SQL
editor. Both are idempotent.

- `0001_ratings_and_policies.sql` — `profiles` and `bidet_ratings` tables, the
  `submit_bidet_rating()` function, the `bidet-images` bucket, and all
  row-level-security policies. Adapts to an existing `profiles` table rather
  than assuming it can create one.
- `0003_reports_access_and_moderation.sql` — access details, a rejected state
  with a reason, the reports table, contributor attribution, and the proximity
  lookup used to catch duplicates.
- `0002_timestamptz.sql` — makes `created_at` timezone-aware, so dates no
  longer read eight hours early in Cebu.

Then promote yourself to admin:

```sql
update public.profiles set role = 'admin'
where id = (select id from auth.users where email = 'you@example.com');
```

### 2. Configuration

Credentials come from `--dart-define`, with the current project compiled in as
a fallback:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxx
```

On Vercel, set `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `WEB_ORIGIN` as project
environment variables; [`build.sh`](build.sh) forwards them.

## Building

### Web

```bash
flutter build web --release
```

Vercel runs `build.sh` and serves `build/web`. Note `--wasm` is **not**
available: `geolocator_web` still imports `dart:html`.

### Android

Always build per-ABI. A fat APK ships arm64 + armeabi + x86_64 native libs to
every device:

```bash
flutter build apk --release --split-per-abi
```

| Build | Size |
| --- | --- |
| Fat APK (before the split) | 50.3 MB |
| arm64-v8a | 43.3 MB |
| armeabi-v7a | 34.4 MB |
| x86_64 | 46.0 MB |

The Mapbox native SDK is most of that weight. Dropping `mapbox_maps_flutter`
and keeping only the flutter_map tile layers takes arm64 down to roughly
18 MB, if size matters more than the 3D view.

**After changing dependencies, run `flutter clean`.** The generated
`web_plugin_registrant.dart` is cached and will keep importing removed plugins,
failing the web build with confusing "couldn't resolve package" errors.

### Release signing

Release builds fall back to debug keys when `android/key.properties` is
missing, and Gradle prints a warning. Such an APK is **not** distributable —
and if you ship one, you can never upgrade those installs with a properly
signed build.

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Copy `android/key.properties.example` to `android/key.properties` and fill it
in. Both the keystore and `key.properties` are gitignored.

CI ([`.github/workflows/android-release.yml`](.github/workflows/android-release.yml))
builds signed APKs on a `v*` tag from the `KEYSTORE_BASE64`,
`KEYSTORE_PASSWORD`, `KEY_PASSWORD` and `KEY_ALIAS` secrets.

### Deep links

`/bidet/<id>` is a real URL on web and an Android App Link. To make links open
the app instead of the browser:

1. Set the real domain in `android:host` in
   [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml)
   (currently the placeholder `sanbidet-cebu.vercel.app`).
2. Get your signing fingerprint:
   `keytool -list -v -keystore upload-keystore.jks -alias upload`
3. Set `ANDROID_CERT_SHA256` in Vercel; `build.sh` writes
   `/.well-known/assetlinks.json` from it.

## Testing

```bash
flutter analyze   # clean
flutter test      # 28 tests
```

Both targets build: `flutter build web --release` and
`flutter build apk --release --split-per-abi`.

`test/fakes.dart` provides `FakeBidetRepository` and `FakeAuthRepository`;
`wrap()` in `test/widget_test.dart` mounts a widget with theme + DI in place.

## Permissions

`android/app/src/main/AndroidManifest.xml` declares `INTERNET`,
`ACCESS_NETWORK_STATE`, `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`
explicitly. **Do not remove these.** `INTERNET` used to arrive only via the
`firebase-firestore` AAR, so dropping that unused dependency would have
silently stripped network access from release builds. The location permissions
were never declared at all, which meant `geolocator` was denied immediately and
bidets could not be submitted from the APK.
