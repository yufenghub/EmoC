part of '../main.dart';

const equalizerPresets = <String, List<double>>{
  'flat': [0, 0, 0, 0, 0],
  'bass': [7, 5, 1, -1, -2],
  'vocal': [-2, -1, 3, 5, 2],
  'pop': [2, 3, 0, 2, 3],
  'rock': [5, 3, -2, 3, 5],
  'electronic': [5, 2, -1, 3, 5],
};

const equalizerPresetLabels = <String, String>{
  'flat': '原声',
  'bass': '低音',
  'vocal': '人声',
  'pop': '流行',
  'rock': '摇滚',
  'electronic': '电子',
  'custom': '自定义',
};

extension EqualizerPreferences on AppModel {
  Future<void> setEqualizerEnabled(bool enabled) async {
    equalizerEnabled = enabled;
    notifyListeners();
    await _saveEqualizer();
  }

  Future<void> setEqualizerPreset(String preset) async {
    if (!equalizerPresets.containsKey(preset)) return;
    equalizerPreset = preset;
    equalizerBands = List<double>.from(equalizerPresets[preset]!);
    notifyListeners();
    await _saveEqualizer();
  }

  Future<void> setEqualizerBand(int index, double level) async {
    if (index < 0 || index >= equalizerBands.length) return;
    equalizerBands = List<double>.from(equalizerBands)
      ..[index] = level.clamp(-12, 12).toDouble();
    equalizerPreset = 'custom';
    notifyListeners();
    await _saveEqualizer();
  }

  Future<void> _saveEqualizer() async {
    try {
      await NativeBridge.setString(
        'equalizerSettings',
        jsonEncode({
          'enabled': equalizerEnabled,
          'preset': equalizerPreset,
          'bands': equalizerBands,
        }),
      );
      await NativeBridge.setEqualizer(equalizerEnabled, equalizerBands);
    } on PlatformException catch (error) {
      _showNotice(
        error.code == 'EQUALIZER_UNAVAILABLE' ? '当前设备不支持均衡器' : '均衡器设置失败',
      );
    } on MissingPluginException {
      // Flutter widget tests do not have the Android audio engine.
    }
  }
}

class EqualizerPage extends StatefulWidget {
  const EqualizerPage({required this.model, super.key});

  final AppModel model;

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage> {
  late List<double> _draft;
  static const frequencies = ['60 Hz', '230 Hz', '910 Hz', '3.6 kHz', '14 kHz'];

  @override
  void initState() {
    super.initState();
    _draft = List<double>.from(widget.model.equalizerBands);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.model,
    builder: (context, _) {
      final model = widget.model;
      final theme = Theme.of(context);
      return Scaffold(
        backgroundColor: model.visualStyle == 'liquid'
            ? Colors.transparent
            : theme.colorScheme.surface,
        appBar: AppBar(title: const Text('自定义均衡器')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            SettingsTile(
              icon: Icons.equalizer,
              title: '启用均衡器',
              trailing: Switch(
                value: model.equalizerEnabled,
                onChanged: (value) =>
                    unawaited(model.setEqualizerEnabled(value)),
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '预设',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      key: ValueKey(model.equalizerPreset),
                      initialValue: model.equalizerPreset,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: equalizerPresetLabels.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: !model.equalizerEnabled
                          ? null
                          : (value) {
                              if (value == null || value == 'custom') return;
                              setState(
                                () => _draft = List<double>.from(
                                  equalizerPresets[value]!,
                                ),
                              );
                              unawaited(model.setEqualizerPreset(value));
                            },
                    ),
                    const SizedBox(height: 18),
                    for (var index = 0; index < frequencies.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 64,
                              child: Text(
                                frequencies[index],
                                style: theme.textTheme.labelMedium,
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: _draft[index],
                                min: -12,
                                max: 12,
                                divisions: 48,
                                onChanged: !model.equalizerEnabled
                                    ? null
                                    : (value) =>
                                          setState(() => _draft[index] = value),
                                onChangeEnd: !model.equalizerEnabled
                                    ? null
                                    : (value) => unawaited(
                                        model.setEqualizerBand(index, value),
                                      ),
                              ),
                            ),
                            SizedBox(
                              width: 47,
                              child: Text(
                                '${_draft[index] >= 0 ? '+' : ''}${_draft[index].toStringAsFixed(1)}',
                                textAlign: TextAlign.end,
                                style: theme.textTheme.labelMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
