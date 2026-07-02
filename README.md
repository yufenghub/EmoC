# EmoC

> A third-party, free Android music client with a native mobile UI.

[![License: GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-3f7bff.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android-34c759.svg)](#requirements)
[![Flutter](https://img.shields.io/badge/built%20with-Flutter-54c5f8.svg)](https://flutter.dev)

EmoC is a Flutter + Kotlin Android client that presents a mobile-first music
experience while using NetEase Cloud Music account and content services through
the official website/session flow.

This project is third-party, free, and unofficial. It is not affiliated with,
endorsed by, sponsored by, or officially connected to NetEase Cloud Music.
Music, lyrics, cover art, accounts, trademarks, and service availability belong
to their respective rights holders.

## Highlights

- Mobile-first home, playlist, search, lyrics, and settings pages.
- NetEase Cloud Music login flow with persisted login state.
- Playlist view for liked songs and user-created playlists.
- Native Android media controls and system playback integration.
- Synced lyrics page and optional desktop lyrics overlay.
- Dynamic color, light/dark/system theme modes, and playback preferences.
- Local cache for faster app startup and playback-list restoration.

## Screenshots

Screenshots are not committed yet. Place public screenshots in
`.github/assets/` and reference them here before making the repository public.

| Home | Playlists | Lyrics | Settings |
| ---- | --------- | ------ | -------- |
| To be added | To be added | To be added | To be added |

## Download

Release APKs are published from the GitHub Releases page after signing:

<https://github.com/yufenghub/EmoC/releases>

If no release is listed yet, build locally with the instructions below.

## Requirements

- Flutter SDK
- Android SDK
- JDK 17
- Android Studio or compatible command-line build tools

The project is currently developed and tested on Windows.

## Build

```powershell
flutter pub get
flutter build apk
```

The generated release APK is written to:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Release Signing

Release builds require `android/key.properties`. Use
`android/key.properties.example` as a template:

```properties
storePassword=replace_with_store_password
keyPassword=replace_with_key_password
keyAlias=emoc-release
storeFile=../release-keystore/emoc-release.jks
```

Do not commit the real `key.properties` file or keystore file. Keep the release
keystore backed up securely. Losing it means future versions cannot upgrade
existing installations with the same package name.

## Versioning

EmoC follows semantic versioning for public releases:

- `MAJOR`: breaking application or data-behavior changes.
- `MINOR`: new user-facing features.
- `PATCH`: bug fixes and small compatibility updates.

Flutter/Android versions use the format in `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

`1.0.0` is the visible Android `versionName`; `1` is the Android `versionCode`
and must increase for every published APK.

See [VERSIONING.md](VERSIONING.md) for the full release rule.

## Repository Hygiene

The following are intentionally excluded from version control:

- `build/`
- `.dart_tool/`
- Android Studio project caches
- `android/local.properties`
- `android/key.properties`
- `*.jks`
- `*.keystore`
- generated APK/AAB files

## Privacy

EmoC does not run a custom analytics backend and does not host music content.
Account login, playback, search, playlists, lyrics, and related network traffic
are handled through NetEase Cloud Music services.

See [PRIVACY.md](PRIVACY.md) for details.

## Disclaimer

EmoC is a third-party and free project for learning, interoperability research,
and personal use. Users are responsible for complying with applicable laws,
service terms, and content rights in their region.

See [DISCLAIMER.md](DISCLAIMER.md) before public distribution or redistribution.

## Acknowledgements

No formal acknowledgements yet.

The project layout and release-facing README structure were organized with
reference to public Android/music-player projects such as SPlayer, while keeping
EmoC's own technical architecture and legal wording.

## License

EmoC is licensed under the GNU General Public License v3.0 or later.
See [LICENSE](LICENSE).
