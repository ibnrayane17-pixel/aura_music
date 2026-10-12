import 'dart:async';

import 'package:aura_music/app_scope.dart';
import 'package:aura_music/neu.dart';
import 'package:aura_music/notification_permission.dart';
import 'package:aura_music/pages.dart';
import 'package:aura_music/player_controller.dart';
import 'package:aura_music/settings.dart';
import 'package:aura_music/settings_page.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Media notification + lock screen controls.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.auramusic.app.channel.audio',
    androidNotificationChannelName: 'Aura Music playback',
    androidNotificationOngoing: true,
    notificationColor: const Color(0xFF8B5CF6),
    androidNotificationIcon: 'mipmap/ic_launcher',
  );

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final AppSettings settings = AppSettings(prefs);
  final PlaylistStore playlists = PlaylistStore(prefs);
  final PlayerController controller = PlayerController(
    prefs: prefs,
    settings: settings,
    playlists: playlists,
  );

  runApp(
    AuraMusicApp(
      settings: settings,
      playlists: playlists,
      controller: controller,
    ),
  );
}

class AuraMusicApp extends StatelessWidget {
  const AuraMusicApp({
    super.key,
    required this.settings,
    required this.playlists,
    required this.controller,
  });

  final AppSettings settings;
  final PlaylistStore playlists;
  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: settings,
      playlists: playlists,
      controller: controller,
      child: Builder(
        builder: (BuildContext scopeContext) {
          final AppSettings s = scopeContext.settings;
          return MaterialApp(
            title: 'Aura Music',
            debugShowCheckedModeBanner: false,
            theme: buildAuraTheme(s.accent, s.accentSoft),
            builder: (BuildContext appContext, Widget? child) {
              return Directionality(
                textDirection: s.isRtl ? TextDirection.rtl : TextDirection.ltr,
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const AppShell(),
          );
        },
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _navIndex = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final PlayerController c = context.controller;
    c.onMessage = (String key, [Map<String, String>? args]) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.tr(key, args: args))));
    };
    unawaited(_start(c));
  }

  /// 1) load the music library (asks for the audio permission),
  /// 2) then ask for the notification permission (Android 13+).
  Future<void> _start(PlayerController c) async {
    await c.init();
    if (!mounted) return;
    if (!await NotificationPermission.isEnabled()) {
      await NotificationPermission.request();
    }
  }

  /// Debug only: shows why the music notification may be missing.
  Future<void> _showNotificationCheck() async {
    final Map<String, dynamic> info = await NotificationPermission.info();
    if (!mounted) return;

    final List<dynamic> channels =
        (info['channels'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> active =
        (info['active'] as List<dynamic>?) ?? <dynamic>[];

    final String text = <String>[
      if (info['error'] != null) 'ERROR: ${info['error']}',
      'Phone: ${info['device']}',
      'Android: ${info['release']} (API ${info['sdk']})',
      'Notifications allowed: ${info['enabled']}',
      'Permission granted: ${info['permission']}',
      'Audio service running: ${info['serviceRunning']}',
      'Channels: ${channels.isEmpty ? 'none' : '\n  ${channels.join('\n  ')}'}',
      'Active notifications: ${active.isEmpty ? 'none' : '\n  ${active.join('\n  ')}'}',
    ].join('\n');

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Notification check'),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: <Widget>[
          TextButton(
            onPressed: () => unawaited(NotificationPermission.request()),
            child: const Text('Ask permission'),
          ),
          TextButton(
            onPressed: () => unawaited(NotificationPermission.openSettings()),
            child: const Text('Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NeuBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: _navIndex,
          children: const <Widget>[
            HomePage(),
            LibraryPage(),
            SettingsScreen(),
          ],
        ),
        floatingActionButton: kDebugMode
            ? FloatingActionButton.small(
                heroTag: 'notification_check',
                onPressed: _showNotificationCheck,
                child: const Icon(Icons.bug_report_outlined),
              )
            : null,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const MiniPlayer(),
            NeuBottomNav(
              currentIndex: _navIndex,
              onTap: (int i) => setState(() => _navIndex = i),
            ),
          ],
        ),
      ),
    );
  }
}