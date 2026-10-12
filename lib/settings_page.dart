import 'package:aura_music/app_scope.dart';
import 'package:aura_music/hidden_page.dart';
import 'package:aura_music/l10n.dart';
import 'package:aura_music/neu.dart';
import 'package:aura_music/pages.dart';
import 'package:aura_music/player_controller.dart';
import 'package:aura_music/settings.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

String formatListenTime(BuildContext context, int ms) {
  final int totalMinutes = ms ~/ 60000;
  final int hours = totalMinutes ~/ 60;
  final int minutes = totalMinutes % 60;
  if (hours > 0) {
    return context.tr(
      'time_hm',
      args: <String, String>{'h': '$hours', 'm': '$minutes'},
    );
  }
  return context.tr('time_m', args: <String, String>{'m': '$minutes'});
}

// ===========================================================================
// Settings
// ===========================================================================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<String> _colorKeys = <String>[
    'color_purple',
    'color_blue',
    'color_green',
    'color_orange',
    'color_pink',
  ];

  Widget _swatch(int index, {double size = 26}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[kAccents[index].soft, kAccents[index].main],
        ),
      ),
    );
  }

  Widget _group(BuildContext context, String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 18, 8, 10),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: context.accentSoft,
            ),
          ),
        ),
        for (final Widget tile in tiles)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: tile),
      ],
    );
  }

  String _shortLabel(BuildContext context, int seconds) => seconds == 0
      ? context.tr('hide_short_off')
      : context.tr('hide_short_n', args: <String, String>{'n': '$seconds'});

  String _sleepLabel(BuildContext context, int minutes) => minutes == 0
      ? context.tr('sleep_off')
      : context.tr('sleep_n', args: <String, String>{'n': '$minutes'});

  Future<void> _pickColor(BuildContext context) async {
    final AppSettings s = context.settings;
    final int? picked = await showNeuChoiceDialog<int>(
      context,
      title: context.tr('theme_color'),
      selected: s.accentIndex,
      choices: <NeuChoice<int>>[
        for (int i = 0; i < kAccents.length; i++)
          NeuChoice<int>(
            value: i,
            label: context.tr(_colorKeys[i]),
            leading: _swatch(i),
          ),
      ],
    );
    if (picked != null) await s.setAccent(picked);
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final AppSettings s = context.settings;
    final String? picked = await showNeuChoiceDialog<String>(
      context,
      title: context.tr('language'),
      selected: s.language,
      choices: <NeuChoice<String>>[
        for (final AppLanguage lang in kLanguages)
          NeuChoice<String>(value: lang.code, label: lang.nativeName),
      ],
    );
    if (picked != null) await s.setLanguage(picked);
  }

  Future<void> _pickSort(BuildContext context) async {
    final AppSettings s = context.settings;
    final int? picked = await showNeuChoiceDialog<int>(
      context,
      title: context.tr('sort_by'),
      selected: s.sortMode,
      choices: <NeuChoice<int>>[
        NeuChoice<int>(value: 0, label: context.tr('sort_recent')),
        NeuChoice<int>(value: 1, label: context.tr('sort_az')),
      ],
    );
    if (picked != null) await s.setSortMode(picked);
  }

  Future<void> _pickShort(BuildContext context) async {
    final AppSettings s = context.settings;
    final int? picked = await showNeuChoiceDialog<int>(
      context,
      title: context.tr('hide_short'),
      selected: s.minSeconds,
      choices: <NeuChoice<int>>[
        for (final int seconds in const <int>[0, 30, 60, 120])
          NeuChoice<int>(value: seconds, label: _shortLabel(context, seconds)),
      ],
    );
    if (picked != null) await s.setMinSeconds(picked);
  }

  Future<void> _pickSleep(BuildContext context) async {
    final PlayerController c = context.controller;
    final int? picked = await showNeuChoiceDialog<int>(
      context,
      title: context.tr('sleep_timer'),
      selected: c.sleepMinutes,
      choices: <NeuChoice<int>>[
        for (final int minutes in const <int>[0, 15, 30, 45, 60])
          NeuChoice<int>(value: minutes, label: _sleepLabel(context, minutes)),
      ],
    );
    if (picked != null) c.setSleepTimer(picked);
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings s = context.settings;
    final PlayerController c = context.controller;
    final String languageName = kLanguages
        .firstWhere(
          (AppLanguage l) => l.code == s.language,
          orElse: () => kLanguages.first,
        )
        .nativeName;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: buildAuraAppBar(title: context.tr('settings')),
      body: ListenableBuilder(
        listenable: c,
        builder: (BuildContext _, Widget? child) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: <Widget>[
              _group(context, context.tr('appearance'), <Widget>[
                NeuTile(
                  icon: Icons.palette_outlined,
                  title: context.tr('theme_color'),
                  value: context.tr(_colorKeys[s.accentIndex]),
                  onTap: () => _pickColor(context),
                ),
                NeuTile(
                  icon: Icons.language_rounded,
                  title: context.tr('language'),
                  value: languageName,
                  onTap: () => _pickLanguage(context),
                ),
              ]),
              _group(context, context.tr('playback'), <Widget>[
                NeuTile(
                  icon: Icons.sort_rounded,
                  title: context.tr('sort_by'),
                  value: s.sortMode == 0
                      ? context.tr('sort_recent')
                      : context.tr('sort_az'),
                  onTap: () => _pickSort(context),
                ),
                NeuTile(
                  icon: Icons.content_cut_rounded,
                  title: context.tr('hide_short'),
                  value: _shortLabel(context, s.minSeconds),
                  onTap: () => _pickShort(context),
                ),
                NeuTile(
                  icon: Icons.bedtime_outlined,
                  title: context.tr('sleep_timer'),
                  value: _sleepLabel(context, c.sleepMinutes),
                  onTap: () => _pickSleep(context),
                ),
              ]),
              _group(context, context.tr('library'), <Widget>[
                NeuTile(
                  icon: Icons.visibility_off_outlined,
                  title: context.tr('hidden_songs'),
                  value: context.tr(
                    'hidden_n',
                    args: <String, String>{'n': '${c.hiddenCount}'},
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          const HiddenSongsPage(),
                    ),
                  ),
                ),
              ]),
              _group(context, context.tr('insights'), <Widget>[
                NeuTile(
                  icon: Icons.insights_rounded,
                  title: context.tr('listening_stats'),
                  value: formatListenTime(context, c.listenedMs),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const StatsPage(),
                    ),
                  ),
                ),
              ]),
              _group(context, context.tr('about'), <Widget>[
                NeuTile(
                  icon: Icons.info_outline_rounded,
                  title: context.tr('about'),
                  value: '${context.tr('version')} 1.0.0',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'Aura Music',
                    applicationVersion: '1.0.0',
                    applicationIcon: const AuraLogo(size: 48),
                  ),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Listening statistics
// ===========================================================================
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  Future<void> _confirmReset(BuildContext context) async {
    final PlayerController c = context.controller;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('stats_reset_q')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.tr('stats_reset')),
          ),
        ],
      ),
    );
    if (confirmed == true) await c.resetStats();
  }

  @override
  Widget build(BuildContext context) {
    final PlayerController c = context.controller;

    return NeuBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: buildSubAppBar(context, title: context.tr('listening_stats')),
        body: ListenableBuilder(
          listenable: c,
          builder: (BuildContext _, Widget? child) {
            final List<MapEntry<SongModel, int>> top = c.topSongs(5);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: <Widget>[
                _StatCard(
                  icon: Icons.timer_outlined,
                  value: formatListenTime(context, c.listenedMs),
                  label: context.tr('stats_total_time'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _StatCard(
                        icon: Icons.play_circle_outline_rounded,
                        value: '${c.totalPlays}',
                        label: context.tr('stats_plays'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.library_music_outlined,
                        value: '${c.songs.length}',
                        label: context.tr('stats_library'),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 24, 8, 12),
                  child: Text(
                    context.tr('stats_top').toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: context.accentSoft,
                    ),
                  ),
                ),
                if (top.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      context.tr('stats_empty'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  )
                else
                  for (int i = 0; i < top.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: NeuBox(
                        radius: 18,
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: <Widget>[
                            SizedBox(
                              width: 28,
                              child: Text(
                                '${i + 1}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: context.accentSoft,
                                ),
                              ),
                            ),
                            ArtworkThumb(id: top[i].key.id, size: 44),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    top[i].key.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    context.artistOf(top[i].key),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                context.tr(
                                  'plays_n',
                                  args: <String, String>{
                                    'n': '${top[i].value}',
                                  },
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.accentSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: NeuPillButton(
                    icon: Icons.restart_alt_rounded,
                    label: context.tr('stats_reset'),
                    onTap: () => _confirmReset(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return NeuBox(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: context.accentSoft),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}