# 版本规则 / Versioning

EmoC 的公开版本采用语义化版本。

EmoC uses semantic versioning for public releases.

```text
MAJOR.MINOR.PATCH+BUILD
```

示例 / Example:

```yaml
version: 1.0.0+1
```

## 显示版本 / Version Name

`MAJOR.MINOR.PATCH` 是展示给用户的版本号。

`MAJOR.MINOR.PATCH` is the public version shown to users.

- `MAJOR`：不兼容的应用行为或数据变更。
  Breaking application or data-behavior changes.
- `MINOR`：新增用户可见功能。
  New user-facing features.
- `PATCH`：修复、兼容性更新和小幅优化。
  Bug fixes, compatibility updates, and polish.

## 构建号 / Build Number

`+` 后的数字是 Android `versionCode`。

The value after `+` is the Android `versionCode`.

规则 / Rules:

- 必须是正整数。
  It must be a positive integer.
- 每次发布给用户的 APK/AAB 都必须递增。
  It must increase for every APK/AAB published to users.
- 不要为新的公开版本复用旧构建号。
  Never reuse an old build number for a new public release.

## 标签 / Tags

GitHub Release 标签建议使用：

GitHub releases should use tags like:

```text
v1.0.0
v1.0.1
v1.1.0
```

预发布标签可使用：

Pre-release tags may use:

```text
v1.1.0-beta.1
```

## 发布检查 / Release Checklist

- 更新 `pubspec.yaml`。
  Update `pubspec.yaml`.
- 更新 `CHANGELOG.md`。
  Update `CHANGELOG.md`.
- 构建签名 release APK。
  Build a signed release APK.
- 验证安装、登录、播放和基础页面流程。
  Verify installation, login, playback, and basic page flows.
- 创建 GitHub Release 并上传 APK。
  Create a GitHub Release and upload the APK.
- 私密保存并备份签名密钥。
  Keep signing keys private and backed up.
