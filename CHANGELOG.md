# 更新日志 / Changelog

EmoC 的公开变化会记录在这里。

All notable public changes to EmoC will be documented in this file.

公开版本应与 `pubspec.yaml` 中的版本一致。

Public versions should match the version in `pubspec.yaml`.

## [1.0.4] - 2026-07-14

### 优化 / Improved

- 增强后台播放保护：歌曲结束后保持前台媒体服务和系统播放状态，并为自动续播增加原生事件重试与超时恢复。
  Strengthened background playback by keeping the foreground media service active between tracks and adding native retry and timeout recovery for automatic advancement.
- 为播放地址请求增加真正的全局超时；网络异常或遇到当前账号不可播放的歌曲时，可继续尝试播放列表中的下一首。
  Added a real global timeout for playback URL requests so network failures or unavailable tracks can advance to the next queue item.
- 优化歌单歌曲与封面缓存、长列表分批展示和播放列表状态恢复，减少首次加载与滚动卡顿。
  Improved playlist-song and artwork caching, incremental long-list rendering, and queue restoration to reduce startup and scrolling stalls.

### 修复 / Fixed

- 修复新建、删除歌单以及添加、移除、喜欢歌曲等操作可能因旧网页调用路径失效的问题，改用当前接口契约。
  Fixed playlist creation/deletion and song add/remove/like operations that could fail through obsolete web paths by using the current API contracts.
- 修复歌曲自然播放结束、VIP 连续跳过或后台网络请求卡住时，自动播放可能中断的问题。
  Fixed automatic playback stopping after natural completion, chained unavailable-track skips, or stalled background requests.
- 修复部分播放状态、封面与系统媒体控件在应用进入后台后不能及时同步的问题。
  Fixed several playback-state, artwork, and system-media synchronization issues while the app is backgrounded.

### 验证 / Verification

- Dart 静态分析通过，13 项 Flutter 自动化测试全部通过，Android Release APK 构建成功。
  Dart analysis passed, all 13 Flutter tests passed, and the Android release APK built successfully.

## [1.0.3] - 2026-07-13

### 优化 / Improved

- 重构长歌单歌曲与封面加载流程：首次准备 72 首，滑动到底后每批继续加载 36 首，兼顾完整内容与滚动性能。
  Reworked long-playlist song and artwork loading: 72 songs are prepared initially and 36 more are revealed per batch near the bottom.
- 保存每个歌单已经展开的歌曲数量；重启应用或切换封面显示后可恢复上次加载深度，清除缓存时才会重置。
  Persisted each playlist's revealed high-water mark across restarts and cover-display changes; clearing the cache intentionally resets it.
- 优化歌曲封面预加载、运行时缓存和重复请求合并，减少长歌单滚动时的重复下载与卡顿。
  Improved artwork preloading, runtime caching, and duplicate-request coalescing to reduce repeated downloads and scrolling stutter.
- 优化播放列表和当前歌曲状态恢复，重新进入应用后保留更完整的播放上下文。
  Improved queue and current-song restoration so more playback context survives app restarts.

### 修复 / Fixed

- 修复从每日推荐切换到用户歌单歌曲后，软件界面动态取色可能停留在上一首歌曲颜色的问题。
  Fixed dynamic color sometimes remaining on the previous song after switching from daily recommendations to a user playlist.
- 将根主题更新与歌单封面加载通知分离，避免高频加载事件反复重启主题过渡动画。
  Isolated root theme updates from artwork-loading notifications to prevent frequent events from repeatedly restarting theme transitions.
- 修复同一歌单取色请求被高频轮询重复取消和重建的问题。
  Fixed repeated cancellation and recreation of the same playlist color request during frequent playback polling.

### 验证 / Verification

- Flutter 静态分析通过，12 项自动化测试全部通过，并在 Android 模拟器验证推荐歌曲到用户歌单歌曲的动态取色切换。
  Flutter analysis passed, all 12 automated tests passed, and the recommendation-to-playlist dynamic-color transition was verified on an Android emulator.

## [1.0.0] - 2026-07-02

### 新增 / Added

- 使用 Flutter 构建的移动端优先 Android UI。
  Mobile-first Android UI built with Flutter.
- Kotlin 原生集成：媒体播放、系统媒体会话和桌面歌词悬浮窗。
  Native Kotlin integration for media playback, media session, and desktop lyrics overlay.
- 网易云音乐登录/会话流程。
  NetEase Cloud Music login/session flow.
- 首页推荐、歌单、搜索、播放控制和歌词页面。
  Home recommendations, playlist library, search, playback controls, and lyrics page.
- 桌面歌词设置，包括透明度、颜色、字号、锁定、多句模式和前台自动隐藏。
  Desktop lyrics settings including opacity, color, size, lock, multi-line mode, and foreground auto-hide.
- 动态取色、浅色/深色/跟随系统主题、缓存清理和播放音质偏好。
  Dynamic color, light/dark/system theme settings, cache clearing, and playback quality preference.
- 公开文档、界面展示、隐私说明、免责声明和 GPL-3.0-or-later 许可证。
  Public documentation, screenshots, privacy policy, disclaimer, and GPL-3.0-or-later license.

### 说明 / Notes

- EmoC 是第三方、免费、非官方项目。
  EmoC is third-party, free, and unofficial.
- 服务可用性取决于网易云音乐。
  Service availability depends on NetEase Cloud Music.
