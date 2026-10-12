import 'dart:async';
import 'dart:math' as math;

import 'package:aura_music/app_scope.dart';
import 'package:aura_music/neu.dart';
import 'package:aura_music/player_controller.dart';
import 'package:aura_music/settings.dart';
import 'package:aura_music/song_actions.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';

// ===========================================================================
// Helpers
// ===========================================================================
String formatDuration(Duration d) {
  final int total = d.inSeconds;
  final int h = total ~/ 3600;
  final int m = (total % 3600) ~/ 60;
  final String s = (total % 60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
  return '$m:$s';
}

String formatMs(int? ms) {
  if (ms == null || ms <= 0) return '--:--';
  return formatDuration(Duration(milliseconds: ms));
}

extension SongLabels on BuildContext {
  String artistOf(SongModel song) =>
      cleanTag(song.artist) ?? tr('unknown_artist');
  String albumOf(SongModel song) => cleanTag(song.album) ?? tr('unknown_album');
}

String songsCountLabel(BuildContext context, int n) => n == 1
    ? context.tr('one_song')
    : context.tr('n_songs', args: <String, String>{'n': '$n'});

/// Opens the full-screen "now playing" page (slides up from the bottom).
void openNowPlaying(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (BuildContext c, Animation<double> a, Animation<double> s) =>
          const NowPlayingPage(),
      transitionsBuilder: (
        BuildContext c,
        Animation<double> animation,
        Animation<double> secondary,
        Widget child,
      ) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
    ),
  );
}

/// Asks for a playlist name. Returns null if cancelled.
Future<String?> askPlaylistName(BuildContext context, {String initial = ''}) {
  final TextEditingController textController =
      TextEditingController(text: initial);
  final bool isNew = initial.isEmpty;
  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(dialogContext.tr(isNew ? 'new_playlist' : 'rename')),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(
            hintText: dialogContext.tr('playlist_name'),
          ),
          onSubmitted: (String value) =>
              Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.tr('cancel')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(textController.text.trim()),
            child: Text(dialogContext.tr(isNew ? 'create' : 'save')),
          ),
        ],
      );
    },
  );
}

// ===========================================================================
// Artwork + song card
// ===========================================================================
class ArtworkThumb extends StatelessWidget {
  const ArtworkThumb({
    super.key,
    required this.id,
    this.size = 48,
    this.radius = 11,
    this.highRes = false,
  });

  final int id;
  final double size;
  final double radius;
  final bool highRes;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: QueryArtworkWidget(
        id: id,
        type: ArtworkType.AUDIO,
        size: highRes ? 1000 : 200,
        quality: highRes ? 100 : 50,
        artworkWidth: size,
        artworkHeight: size,
        artworkFit: BoxFit.cover,
        keepOldArtwork: true,
        artworkBorder: BorderRadius.circular(radius),
        nullArtworkWidget: Container(
          decoration: BoxDecoration(
            color: kSurfaceDark,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Icon(
            Icons.music_note_rounded,
            color: context.accentSoft.withValues(alpha: 0.8),
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}

class SongCard extends StatelessWidget {
  const SongCard({
    super.key,
    required this.song,
    required this.selected,
    required this.player,
    required this.onTap,
    this.onRemove,
  });

  final SongModel song;
  final bool selected;
  final AudioPlayer player;
  final VoidCallback onTap;

  /// When not null, the menu shows "Remove from playlist".
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: NeuBox(
        radius: 20,
        glow: selected,
        padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 4, 10),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 54,
              height: 54,
              child: NeuBox(
                inset: true,
                radius: 14,
                padding: const EdgeInsets.all(3),
                child: ArtworkThumb(id: song.id),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? context.accentSoft : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.artistOf(song),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),
            if (selected)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: StreamBuilder<bool>(
                  stream: player.playingStream,
                  initialData: player.playing,
                  builder:
                      (BuildContext context, AsyncSnapshot<bool> snapshot) {
                    return EqualizerIcon(animate: snapshot.data ?? false);
                  },
                ),
              ),
            Text(
              formatMs(song.duration),
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
            _SongMenu(song: song, onPlay: onTap, onRemove: onRemove),
          ],
        ),
      ),
    );
  }
}

class _SongMenu extends StatelessWidget {
  const _SongMenu({required this.song, required this.onPlay, this.onRemove});

  final SongModel song;
  final VoidCallback onPlay;
  final VoidCallback? onRemove;

  void _showInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(song.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: Text(
          '${dialogContext.tr('artist')}: ${dialogContext.artistOf(song)}\n'
          '${dialogContext.tr('album')}: ${dialogContext.albumOf(song)}\n'
          '${dialogContext.tr('duration')}: ${formatMs(song.duration)}\n\n'
          '${song.data}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.tr('close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      iconSize: 20,
      icon: const Icon(Icons.more_vert, color: Colors.white54),
      onSelected: (String value) {
        switch (value) {
          case 'play':
            onPlay();
          case 'add':
            showAddToPlaylistSheet(context, song);
          case 'info':
            _showInfo(context);
          case 'remove':
            onRemove?.call();
          case 'hide':
            hideSongWithUndo(context, song);
          case 'delete':
            confirmAndDeleteSong(context, song);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: 'play', child: Text(context.tr('play'))),
        PopupMenuItem<String>(
          value: 'add',
          child: Text(context.tr('add_to_playlist')),
        ),
        if (onRemove != null)
          PopupMenuItem<String>(
            value: 'remove',
            child: Text(context.tr('remove')),
          ),
        PopupMenuItem<String>(
          value: 'info',
          child: Text(context.tr('details')),
        ),
        PopupMenuItem<String>(
          value: 'hide',
          child: Text(context.tr('hide_song')),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(
            context.tr('delete'),
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    );
  }
}

class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.title,
    required this.count,
    required this.artworkId,
    required this.onTap,
  });

  final String title;
  final int count;
  final int artworkId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: NeuBox(
        radius: 20,
        padding: const EdgeInsets.all(10),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 54,
              height: 54,
              child: NeuBox(
                inset: true,
                radius: 14,
                padding: const EdgeInsets.all(3),
                child: ArtworkThumb(id: artworkId),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    songsCountLabel(context, count),
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.play_arrow_rounded, color: context.accentSoft),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Home
// ===========================================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _search = TextEditingController();
  int _tab = 0;
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (_searching) {
        _tab = 0;
      } else {
        _search.clear();
        _query = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final PlayerController c = context.controller;
    final List<String> tabs = <String>[
      context.tr('songs'),
      context.tr('artists'),
      context.tr('albums'),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: buildAuraAppBar(
        title: 'Aura Music',
        customTitle: _searching ? _buildSearchField(context) : null,
        actions: <Widget>[
          NeuButton(
            icon: _searching ? Icons.close_rounded : Icons.search,
            tooltip: context.tr('search_hint'),
            size: 40,
            iconSize: 20,
            onPressed: _toggleSearch,
          ),
          const SizedBox(width: 10),
          _buildMenu(context, c),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: NeuTabBar(
              labels: tabs,
              selectedIndex: _tab,
              onChanged: (int i) => setState(() => _tab = i),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: c,
              builder: (BuildContext context, Widget? child) =>
                  _buildBody(context, c),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return SizedBox(
      height: 42,
      child: NeuBox(
        inset: true,
        radius: 21,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextField(
            controller: _search,
            autofocus: true,
            cursorColor: context.accent,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: context.tr('search_hint'),
              hintStyle: const TextStyle(color: Colors.white38),
              border: InputBorder.none,
              isDense: true,
            ),
            onChanged: (String value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context, PlayerController c) {
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 48),
      onSelected: (String value) {
        if (value == 'refresh') {
          c.checkPermissionAndLoad();
        } else if (value == 'about') {
          showAboutDialog(
            context: context,
            applicationName: 'Aura Music',
            applicationVersion: '1.0.0',
          );
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'refresh',
          child: Text(context.tr('refresh_library')),
        ),
        PopupMenuItem<String>(
          value: 'about',
          child: Text(context.tr('about')),
        ),
      ],
      child: const SizedBox(
        width: 40,
        height: 40,
        child: NeuBox(
          shape: BoxShape.circle,
          depth: 0.6,
          child: Center(
            child: Icon(Icons.more_vert, size: 20, color: Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PlayerController c) {
    if (c.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (c.errorKey != null) {
      return StatusMessage(
        icon: Icons.error_outline,
        title: context.tr('error_title'),
        message: context.tr(c.errorKey!),
        actionLabel: context.tr('try_again'),
        onAction: c.checkPermissionAndLoad,
      );
    }
    if (!c.permissionGranted) {
      return StatusMessage(
        icon: Icons.lock_outline,
        title: context.tr('permission_title'),
        message: context.tr('permission_msg'),
        actionLabel: context.tr('grant_permission'),
        onAction: c.checkPermissionAndLoad,
      );
    }
    if (c.songs.isEmpty) {
      return StatusMessage(
        icon: Icons.music_off_outlined,
        title: context.tr('no_songs'),
        message: context.tr('no_songs_msg'),
      );
    }

    switch (_tab) {
      case 0:
        return _buildSongList(context, c);
      case 1:
        return _buildGroupList(context, c, byArtist: true);
      default:
        return _buildGroupList(context, c, byArtist: false);
    }
  }

  void _playSong(BuildContext context, PlayerController c, SongModel song) {
    final int index = c.songs.indexWhere((SongModel s) => s.id == song.id);
    if (index < 0) return;
    unawaited(c.playFrom(c.songs, index, source: 'library'));
    openNowPlaying(context);
  }

  Widget _buildSongList(BuildContext context, PlayerController c) {
    final List<SongModel> shown = _query.isEmpty
        ? c.songs
        : c.songs
            .where((SongModel s) =>
                s.title.toLowerCase().contains(_query) ||
                context.artistOf(s).toLowerCase().contains(_query))
            .toList();

    if (shown.isEmpty) {
      return StatusMessage(
        icon: Icons.search_off_rounded,
        title: context.tr('no_results'),
        message: context.tr(
          'nothing_matches',
          args: <String, String>{'q': _search.text.trim()},
        ),
      );
    }

    return ValueListenableBuilder<SongModel?>(
      valueListenable: c.currentSong,
      builder: (BuildContext context, SongModel? current, Widget? child) {
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: shown.length,
          itemBuilder: (BuildContext context, int i) {
            final SongModel song = shown[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: SongCard(
                song: song,
                selected: song.id == current?.id,
                player: c.player,
                onTap: () => _playSong(context, c, song),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGroupList(
    BuildContext context,
    PlayerController c, {
    required bool byArtist,
  }) {
    final Map<String, List<SongModel>> groups = <String, List<SongModel>>{};
    for (final SongModel s in c.songs) {
      final String key =
          (byArtist ? cleanTag(s.artist) : cleanTag(s.album)) ?? '';
      groups.putIfAbsent(key, () => <SongModel>[]).add(s);
    }
    final List<String> keys = groups.keys.toList()
      ..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: keys.length,
      itemBuilder: (BuildContext context, int i) {
        final String key = keys[i];
        final List<SongModel> members = groups[key]!;
        final String title = key.isEmpty
            ? context.tr(byArtist ? 'unknown_artist' : 'unknown_album')
            : key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GroupCard(
            title: title,
            count: members.length,
            artworkId: members.first.id,
            onTap: () {
              unawaited(
                c.playFrom(
                  members,
                  0,
                  source: '${byArtist ? 'artist' : 'album'}:$key',
                ),
              );
              openNowPlaying(context);
            },
          ),
        );
      },
    );
  }
}

// ===========================================================================
// Library + playlists
// ===========================================================================
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: buildAuraAppBar(title: context.tr('library')),
      body: const PlaylistsView(),
    );
  }
}

/// List of playlists + "New playlist" button (used by the Library screen).
class PlaylistsView extends StatelessWidget {
  const PlaylistsView({super.key});

  Future<void> _create(BuildContext context) async {
    final PlaylistStore store = context.playlistStore;
    final String? name = await askPlaylistName(context);
    if (name != null && name.isNotEmpty) {
      store.create(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PlaylistStore store = context.playlistStore;
    final PlayerController c = context.controller;
    final List<Playlist> items = store.items;

    final Widget newButton = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: NeuPillButton(
          icon: Icons.add_rounded,
          label: context.tr('new_playlist'),
          filled: true,
          onTap: () => _create(context),
        ),
      ),
    );

    if (items.isEmpty) {
      return Column(
        children: <Widget>[
          newButton,
          Expanded(
            child: StatusMessage(
              icon: Icons.queue_music_rounded,
              title: context.tr('no_playlists'),
              message: context.tr('no_playlists_msg'),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: items.length + 1,
      itemBuilder: (BuildContext context, int i) {
        if (i == 0) return newButton;
        final Playlist playlist = items[i - 1];
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: _PlaylistCard(
            playlist: playlist,
            songs: c.songsOf(playlist),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) =>
                    PlaylistDetailPage(playlistId: playlist.id),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.songs,
    required this.onTap,
  });

  final Playlist playlist;
  final List<SongModel> songs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: NeuBox(
        radius: 20,
        padding: const EdgeInsets.all(10),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 54,
              height: 54,
              child: NeuBox(
                inset: true,
                radius: 14,
                padding: const EdgeInsets.all(3),
                child: songs.isEmpty
                    ? Center(
                        child: Icon(
                          Icons.queue_music_rounded,
                          color: context.accentSoft,
                        ),
                      )
                    : ArtworkThumb(id: songs.first.id),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    songsCountLabel(context, songs.length),
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.chevron_right, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: choose a playlist for [song] (or create a new one).
Future<void> showAddToPlaylistSheet(BuildContext context, SongModel song) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => _AddToPlaylistSheet(song: song),
  );
}

class _AddToPlaylistSheet extends StatelessWidget {
  const _AddToPlaylistSheet({required this.song});

  final SongModel song;

  @override
  Widget build(BuildContext context) {
    final PlaylistStore store = context.playlistStore;
    final PlayerController c = context.controller;
    final List<Playlist> items = store.items;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  context.tr('add_to_playlist'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.add_circle_outline_rounded,
                color: context.accentSoft,
              ),
              title: Text(context.tr('new_playlist')),
              onTap: () async {
                final ScaffoldMessengerState messenger =
                    ScaffoldMessenger.of(context);
                final NavigatorState navigator = Navigator.of(context);
                final String? name = await askPlaylistName(context);
                if (name == null || name.isEmpty || !context.mounted) return;
                final Playlist created = store.create(name);
                store.addSongs(created.id, <int>[song.id]);
                final String text = context.tr(
                  'added_to',
                  args: <String, String>{'name': created.name},
                );
                navigator.pop();
                messenger.showSnackBar(SnackBar(content: Text(text)));
              },
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final Playlist p in items)
                    ListTile(
                      leading: Icon(
                        p.songIds.contains(song.id)
                            ? Icons.check_circle_rounded
                            : Icons.queue_music_rounded,
                        color: p.songIds.contains(song.id)
                            ? context.accent
                            : Colors.white54,
                      ),
                      title: Text(p.name),
                      subtitle: Text(
                        songsCountLabel(context, c.songsOf(p).length),
                        style: const TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        final ScaffoldMessengerState messenger =
                            ScaffoldMessenger.of(context);
                        final String text = context.tr(
                          'added_to',
                          args: <String, String>{'name': p.name},
                        );
                        store.addSongs(p.id, <int>[song.id]);
                        Navigator.of(context).pop();
                        messenger.showSnackBar(SnackBar(content: Text(text)));
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class PlaylistDetailPage extends StatelessWidget {
  const PlaylistDetailPage({super.key, required this.playlistId});

  final String playlistId;

  void _pickSongs(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            SongPickerPage(playlistId: playlistId),
      ),
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    String value,
    Playlist playlist,
  ) async {
    final PlaylistStore store = context.playlistStore;
    if (value == 'rename') {
      final String? name =
          await askPlaylistName(context, initial: playlist.name);
      if (name != null && name.isNotEmpty) {
        store.rename(playlist.id, name);
      }
    } else if (value == 'delete') {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(
            dialogContext.tr(
              'delete_playlist_q',
              args: <String, String>{'name': playlist.name},
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.tr('delete')),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        Navigator.of(context).pop();
        store.delete(playlist.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final PlaylistStore store = context.playlistStore;
    final PlayerController c = context.controller;
    final Playlist? playlist = store.byId(playlistId);
    if (playlist == null) return const SizedBox.shrink();
    final List<SongModel> songs = c.songsOf(playlist);

    return NeuBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: buildSubAppBar(
          context,
          title: playlist.name,
          actions: <Widget>[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              onSelected: (String value) => _onMenu(context, value, playlist),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'rename',
                  child: Text(context.tr('rename')),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text(context.tr('delete')),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: songs.isEmpty
            ? StatusMessage(
                icon: Icons.queue_music_rounded,
                title: context.tr('empty_playlist'),
                message: context.tr('empty_playlist_msg'),
              )
            : ValueListenableBuilder<SongModel?>(
                valueListenable: c.currentSong,
                builder: (
                  BuildContext context,
                  SongModel? current,
                  Widget? child,
                ) {
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: songs.length,
                    itemBuilder: (BuildContext context, int i) {
                      final SongModel song = songs[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: SongCard(
                          song: song,
                          selected: song.id == current?.id,
                          player: c.player,
                          onRemove: () =>
                              store.removeSong(playlist.id, song.id),
                          onTap: () {
                            unawaited(c.playPlaylist(playlist, start: i));
                            openNowPlaying(context);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: NeuPillButton(
                        icon: Icons.add_rounded,
                        label: context.tr('add_songs'),
                        onTap: () => _pickSongs(context),
                      ),
                    ),
                    if (songs.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 12),
                      Expanded(
                        child: NeuPillButton(
                          icon: Icons.play_arrow_rounded,
                          label: context.tr('play_all'),
                          filled: true,
                          onTap: () {
                            unawaited(c.playPlaylist(playlist));
                            openNowPlaying(context);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const MiniPlayer(),
            ],
          ),
        ),
      ),
    );
  }
}

class SongPickerPage extends StatefulWidget {
  const SongPickerPage({super.key, required this.playlistId});

  final String playlistId;

  @override
  State<SongPickerPage> createState() => _SongPickerPageState();
}

class _SongPickerPageState extends State<SongPickerPage> {
  final Set<int> _selected = <int>{};
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PlayerController c = context.controller;
    final PlaylistStore store = context.playlistStore;
    final Playlist? playlist = store.byId(widget.playlistId);
    if (playlist == null) return const SizedBox.shrink();

    final Set<int> existing = playlist.songIds.toSet();
    final List<SongModel> shown = c.songs
        .where((SongModel s) =>
            _query.isEmpty ||
            s.title.toLowerCase().contains(_query) ||
            context.artistOf(s).toLowerCase().contains(_query))
        .toList();

    return NeuBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: buildSubAppBar(
          context,
          title: context.tr('add_songs'),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Center(
                child: Text(
                  context.tr(
                    'n_selected',
                    args: <String, String>{'n': '${_selected.length}'},
                  ),
                  style: TextStyle(color: context.accentSoft, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: NeuBox(
                inset: true,
                radius: 21,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _search,
                  cursorColor: context.accent,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: context.tr('search_hint'),
                    hintStyle: const TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    icon: const Icon(Icons.search, color: Colors.white38),
                  ),
                  onChanged: (String value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: shown.length,
                itemBuilder: (BuildContext context, int i) {
                  final SongModel song = shown[i];
                  final bool already = existing.contains(song.id);
                  final bool picked = _selected.contains(song.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: already
                          ? null
                          : () => setState(() {
                                if (picked) {
                                  _selected.remove(song.id);
                                } else {
                                  _selected.add(song.id);
                                }
                              }),
                      child: Opacity(
                        opacity: already ? 0.5 : 1,
                        child: NeuBox(
                          radius: 18,
                          glow: picked,
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: <Widget>[
                              ArtworkThumb(id: song.id, size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      context.artistOf(song),
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
                                child: Icon(
                                  already || picked
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked,
                                  color: picked
                                      ? context.accent
                                      : Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: NeuPillButton(
              icon: Icons.check_rounded,
              label: context.tr('done'),
              filled: true,
              onTap: () {
                store.addSongs(playlist.id, _selected);
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Now playing (full screen)
// ===========================================================================
class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerController c = context.controller;
    return NeuBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragEnd: (DragEndDetails details) {
              if ((details.primaryVelocity ?? 0) > 500) {
                Navigator.of(context).maybePop();
              }
            },
            child: ValueListenableBuilder<SongModel?>(
              valueListenable: c.currentSong,
              builder: (BuildContext context, SongModel? song, Widget? child) {
                if (song == null) {
                  return StatusMessage(
                    icon: Icons.music_off_outlined,
                    title: context.tr('no_songs'),
                    message: context.tr('no_songs_msg'),
                  );
                }
                return _NowPlayingBody(song: song, controller: c);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NowPlayingBody extends StatelessWidget {
  const _NowPlayingBody({required this.song, required this.controller});

  final SongModel song;
  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final PlayerController c = controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              NeuButton(
                icon: Icons.keyboard_arrow_down_rounded,
                tooltip: context.tr('close'),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Text(
                  context.tr('now_playing'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
              NeuButton(
                icon: Icons.playlist_add_rounded,
                tooltip: context.tr('add_to_playlist'),
                onPressed: () => showAddToPlaylistSheet(context, song),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double side =
                      math.min(constraints.maxWidth, constraints.maxHeight - 16)
                          .clamp(120.0, 520.0)
                          .toDouble();
                  return NeuBox(
                    radius: 34,
                    padding: const EdgeInsets.all(10),
                    child: ArtworkThumb(
                      id: song.id,
                      size: side - 20,
                      radius: 26,
                      highRes: true,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            song.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            context.artistOf(song),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: context.accentSoft),
          ),
          const SizedBox(height: 14),
          _SeekBar(player: c.player, fallbackMs: song.duration ?? 0),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: ListenableBuilder(
              listenable: c,
              builder: (BuildContext context, Widget? child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    NeuButton(
                      icon: Icons.shuffle_rounded,
                      size: 48,
                      active: c.shuffle,
                      onPressed: c.toggleShuffle,
                    ),
                    NeuButton(
                      icon: Icons.skip_previous_rounded,
                      size: 56,
                      iconSize: 28,
                      onPressed: () => c.player.seekToPrevious(),
                    ),
                    PlayPauseButton(player: c.player, size: 76, iconSize: 40),
                    NeuButton(
                      icon: Icons.skip_next_rounded,
                      size: 56,
                      iconSize: 28,
                      onPressed: () => c.player.seekToNext(),
                    ),
                    NeuButton(
                      icon: c.loopMode == LoopMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      size: 48,
                      active: c.loopMode != LoopMode.off,
                      onPressed: c.cycleLoop,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.player, required this.fallbackMs});

  final AudioPlayer player;
  final int fallbackMs;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.accent;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: StreamBuilder<Duration>(
        stream: widget.player.positionStream,
        builder: (BuildContext context, AsyncSnapshot<Duration> snapshot) {
          final Duration position = snapshot.data ?? Duration.zero;
          final Duration total = widget.player.duration ??
              Duration(milliseconds: widget.fallbackMs);
          final double max =
              total.inMilliseconds > 0 ? total.inMilliseconds.toDouble() : 1.0;
          final double value = (_drag ?? position.inMilliseconds.toDouble())
              .clamp(0.0, max)
              .toDouble();

          return Column(
            children: <Widget>[
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 5,
                  activeTrackColor: accent,
                  inactiveTrackColor: Colors.white12,
                  thumbColor: context.accentSoft,
                  overlayColor: accent.withValues(alpha: 0.2),
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                ),
                child: Slider(
                  value: value,
                  max: max,
                  onChanged: (double v) => setState(() => _drag = v),
                  onChangeEnd: (double v) {
                    widget.player.seek(Duration(milliseconds: v.round()));
                    setState(() => _drag = null);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      formatDuration(Duration(milliseconds: value.round())),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                    Text(
                      formatDuration(total),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Mini player + play/pause button
// ===========================================================================
class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({
    super.key,
    required this.player,
    this.size = 48,
    this.iconSize = 28,
  });

  final AudioPlayer player;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (BuildContext context, AsyncSnapshot<PlayerState> snapshot) {
        final PlayerState? state = snapshot.data;
        final ProcessingState? processing = state?.processingState;
        final bool playing = state?.playing ?? false;
        final bool loading = processing == ProcessingState.loading ||
            processing == ProcessingState.buffering;

        return NeuButton(
          filled: true,
          size: size,
          iconSize: iconSize,
          loading: loading,
          icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          onPressed: () {
            if (playing) {
              player.pause();
            } else {
              player.play();
            }
          },
        );
      },
    );
  }
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerController c = context.controller;
    return ValueListenableBuilder<SongModel?>(
      valueListenable: c.currentSong,
      builder: (BuildContext context, SongModel? song, Widget? child) {
        if (song == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => openNowPlaying(context),
            child: NeuBox(
              radius: 26,
              padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: NeuBox(
                          inset: true,
                          radius: 14,
                          padding: const EdgeInsets.all(3),
                          child: ArtworkThumb(id: song.id, size: 44),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.artistOf(song),
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
                      const SizedBox(width: 8),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            NeuButton(
                              icon: Icons.skip_previous_rounded,
                              tooltip: context.tr('play'),
                              size: 38,
                              onPressed: () => c.player.seekToPrevious(),
                            ),
                            const SizedBox(width: 8),
                            PlayPauseButton(player: c.player),
                            const SizedBox(width: 8),
                            NeuButton(
                              icon: Icons.skip_next_rounded,
                              size: 38,
                              onPressed: () => c.player.seekToNext(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<Duration>(
                    stream: c.player.positionStream,
                    builder: (
                      BuildContext context,
                      AsyncSnapshot<Duration> posSnap,
                    ) {
                      final Duration position = posSnap.data ?? Duration.zero;
                      final Duration total = c.player.duration ??
                          Duration(milliseconds: song.duration ?? 0);
                      final double value = total.inMilliseconds > 0
                          ? (position.inMilliseconds / total.inMilliseconds)
                              .clamp(0.0, 1.0)
                              .toDouble()
                          : 0.0;
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 3,
                          color: context.accent,
                          backgroundColor: Colors.white12,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}