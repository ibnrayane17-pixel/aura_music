import 'package:aura_music/player_controller.dart';
import 'package:aura_music/settings.dart';
import 'package:flutter/material.dart';

/// Makes settings, playlists and the player available to every screen,
/// and rebuilds them when the settings or playlists change.
class AppScope extends InheritedNotifier<Listenable> {
  AppScope({
    super.key,
    required this.settings,
    required this.playlists,
    this.controller,
    required super.child,
  }) : super(notifier: Listenable.merge(<Listenable>[settings, playlists]));

  final AppSettings settings;
  final PlaylistStore playlists;
  final PlayerController? controller;

  static AppScope of(BuildContext context) {
    final AppScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget.');
    return scope!;
  }
}

extension AppContext on BuildContext {
  AppSettings get settings => AppScope.of(this).settings;
  PlaylistStore get playlistStore => AppScope.of(this).playlists;
  PlayerController get controller => AppScope.of(this).controller!;
  Color get accent => settings.accent;
  Color get accentSoft => settings.accentSoft;

  String tr(String key, {Map<String, String>? args}) =>
      settings.tr(key, args: args);
}
