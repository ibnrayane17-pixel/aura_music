import 'package:aura_music/l10n.dart';
import 'package:aura_music/l10n_extra.dart';
import 'package:aura_music/l10n_more.dart';
import 'package:aura_music/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('hide/delete strings are complete in every language', () {
    final RegExp placeholder = RegExp(r'\{[a-z]+\}');
    final Map<String, String> english = kMoreStrings['en']!;

    for (final AppLanguage lang in kLanguages) {
      final Map<String, String>? table = kMoreStrings[lang.code];
      expect(table, isNotNull, reason: 'No table for ${lang.code}');
      for (final MapEntry<String, String> entry in english.entries) {
        final String? text = table![entry.key];
        expect(text, isNotNull, reason: '${lang.code} lacks "${entry.key}"');
        for (final RegExpMatch m in placeholder.allMatches(entry.value)) {
          expect(
            text!.contains(m.group(0)!),
            isTrue,
            reason: '${lang.code}/${entry.key} lacks ${m.group(0)}',
          );
        }
      }
    }
  });

  test('translateAll finds the new strings', () {
    expect(translateAll('fr', 'undo'), isNot('undo'));
    expect(
      translateAll('ar', 'hidden_songs'),
      isNot(translateAll('en', 'hidden_songs')),
    );
    expect(
      translateAll('en', 'hidden_n', args: <String, String>{'n': '3'}),
      '3 hidden',
    );
  });

  test('removeSongsEverywhere cleans every playlist', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final PlaylistStore store = PlaylistStore(prefs);

    final Playlist a = store.create('A');
    final Playlist b = store.create('B');
    store.addSongs(a.id, <int>[1, 2, 3]);
    store.addSongs(b.id, <int>[2, 4]);

    store.removeSongsEverywhere(<int>[2, 3]);

    expect(store.byId(a.id)!.songIds, <int>[1]);
    expect(store.byId(b.id)!.songIds, <int>[4]);
  });
}