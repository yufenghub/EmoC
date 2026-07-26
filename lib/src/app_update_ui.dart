part of '../main.dart';

class AppUpdatePromptCoordinator extends StatefulWidget {
  const AppUpdatePromptCoordinator({required this.model, super.key});

  final AppModel model;

  @override
  State<AppUpdatePromptCoordinator> createState() =>
      _AppUpdatePromptCoordinatorState();
}

class _AppUpdatePromptCoordinatorState
    extends State<AppUpdatePromptCoordinator> {
  bool _dialogScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.model.updates.addListener(_handleUpdateChanged);
  }

  @override
  void didUpdateWidget(covariant AppUpdatePromptCoordinator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model) {
      oldWidget.model.updates.removeListener(_handleUpdateChanged);
      widget.model.updates.addListener(_handleUpdateChanged);
    }
  }

  void _handleUpdateChanged() {
    if (!mounted || _dialogScheduled) return;
    if (!widget.model.updates.startupPromptPending ||
        widget.model.loginGateVisible) {
      return;
    }
    _dialogScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final release = await widget.model.updates.consumeStartupPrompt();
      if (!mounted) return;
      if (release != null) {
        await showAppUpdateDialog(context, widget.model, release: release);
      }
      _dialogScheduled = false;
    });
  }

  @override
  void dispose() {
    widget.model.updates.removeListener(_handleUpdateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _handleUpdateChanged();
    return const SizedBox.shrink();
  }
}

Future<void> showAppUpdateDialog(
  BuildContext context,
  AppModel model, {
  AppReleaseInfo? release,
}) async {
  final update = model.updates;
  var target = release ?? update.latestRelease;
  if (target == null || !update.hasUpdate) {
    final available = await update.checkForUpdates();
    if (!context.mounted) return;
    target = update.latestRelease;
    if (!available || target == null) {
      await _showUpdateMessage(
        context,
        update.phase == AppUpdatePhase.error ? update.errorMessage : '当前已是最新版本',
      );
      return;
    }
  }
  if (update.hasLatestInstaller) {
    await _confirmAndInstallUpdate(context, model);
    return;
  }
  final shouldDownload = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    builder: (context) {
      final notes = target!.notes.trim().isEmpty
          ? '本次更新未提供更新说明。'
          : target.notes.trim();
      return AlertDialog(
        title: Text('发现新版本 ${target.version}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('当前版本：${update.currentVersionName}'),
                const SizedBox(height: 14),
                Text(
                  '更新说明',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(notes),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('稍后'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.download_outlined),
            label: const Text('立即更新'),
          ),
        ],
      );
    },
  );
  if (shouldDownload == true && context.mounted) {
    await downloadAndInstallUpdate(context, model);
  }
}

Future<void> downloadAndInstallUpdate(
  BuildContext context,
  AppModel model,
) async {
  final update = model.updates;
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope<void>(
        canPop: false,
        child: AlertDialog(
          title: const Text('正在下载更新'),
          content: AnimatedBuilder(
            animation: update,
            builder: (context, _) {
              final percent = (update.downloadProgress * 100).round();
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: update.totalBytes > 0
                        ? update.downloadProgress
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    update.totalBytes > 0
                        ? '$percent%  ${_formatUpdateBytes(update.downloadedBytes)} / ${_formatUpdateBytes(update.totalBytes)}'
                        : '正在连接 GitHub…',
                  ),
                  const SizedBox(height: 6),
                  const Text('下载完成后会校验应用包名与签名。'),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 80));
  final success = await update.downloadLatest();
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  if (!success) {
    await _showUpdateMessage(context, update.errorMessage);
    return;
  }
  await _confirmAndInstallUpdate(context, model);
}

Future<void> _confirmAndInstallUpdate(
  BuildContext context,
  AppModel model,
) async {
  final update = model.updates;
  final install = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('更新已下载'),
      content: Text(
        'EmoC ${update.downloadedVersion} 已通过本机校验。'
        '接下来将打开 Android 系统安装界面；如果取消，可以稍后在“关于 EmoC”的版本栏继续安装。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('稍后'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('安装'),
        ),
      ],
    ),
  );
  if (install != true || !context.mounted) return;
  final message = await update.installDownloaded();
  if (context.mounted) await _showUpdateMessage(context, message);
}

Future<void> _showUpdateMessage(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message.isEmpty ? '操作未完成，请稍后重试' : message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

String _formatUpdateBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
