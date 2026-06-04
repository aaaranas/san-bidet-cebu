# SanBidet Cebu

> Crowdsourcing clean bidets across Cebu, one spray at a time.

## Description

SanBidet Cebu is a community-driven mobile and web application built to help people in Cebu, Philippines find and share bidet locations. Whether you're a local or a visitor, the app makes it easy to discover nearby facilities with working bidets, sorted by your current location.

The platform is powered by crowdsourced contributions. Users can add new bidet locations, upload photos, and rate facilities across four categories — cleanliness, pressure, accessibility, and privacy — giving others a reliable picture of what to expect before they arrive.

To maintain data quality, submitted locations go through an approval workflow before appearing on the map. An admin moderation panel lets trusted community members review pending contributions, keeping the map accurate and trustworthy. GIS data export is also available for researchers and urban planners interested in sanitation infrastructure.

## Features

- Interactive map of bidet locations sorted by proximity to the user
- Support for multiple bidet types: spray hose, tabo, and bidet seats
- 4-category community rating system: cleanliness, pressure, accessibility, and privacy
- Crowd-sourced location contributions with photo uploads
- User authentication (sign up, log in, profile management)
- Admin moderation panel with location approval workflow (pending → approved)
- GIS data export for spatial analysis
- Cross-platform: iOS, Android, macOS, Linux, Windows, and Web
- Web version deployed on Vercel

## Tech Stack

| Category | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Backend / Database | Supabase (PostgreSQL + Auth + Storage) |
| Mapping | flutter_map, latlong2 |
| Geolocation | geolocator, permission_handler |
| Navigation | go_router |
| Media | image_picker, cached_network_image |
| Utilities | share_plus, url_launcher, path_provider |
| Web Deployment | Vercel |

## Getting Started

### Prerequisites

- [Flutter SDK 3.9.2+](https://docs.flutter.dev/get-started/install)
- Dart (included with Flutter)
- A [Supabase](https://supabase.com) project with the required tables and storage buckets set up
- For mobile builds: Android Studio or Xcode (depending on target platform)

### Setup

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd san-bidet-cebu
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Configure Supabase credentials**

   Open `lib/main.dart` and replace the placeholder values with your Supabase project URL and anon key:

   ```dart
   await Supabase.initialize(
     url: 'YOUR_SUPABASE_URL',
     anonKey: 'YOUR_SUPABASE_ANON_KEY',
   );
   ```

4. **Run the app**

   ```bash
   # Run on a connected device or emulator
   flutter run

   # Run for a specific platform
   flutter run -d chrome        # Web
   flutter run -d android
   flutter run -d ios
   ```

5. **Build for web (Vercel deployment)**

   ```bash
   flutter build web
   ```

   Deploy the contents of `build/web` to Vercel.

## Project Structure

```
lib/
  features/          # Feature modules (home, auth, map, bidet, admin)
  services/          # SupabaseService, AuthService, LocationService
  widgets/           # Reusable UI components
ios/                 # iOS platform files
android/             # Android platform files
web/                 # Web platform files
windows/             # Windows platform files
linux/               # Linux platform files
macos/               # macOS platform files
```

Each feature module under `lib/features/` contains its own screens, widgets, and logic, keeping the codebase organized and easy to navigate.

## Contributing

Contributions are welcome. If you know of a bidet location in Cebu that isn't on the map, the best way to contribute is through the app itself. For code contributions, please open an issue first to discuss what you'd like to change, then submit a pull request against the main branch.

## License

This project is open source. See the [LICENSE](LICENSE) file for details.
