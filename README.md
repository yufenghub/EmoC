# EmoC

EmoC is a third-party, free Android music client built with Flutter and native
Kotlin components. It provides a mobile-first interface, playback controls,
playlist views, lyrics, desktop lyrics, and Android media session integration.

This project is not affiliated with, endorsed by, sponsored by, or officially
connected to NetEase Cloud Music. All trademarks, service names, and music
content belong to their respective owners.

## Status

This repository contains the application source code. Release signing secrets,
local build outputs, and machine-specific configuration files are intentionally
excluded from version control.

## Requirements

- Flutter SDK
- Android SDK
- JDK 17
- Android Studio or compatible command-line build tools

The project has been developed and tested on Windows.

## Build

```powershell
flutter pub get
flutter build apk
```

The release APK is generated at:

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

Do not commit the real `key.properties` file or keystore file. Losing the
release keystore means future versions cannot upgrade existing installations
with the same package name.

## Repository Hygiene

The following are intentionally ignored:

- `build/`
- `.dart_tool/`
- Android Studio project caches
- `android/local.properties`
- `android/key.properties`
- `*.jks`
- `*.keystore`
- generated APK/AAB files

## Disclaimer

EmoC is a third-party and free project. It is provided for learning,
interoperability research, and personal use. Users are responsible for complying
with applicable laws, service terms, and content rights in their region.

The maintainers do not provide or host copyrighted music content.
