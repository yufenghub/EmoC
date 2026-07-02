# Versioning

EmoC uses semantic versioning for public releases.

```text
MAJOR.MINOR.PATCH+BUILD
```

Example:

```yaml
version: 1.0.0+1
```

## Version Name

`MAJOR.MINOR.PATCH` is the public version shown to users.

- Increase `MAJOR` for incompatible app behavior or data changes.
- Increase `MINOR` for new user-facing features.
- Increase `PATCH` for bug fixes, compatibility updates, and polish.

## Build Number

The value after `+` is the Android `versionCode`.

Rules:

- It must be a positive integer.
- It must increase for every APK/AAB published to users.
- Never reuse an old build number for a new public release.

## Tags

GitHub releases should use tags like:

```text
v1.0.0
v1.0.1
v1.1.0
```

Pre-release tags may use:

```text
v1.1.0-beta.1
```

## Release Checklist

- Update `pubspec.yaml`.
- Update `CHANGELOG.md`.
- Build a signed release APK.
- Verify installation and basic playback/login flows.
- Create a GitHub Release and upload the APK.
- Keep signing keys private and backed up.
