import 'dart:convert';

import 'package:aura_music/l10n.dart';
import 'package:aura_music/l10n_extra.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Theme colours (5 options)
// ---------------------------------------------------------------------------
class AccentOption {
  const AccentOption(this.main, this.soft);

  final Color main;
  final Color soft;
}

const List<AccentOption> kAccents = <AccentOption>[
  AccentOption(Color(0xFF8B5CF6), Color(0xFFB794FF)), // purple
  AccentOption(Color(0xFF3B82F6), Color(0xFF93C5FD)), // blue
  AccentOption(Color(0xFF10B981), Color(0xFF6EE7B7)), // green
  AccentOption(Color(0xFFF59E0B), Color(0xFFFCD34D)), // orange
  AccentOption(Color(0xFFEC4899), Color(0xFFF9A8D4)), // pink
];

// ---------------------------------------------------------------------------
// App settings (saved on the phone)
// ---------------------------------------------------------------------------
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs) {
    _accentIndex = (_prefs.getInt('accent') ?? 0)
        .clamp(0, kAccents.length - 1)
        .toInt();
    _language = _prefs.getString('language') ?? 'en';
    _sortMode = _prefs.getInt('sort') ?? 0;
    _minSeconds = _prefs.getInt('min_seconds') ?? 0;
  }

  final SharedPreferences _prefs;

  int _accentIndex = 0;
  String _language = 'en';
  int _sortMode = 0; // 0 = recently added, 1 = A-Z
  int _minSeconds = 0;

  int get accentIndex => _accentIndex;
  Color get accent => kAccents[_accentIndex].main;
  Color get accentSoft => kAccents[_accentIndex].soft;
  String get language => _language;
  int get sortMode => _sortMode;
  int get minSeconds => _minSeconds;

  bool get isRtl => kLanguages
      .firstWhere(
        (AppLanguage l) => l.code == _language,
        orElse: () => kLanguages.first,
      )
      .rtl;

  String tr(String key, {Map<String, String>? args}) =>
      translateAll(_language, key, args: args);

  Future<void> setAccent(int index) async {
    final int safe = index.clamp(0, kAccents.length - 1).toInt();
    if (safe == _accentIndex) return;
    _accentIndex = safe;
    notifyListeners();
    await _prefs.setInt('accent', safe);
  }

  Future<void> setLanguage(String code) async {
    if (code == _language) return;
    _language = code;
    notifyListeners();
    await _prefs.setString('language', code);
  }

  Future<void> setSortMode(int mode) async {
    if (mode == _sortMode) return;
    _sortMode = mode;
    notifyListeners();
    await _prefs.setInt('sort', mode);
  }

  Future<void> setMinSeconds(int seconds) async {
    if (seconds == _minSeconds) return;
    _minSeconds = seconds;
    notifyListeners();
    await _prefs.setInt('min_seconds', seconds);
  }
}

// ---------------------------------------------------------------------------
// Playlists (saved on the phone as JSON)
// ---------------------------------------------------------------------------
class Playlist {
  Playlist({required this.id, required this.name, List<int>? songIds})
      : songIds = songIds ?? <int>[];

  final String id;
  String name;
  final List<int> songIds;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'songs': songIds,
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        songIds: (json['songs'] as List<dynamic>)
            .map((dynamic e) => e as int)
            .toList(),
      );
}

class PlaylistStore extends ChangeNotifier {
  PlaylistStore(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;
  final List<Playlist> _items = <Playlist>[];

  List<Playlist> get items => List<Playlist>.unmodifiable(_items);

  Playlist? byId(String id) {
    for (final Playlist p in _items) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _load() {
    final String? raw = _prefs.getString('playlists');
    if (raw == null) return;
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      _items
        ..clear()
        ..addAll(
          decoded.map(
            (dynamic e) => Playlist.fromJson(e as Map<String, dynamic>),
          ),
        );
    } catch (_) {
      _items.clear();
    }
  }

  Future<void> _save() => _prefs.setString(
        'playlists',
        jsonEncode(_items.map((Playlist p) => p.toJson()).toList()),
      );

  void _changed() {
    notifyListeners();
    _save();
  }

  Playlist create(String name) {
    final Playlist p = Playlist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
    );
    _items.add(p);
    _changed();
    return p;
  }

  void rename(String id, String name) {
    final Playlist? p = byId(id);
    if (p == null) return;
    p.name = name.trim();
    _changed();
  }

  void delete(String id) {
    _items.removeWhere((Playlist p) => p.id == id);
    _changed();
  }

  void addSongs(String id, Iterable<int> songIds) {
    final Playlist? p = byId(id);
    if (p == null) return;
    for (final int songId in songIds) {
      if (!p.songIds.contains(songId)) p.songIds.add(songId);
    }
    _changed();
  }

  void removeSong(String id, int songId) {
    final Playlist? p = byId(id);
    if (p == null) return;
    p.songIds.remove(songId);
    _changed();
  }

  /// Removes the given songs from every playlist (used after a deletion).
  void removeSongsEverywhere(Iterable<int> songIds) {
    final Set<int> toRemove = songIds.toSet();
    bool changed = false;
    for (final Playlist p in _items) {
      final int before = p.songIds.length;
      p.songIds.removeWhere(toRemove.contains);
      if (p.songIds.length != before) changed = true;
    }
    if (changed) _changed();
  }
}
