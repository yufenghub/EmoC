# EmoC

> 第三方、免费的 Android 音乐客户端，使用原生移动界面呈现。
> A third-party, free Android music client with a native mobile UI.

[![许可证 / License: GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-3f7bff.svg)](LICENSE)
[![平台 / Platform](https://img.shields.io/badge/platform-Android-34c759.svg)](#环境要求--requirements)
[![Flutter](https://img.shields.io/badge/built%20with-Flutter-54c5f8.svg)](https://flutter.dev)

## 项目说明 / About

EmoC 是一个 Flutter + Kotlin Android 客户端，目标是用更适合手机的界面呈现音乐、歌单、搜索、歌词、桌面歌词和系统媒体控制等体验。应用依赖用户自己的网易云音乐账号与官网会话流程。

EmoC is a Flutter + Kotlin Android client that presents a mobile-first music experience, including playlists, search, lyrics, desktop lyrics, and Android media controls. It depends on the user's own NetEase Cloud Music account and official website/session flow.

> [!IMPORTANT]
> EmoC 是第三方、免费、非官方项目。它不隶属于网易云音乐，也未获得网易云音乐官方授权、赞助、认可或合作。音乐、歌词、封面、账号、商标和服务可用性均归相应权利方所有。
>
> EmoC is third-party, free, and unofficial. It is not affiliated with, endorsed by, sponsored by, authorized by, or officially connected to NetEase Cloud Music. Music, lyrics, cover art, accounts, trademarks, and service availability belong to their respective rights holders.

## 功能特性 / Features

- 移动端优先：首页、歌单、搜索、歌词和设置页面。
  Mobile-first home, playlist, search, lyrics, and settings pages.
- 网易云音乐登录流程与登录状态保存。
  NetEase Cloud Music login flow with persisted login state.
- 展示喜欢的音乐和用户创建的歌单。
  Playlist views for liked songs and user-created playlists.
- Android 系统媒体控件、通知栏播放状态和播放会话集成。
  Native Android media controls, notification playback state, and media-session integration.
- 同步歌词页面与可选桌面歌词悬浮窗。
  Synced lyrics page and optional desktop lyrics overlay.
- 动态取色、浅色/深色/跟随系统主题和播放偏好。
  Dynamic color, light/dark/system theme modes, and playback preferences.
- 本地缓存，用于更快启动和恢复播放列表状态。
  Local cache for faster startup and playback-list restoration.

## 界面展示 / Screenshots

截图暂未提交。准备公开仓库前，可将公开截图放入 `.github/assets/` 并在这里引用。

Screenshots are not committed yet. Place public screenshots in `.github/assets/` and reference them here before making the repository public.

| 首页 / Home | 歌单 / Playlists | 歌词 / Lyrics | 设置 / Settings |
| --- | --- | --- | --- |
| 待补充 / To be added | 待补充 / To be added | 待补充 / To be added | 待补充 / To be added |

## 下载 / Download

签名后的 APK 会发布在 GitHub Releases：

Signed APKs are published on GitHub Releases:

<https://github.com/yufenghub/EmoC/releases>

如果还没有 Release，可以按下方步骤本地构建。

If no release is listed yet, build locally with the instructions below.

## 环境要求 / Requirements

- Flutter SDK
- Android SDK
- JDK 17
- Android Studio 或兼容的命令行构建工具
  Android Studio or compatible command-line build tools

当前主要在 Windows 上开发和测试。

The project is currently developed and tested on Windows.

## 构建 / Build

```powershell
flutter pub get
flutter build apk
```

生成的 release APK 位于：

The generated release APK is written to:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 发布签名 / Release Signing

Release 构建需要 `android/key.properties`。请使用 `android/key.properties.example` 作为模板：

Release builds require `android/key.properties`. Use `android/key.properties.example` as a template:

```properties
storePassword=replace_with_store_password
keyPassword=replace_with_key_password
keyAlias=emoc-release
storeFile=../release-keystore/emoc-release.jks
```

不要提交真实的 `key.properties` 或 keystore 文件。请安全备份 release keystore；丢失后，相同包名的后续版本将无法覆盖升级旧安装。

Do not commit the real `key.properties` file or keystore file. Keep the release keystore backed up securely. Losing it means future versions cannot upgrade existing installations with the same package name.

## 版本规则 / Versioning

EmoC 的公开版本遵循语义化版本：

EmoC follows semantic versioning for public releases:

- `MAJOR`：不兼容的应用行为或数据变更。
  Breaking application or data-behavior changes.
- `MINOR`：新增用户可见功能。
  New user-facing features.
- `PATCH`：修复、兼容性更新和小幅优化。
  Bug fixes, compatibility updates, and polish.

Flutter/Android 版本号写在 `pubspec.yaml`：

Flutter/Android versions use the format in `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

`1.0.0` 是 Android `versionName`，`1` 是 Android `versionCode`。每次向用户发布 APK 时，`versionCode` 必须递增。

`1.0.0` is the Android `versionName`; `1` is the Android `versionCode` and must increase for every published APK.

完整规则见 [VERSIONING.md](VERSIONING.md)。

See [VERSIONING.md](VERSIONING.md) for the full release rule.

## 仓库规范 / Repository Hygiene

以下内容会被有意排除在版本控制之外：

The following are intentionally excluded from version control:

- `build/`
- `.dart_tool/`
- Android Studio project caches
- `android/local.properties`
- `android/key.properties`
- `*.jks`
- `*.keystore`
- generated APK/AAB files

## 隐私 / Privacy

EmoC 不运行独立分析后台，也不托管音乐内容。账号登录、播放、搜索、歌单、歌词等相关网络请求依赖网易云音乐服务。

EmoC does not run a custom analytics backend and does not host music content. Account login, playback, search, playlists, lyrics, and related network traffic are handled through NetEase Cloud Music services.

详情见 [PRIVACY.md](PRIVACY.md)。

See [PRIVACY.md](PRIVACY.md) for details.

## 免责声明 / Disclaimer

EmoC 是第三方、免费项目，面向学习、互操作研究和个人使用。用户需自行遵守所在地法律法规、平台服务条款和内容权利要求。

EmoC is a third-party and free project for learning, interoperability research, and personal use. Users are responsible for complying with applicable laws, service terms, and content rights in their region.

公开分发或再分发前请阅读 [DISCLAIMER.md](DISCLAIMER.md)。

See [DISCLAIMER.md](DISCLAIMER.md) before public distribution or redistribution.

## 鸣谢 / Acknowledgements

暂无正式鸣谢。

No formal acknowledgements yet.

仓库展示结构参考了 SPlayer 等公开 Android/音乐播放器项目，同时保留 EmoC 自己的技术架构和法律表述。

The release-facing repository structure was organized with reference to public Android/music-player projects such as SPlayer, while keeping EmoC's own technical architecture and legal wording.

## 许可证 / License

EmoC 使用 GNU General Public License v3.0 or later，即 `GPL-3.0-or-later`。

EmoC is licensed under the GNU General Public License v3.0 or later, `GPL-3.0-or-later`.

见 [LICENSE](LICENSE) 和 [NOTICE](NOTICE)。

See [LICENSE](LICENSE) and [NOTICE](NOTICE).
