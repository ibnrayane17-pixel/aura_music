import 'package:aura_music/app_scope.dart';
import 'package:aura_music/player_controller.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// Hides [song] from the library and shows an "Undo" button.
void hideSongWithUndo(BuildContext context, SongModel song) {
  final PlayerController c = context.controller;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final String message = context.tr('song_hidden');
  final String undo = context.tr('undo');

  c.hideSongs(<int>[song.id]);

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: undo,
          onPressed: () => c.unhideSongs(<int>[song.id]),
        ),
      ),
    );
}

/// Asks for confirmation, then deletes the file from the phone.
Future<void> confirmAndDeleteSong(BuildContext context, SongModel song) async {
  final PlayerController c = context.controller;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final String title = context.tr(
    'delete_song_q',
    args: <String, String>{'name': song.title},
  );
  final String body = context.tr('delete_song_msg');
  final String cancel = context.tr('cancel');
  final String delete = context.tr('delete');
  final String doneText = context.tr('song_deleted');
  final String failText = context.tr('delete_failed');

  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(title, maxLines: 3, overflow: TextOverflow.ellipsis),
      content: Text(body, style: const TextStyle(color: Colors.white70)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            delete,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final bool ok = await c.deleteSongs(<SongModel>[song]);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(ok ? doneText : failText)));
}
