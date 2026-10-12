import 'package:aura_music/app_scope.dart';
import 'package:aura_music/neu.dart';
import 'package:aura_music/pages.dart';
import 'package:aura_music/player_controller.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

class HiddenSongsPage extends StatelessWidget {
  const HiddenSongsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerController c = context.controller;

    return NeuBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: buildSubAppBar(context, title: context.tr('hidden_songs')),
        body: ListenableBuilder(
          listenable: c,
          builder: (BuildContext _, Widget? child) {
            final List<SongModel> hidden = c.hiddenSongs;

            if (hidden.isEmpty) {
              return StatusMessage(
                icon: Icons.visibility_outlined,
                title: context.tr('no_hidden'),
                message: context.tr('no_hidden_msg'),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: NeuPillButton(
                      icon: Icons.visibility_outlined,
                      label: context.tr('unhide_all'),
                      filled: true,
                      onTap: () => c.unhideAll(),
                    ),
                  ),
                ),
                for (final SongModel song in hidden)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: NeuBox(
                      radius: 18,
                      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 10, 8),
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
                          NeuButton(
                            icon: Icons.visibility_outlined,
                            size: 40,
                            iconSize: 20,
                            tooltip: context.tr('unhide'),
                            onPressed: () => c.unhideSongs(<int>[song.id]),
                          ),
                        ],
                      ),
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
