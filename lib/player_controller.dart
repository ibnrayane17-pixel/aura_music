import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:aura_music/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kLastSongKey = 'last_song_id';
const String _kListenMsKey = 'listen_ms';
const String _kPlayCountsKey = 'play_counts';
const String _kHiddenKey = 'hidden_songs';

/// Returns null when the tag is empty or the placeholder `<unknown>`.
String? cleanTag(String? value) {
  if (value == null) return null;
  final String text = value.trim();
  if (text.isEmpty || text == '<unknown>') return null;
  return text;
}

class PlayerController extends ChangeNotifier {
  PlayerController({
    required this.prefs,
    required this.settings,
    required this.playlists,
  }) {
    final int loopIndex = (prefs.getInt('loop') ?? LoopMode.all.index)
        .clamp(0, LoopMode.values.length - 1)
        .toInt();
    _loop = LoopMode.values[loopIndex];
    _shuffle = prefs.getBool('shuffle') ?? false;
    _appliedSort = settings.sortMode;
    _appliedMinSeconds = settings.minSeconds;

    _listenedMs = prefs.getInt(_kListenMsKey) ?? 0;
    _loadPlayCounts();
    _loadHidden();

    settings.addListener(_onSettingsChanged);
    _indexSub = player.currentIndexStream.listen(_onIndex);
    _eventSub = player.playbackEventStream.listen(
      (PlaybackEvent event) {},
      onError: (Object error, StackTrace stackTrace) {
        onMessage?.call('playback_error');
      },
    );
    _stateSub = player.playerStateStream.listen(_onPlayerState);
    _positionSub = player.positionStream.listen(_onPosition);
  }

  final SharedPreferences prefs;
  final AppSettings settings;
  final PlaylistStore playlists;

  static const MethodChannel _fileChannel = MethodChannel('com.auramusic/files');

  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer player = AudioPlayer();

  /// The song currently loaded in the player (null if none).
  final ValueNotifier<SongModel?> currentSong = ValueNotifier<SongModel?>(null);

  /// Set by the UI to show short messages (key + optional values).
  void Function(String key, [Map<String, String>? args])? onMessage;

  late final StreamSubscription<int?> _indexSub;
  late final StreamSubscription<PlaybackEvent> _eventSub;
  late final StreamSubscription<PlayerState> _stateSub;
  late final StreamSubscription<Duration> _positionSub;

  List<SongModel> _raw = <SongModel>[];
  Map<int, SongModel> _byId = <int, SongModel>{};
  List<SongModel> _songs = <SongModel>[];
  List<SongModel> _queue = <SongModel>[];
  String _queueSource = '';

  late LoopMode _loop;
  late bool _shuffle;
  int _appliedSort = 0;
  int _appliedMinSeconds = 0;

  Timer? _sleepTimer;
  int sleepMinutes = 0;

  bool loading = true;
  bool permissionGranted = false;
  String? errorKey;

  // --- hidden songs ----------------------------------------------------------
  Set<int> _hidden = <int>{};

  // --- listening statistics -------------------------------------------------
  int _listenedMs = 0;
  DateTime? _listenStart;
  bool _countedCurrent = false;
  Map<int, int> _playCounts = <int, int>{};

  // --- artwork for the notification / lock screen ----------------------------
  final Directory _artDir =
      Directory('${Directory.systemTemp.path}/aura_art');
  Uint8List? _logoBytes;
  int _prefetchToken = 0;

  List<SongModel> get songs => _songs;
  LoopMode get loopMode => _loop;
  bool get shuffle => _shuffle;

  SongModel? songById(int id) => _byId[id];

  String artistLabel(SongModel song) =>
      cleanTag(song.artist) ?? settings.tr('unknown_artist');

  List<SongModel> songsOf(Playlist playlist) => <SongModel>[
        for (final int id in playlist.songIds)
          if (_byId[id] != null) _byId[id]!,
      ];

  // -------------------------------------------------------------------------
  // Start-up and library loading
  // -------------------------------------------------------------------------
  Future<void> init() async {
    try {
      final AudioSession session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {
      // Not critical: just_audio falls back to default session handling.
    }
    await checkPermissionAndLoad();
  }

  /// Android 13+ keeps notifications OFF until the app asks for them.
  /// Without this permission the music notification never appears.
  Future<void> _requestNotificationPermission() async {
    try {
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {
      // Not critical: the user can still enable notifications in Settings.
    }
  }

  Future<void> checkPermissionAndLoad() async {
    loading = true;
    errorKey = null;
    notifyListeners();
    try {
      bool granted = await _audioQuery.permissionsStatus();
      if (!granted) {
        granted = await _audioQuery.permissionsRequest();
      }
      // Ask for notifications right away (one dialog after the other),
      // BEFORE the slow library loading starts.
      await _requestNotificationPermission();

      if (!granted) {
        permissionGranted = false;
        loading = false;
        notifyListeners();
        return;
      }
      permissionGranted = true;

      final List<SongModel> result = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      _raw = result
          .where((SongModel s) => s.uri != null && (s.duration ?? 1) > 0)
          .toList();
      _byId = <int, SongModel>{for (final SongModel s in _raw) s.id: s};

      _computeLibrary();
      loading = false;
      notifyListeners();

      await _syncLibraryQueue(initial: _queueSource.isEmpty);
    } catch (_) {
      errorKey = 'error_read';
      loading = false;
      notifyListeners();
    }
  }

  /// Applies the "hide short audio" filter, the hidden songs and the sort.
  void _computeLibrary() {
    final int minMs = settings.minSeconds * 1000;
    final List<SongModel> list = _raw
        .where((SongModel s) =>
            (s.duration ?? 0) >= minMs && !_hidden.contains(s.id))
        .toList();

    if (settings.sortMode == 1) {
      list.sort((SongModel a, SongModel b) =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else {
      list.sort((SongModel a, SongModel b) =>
          (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
    }

    _songs = list;
    _appliedSort = settings.sortMode;
    _appliedMinSeconds = settings.minSeconds;
  }

  void _onSettingsChanged() {
    if (settings.sortMode != _appliedSort ||
        settings.minSeconds != _appliedMinSeconds) {
      _computeLibrary();
      notifyListeners();
      unawaited(_syncLibraryQueue());
    }
  }

  /// Keeps the player queue equal to the library list
  /// (only when the library is what is currently loaded).
  Future<void> _syncLibraryQueue({bool initial = false}) async {
    if (!initial && _queueSource != 'library') return;

    if (_songs.isEmpty) {
      if (_queueSource == 'library' || initial) {
        await _loadQueue(<SongModel>[], 0, source: 'library');
      }
      return;
    }

    int index = -1;
    Duration position = Duration.zero;
    bool play = false;

    final SongModel? current = currentSong.value;
    if (!initial && current != null) {
      index = _songs.indexWhere((SongModel s) => s.id == current.id);
      if (index >= 0) {
        position = player.position;
        play = player.playing;
      }
    }
    if (index < 0) {
      if (initial) {
        final int? lastId = prefs.getInt(kLastSongKey);
        index = _songs.indexWhere((SongModel s) => s.id == lastId);
      }
      if (index < 0) index = 0;
    }

    await _loadQueue(_songs, index,
        source: 'library', position: position, play: play);
  }

  // -------------------------------------------------------------------------
  // Hide / unhide songs
  // -------------------------------------------------------------------------
  /// Hidden songs that still exist on the phone, sorted by title.
  List<SongModel> get hiddenSongs {
    final List<SongModel> list = <SongModel>[
      for (final int id in _hidden)
        if (_byId[id] != null) _byId[id]!,
    ];
    list.sort((SongModel a, SongModel b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }

  int get hiddenCount => hiddenSongs.length;

  bool isHidden(int id) => _hidden.contains(id);

  void _loadHidden() {
    final String? raw = prefs.getString(_kHiddenKey);
    if (raw == null) return;
    try {
      _hidden = (jsonDecode(raw) as List<dynamic>)
          .map((dynamic e) => e as int)
          .toSet();
    } catch (_) {
      _hidden = <int>{};
    }
  }

  Future<void> _saveHidden() =>
      prefs.setString(_kHiddenKey, jsonEncode(_hidden.toList()));

  Future<void> hideSongs(Iterable<int> ids) async {
    _hidden.addAll(ids);
    _computeLibrary();
    notifyListeners();
    unawaited(_syncLibraryQueue());
    await _saveHidden();
  }

  Future<void> unhideSongs(Iterable<int> ids) async {
    _hidden.removeAll(ids);
    _computeLibrary();
    notifyListeners();
    unawaited(_syncLibraryQueue());
    await _saveHidden();
  }

  Future<void> unhideAll() => unhideSongs(_hidden.toList());

  // -------------------------------------------------------------------------
  // Delete songs from the phone
  // -------------------------------------------------------------------------
  /// Asks Android to delete the files (the system shows a confirmation on
  /// Android 11+). Returns true when the files were deleted.
  Future<bool> deleteSongs(List<SongModel> targets) async {
    if (targets.isEmpty) return false;
    final Set<int> ids = <int>{for (final SongModel s in targets) s.id};

    // Do not keep a file open while Android deletes it.
    final SongModel? current = currentSong.value;
    if (current != null && ids.contains(current.id) && player.playing) {
      await player.pause();
    }

    bool deleted = false;
    try {
      deleted = await _fileChannel.invokeMethod<bool>(
            'deleteAudio',
            <String, dynamic>{'ids': ids.toList()},
          ) ??
          false;
    } on PlatformException {
      deleted = false;
    } on MissingPluginException {
      deleted = false;
    }
    if (!deleted) return false;

    // 1) the player queue, 2) every list the app keeps about these songs.
    await _dropFromQueue(ids);

    _raw.removeWhere((SongModel s) => ids.contains(s.id));
    _byId = <int, SongModel>{for (final SongModel s in _raw) s.id: s};

    _hidden.removeAll(ids);
    await _saveHidden();

    _playCounts.removeWhere((int id, int count) => ids.contains(id));
    await _savePlayCounts();
    playlists.removeSongsEverywhere(ids);

    for (final int id in ids) {
      try {
        final File art = File(_artPath(id));
        if (art.existsSync()) art.deleteSync();
      } catch (_) {}
    }

    _computeLibrary();
    notifyListeners();
    return true;
  }

  /// Rebuilds the player queue without the given songs.
  Future<void> _dropFromQueue(Set<int> ids) async {
    if (!_queue.any((SongModel s) => ids.contains(s.id))) return;

    final SongModel? current = currentSong.value;
    final bool currentGone = current != null && ids.contains(current.id);
    final List<SongModel> remaining =
        _queue.where((SongModel s) => !ids.contains(s.id)).toList();

    if (remaining.isEmpty) {
      await _loadQueue(<SongModel>[], 0, source: _queueSource);
      return;
    }

    int index = 0;
    Duration position = Duration.zero;
    bool play = false;
    if (!currentGone && current != null) {
      final int found =
          remaining.indexWhere((SongModel s) => s.id == current.id);
      if (found >= 0) {
        index = found;
        position = player.position;
        play = player.playing;
      }
    }
    await _loadQueue(remaining, index,
        source: _queueSource, position: position, play: play);
  }

  // -------------------------------------------------------------------------
  // Artwork files (used by the notification and the lock screen)
  // -------------------------------------------------------------------------
  String _artPath(int id) => '${_artDir.path}/$id.jpg';

  Future<Uint8List?> _fallbackLogo() async {
    if (_logoBytes != null) return _logoBytes;
    try {
      final ByteData data = await rootBundle.load('assets/app_logo.png');
      _logoBytes = data.buffer.asUint8List();
    } catch (_) {
      // No logo asset: the notification simply has no picture.
    }
    return _logoBytes;
  }

  /// Saves the song artwork as a small file. If the song has no artwork,
  /// the app logo is saved instead, so the notification is never empty.
  Future<void> _ensureArt(SongModel song) async {
    try {
      final File file = File(_artPath(song.id));
      if (file.existsSync() && file.lengthSync() > 0) return;

      Uint8List? bytes = await _audioQuery.queryArtwork(
        song.id,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 512,
        quality: 90,
      );
      if (bytes == null || bytes.isEmpty) {
        bytes = await _fallbackLogo();
      }
      if (bytes == null || bytes.isEmpty) return;

      if (!_artDir.existsSync()) _artDir.createSync(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      // Artwork is optional: playback must never fail because of it.
    }
  }

  /// Prepares the artwork of the current song and of the ones around it.
  Future<void> _prefetchAround(int index) async {
    final int token = ++_prefetchToken;
    if (index < 0 || index >= _queue.length) return;

    final Set<int> targets = <int>{index};
    final int? next = player.nextIndex;
    final int? previous = player.previousIndex;
    if (next != null) targets.add(next);
    if (previous != null) targets.add(previous);
    for (int i = 1; i <= 8; i++) {
      targets.add(index + i);
    }

    for (final int target in targets) {
      if (token != _prefetchToken) return;
      if (target < 0 || target >= _queue.length) continue;
      await _ensureArt(_queue[target]);
    }
  }

  // -------------------------------------------------------------------------
  // Queue and playback
  // -------------------------------------------------------------------------
  MediaItem _mediaItemOf(SongModel s) => MediaItem(
        id: s.id.toString(),
        title: s.title,
        artist: artistLabel(s),
        album: cleanTag(s.album),
        duration:
            s.duration == null ? null : Duration(milliseconds: s.duration!),
        artUri: Uri.file(_artPath(s.id)),
      );

  Future<void> _loadQueue(
    List<SongModel> list,
    int index, {
    required String source,
    Duration position = Duration.zero,
    bool play = false,
  }) async {
    _queue = list;
    _queueSource = source;

    if (list.isEmpty) {
      currentSong.value = null;
      try {
        await player.stop();
      } catch (_) {}
      return;
    }

    currentSong.value = list[index];
    try {
      await _ensureArt(list[index]);
      if (!play) await player.pause();
      final List<AudioSource> sources = list
          .map(
            (SongModel s) => AudioSource.uri(
              Uri.parse(s.uri!),
              tag: _mediaItemOf(s),
            ),
          )
          .toList();
      await player.setAudioSources(
        sources,
        initialIndex: index,
        initialPosition: position,
      );
      await player.setLoopMode(_loop);
      await player.setShuffleModeEnabled(_shuffle);
      if (play) unawaited(player.play());
    } catch (_) {
      onMessage?.call('queue_error');
    }
  }

  void _onIndex(int? index) {
    if (index == null || index < 0 || index >= _queue.length) return;
    final SongModel song = _queue[index];
    if (currentSong.value?.id != song.id) {
      currentSong.value = song;
    }
    prefs.setInt(kLastSongKey, song.id);
    _countedCurrent = false;
    _flushListening(keepRunning: true);
    unawaited(_prefetchAround(index));
  }

  bool _sameIds(List<SongModel> a, List<SongModel> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  /// Plays [list] starting at [index]. [source] names where the list comes
  /// from (`library`, `playlist:<id>`, `artist:<name>`...).
  Future<void> playFrom(
    List<SongModel> list,
    int index, {
    required String source,
  }) async {
    if (list.isEmpty || index < 0 || index >= list.length) return;
    final bool sameQueue = source == _queueSource && _sameIds(list, _queue);
    try {
      if (sameQueue) {
        if (currentSong.value?.id == list[index].id) {
          if (!player.playing) unawaited(player.play());
          return;
        }
        await _ensureArt(list[index]);
        await player.seek(Duration.zero, index: index);
        unawaited(player.play());
      } else {
        await _loadQueue(list, index, source: source, play: true);
      }
    } catch (_) {
      onMessage?.call('cannot_play');
    }
  }

  Future<void> playPlaylist(Playlist playlist, {int start = 0}) =>
      playFrom(songsOf(playlist), start, source: 'playlist:${playlist.id}');

  Future<void> togglePlay() async {
    if (player.playing) {
      await player.pause();
    } else {
      unawaited(player.play());
    }
  }

  Future<void> cycleLoop() async {
    if (_loop == LoopMode.all) {
      _loop = LoopMode.one;
    } else if (_loop == LoopMode.one) {
      _loop = LoopMode.off;
    } else {
      _loop = LoopMode.all;
    }
    notifyListeners();
    await player.setLoopMode(_loop);
    await prefs.setInt('loop', _loop.index);
  }

  Future<void> toggleShuffle() async {
    _shuffle = !_shuffle;
    notifyListeners();
    await player.setShuffleModeEnabled(_shuffle);
    if (_shuffle) await player.shuffle();
    await prefs.setBool('shuffle', _shuffle);
  }

  // -------------------------------------------------------------------------
  // Sleep timer
  // -------------------------------------------------------------------------
  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepMinutes = minutes;
    if (minutes > 0) {
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        player.pause();
        sleepMinutes = 0;
        _sleepTimer = null;
        notifyListeners();
        onMessage?.call('sleep_fired');
      });
      onMessage?.call('sleep_started', <String, String>{'n': '$minutes'});
    }
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Listening statistics
  // -------------------------------------------------------------------------
  /// Total listening time in milliseconds (includes the current session).
  int get listenedMs {
    final DateTime? start = _listenStart;
    return _listenedMs +
        (start == null ? 0 : DateTime.now().difference(start).inMilliseconds);
  }

  int get totalPlays =>
      _playCounts.values.fold(0, (int sum, int count) => sum + count);

  /// The most played songs (only songs that still exist on the phone).
  List<MapEntry<SongModel, int>> topSongs([int limit = 5]) {
    final List<MapEntry<int, int>> entries = _playCounts.entries.toList()
      ..sort((MapEntry<int, int> a, MapEntry<int, int> b) =>
          b.value.compareTo(a.value));
    final List<MapEntry<SongModel, int>> result = <MapEntry<SongModel, int>>[];
    for (final MapEntry<int, int> entry in entries) {
      final SongModel? song = _byId[entry.key];
      if (song != null) {
        result.add(MapEntry<SongModel, int>(song, entry.value));
      }
      if (result.length >= limit) break;
    }
    return result;
  }

  Future<void> resetStats() async {
    _playCounts = <int, int>{};
    _listenedMs = 0;
    _listenStart = player.playing ? DateTime.now() : null;
    await prefs.remove(_kPlayCountsKey);
    await prefs.remove(_kListenMsKey);
    notifyListeners();
  }

  void _loadPlayCounts() {
    final String? raw = prefs.getString(_kPlayCountsKey);
    if (raw == null) return;
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;
      _playCounts = <int, int>{
        for (final MapEntry<String, dynamic> e in decoded.entries)
          int.parse(e.key): e.value as int,
      };
    } catch (_) {
      _playCounts = <int, int>{};
    }
  }

  Future<void> _savePlayCounts() => prefs.setString(
        _kPlayCountsKey,
        jsonEncode(<String, int>{
          for (final MapEntry<int, int> e in _playCounts.entries)
            e.key.toString(): e.value,
        }),
      );

  void _recordPlay(int songId) {
    _playCounts[songId] = (_playCounts[songId] ?? 0) + 1;
    _savePlayCounts();
    notifyListeners();
  }

  void _flushListening({bool keepRunning = false}) {
    final DateTime? start = _listenStart;
    if (start == null) return;
    _listenedMs += DateTime.now().difference(start).inMilliseconds;
    _listenStart = keepRunning ? DateTime.now() : null;
    prefs.setInt(_kListenMsKey, _listenedMs);
    notifyListeners();
  }

  void _onPlayerState(PlayerState state) {
    if (state.playing) {
      _listenStart ??= DateTime.now();
    } else {
      _flushListening();
    }
  }

  /// A song counts as "played" after 20 seconds (or half of a short clip).
  void _onPosition(Duration position) {
    final SongModel? song = currentSong.value;
    if (song == null || !player.playing) return;

    if (position < const Duration(seconds: 3)) {
      _countedCurrent = false;
      return;
    }
    final int durationMs = song.duration ?? 0;
    final Duration threshold = durationMs > 0 && durationMs < 40000
        ? Duration(milliseconds: durationMs ~/ 2)
        : const Duration(seconds: 20);
    if (!_countedCurrent && position >= threshold) {
      _countedCurrent = true;
      _recordPlay(song.id);
    }
  }

  @override
  void dispose() {
    settings.removeListener(_onSettingsChanged);
    _sleepTimer?.cancel();
    _indexSub.cancel();
    _eventSub.cancel();
    _stateSub.cancel();
    _positionSub.cancel();
    player.dispose();
    super.dispose();
  }
}