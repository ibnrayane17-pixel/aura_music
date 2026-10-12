import 'package:aura_music/app_scope.dart';
import 'package:aura_music/l10n.dart';
import 'package:aura_music/l10n_extra.dart';
import 'package:aura_music/neu.dart';
import 'package:aura_music/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _freshPrefs() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return SharedPreferences.getInstance();
}

Widget _wrap(SharedPreferences prefs, Widget child) {
  final AppSettings settings = AppSettings(prefs);
  return AppScope(
    settings: settings,
    playlists: PlaylistStore(prefs),
    child: MaterialApp(
      theme: buildAuraTheme(settings.accent, settings.accentSoft),
      home: Scaffold(body: child),
    ),
  );
}

void _expectComplete(
  Map<String, Map<String, String>> tables,
  Map<String, String> english,
) {
  final RegExp placeholder = RegExp(r'\{[a-z]+\}');
  for (final AppLanguage lang in kLanguages) {
    final Map<String, String>? table = tables[lang.code];
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
}

void main() {
  group('Translations', () {
    test('there are 10 languages', () {
      expect(kLanguages.length, 10);
    });

    test('main strings are complete in every language', () {
      _expectComplete(kStrings, kStrings['en']!);
    });

    test('extra strings are complete in every language', () {
      _expectComplete(kExtraStrings, kExtraStrings['en']!);
    });

    test('placeholders are replaced', () {
      expect(
        translateAll('fr', 'plays_n', args: <String, String>{'n': '5'}),
        contains('5'),
      );
    });
  });

  group('Settings', () {
    test('values are saved and restored', () async {
      final SharedPreferences prefs = await _freshPrefs();
      final AppSettings settings = AppSettings(prefs);

      await settings.setAccent(2);
      await settings.setLanguage('ar');
      await settings.setSortMode(1);
      await settings.setMinSeconds(60);

      final AppSettings restored = AppSettings(prefs);
      expect(restored.accent, kAccents[2].main);
      expect(restored.language, 'ar');
      expect(restored.isRtl, isTrue);
      expect(restored.sortMode, 1);
      expect(restored.minSeconds, 60);
      expect(restored.tr('settings'), isNot(translate('en', 'settings')));
    });
  });

  group('Playlists', () {
    test('create, edit, save and delete', () async {
      final SharedPreferences prefs = await _freshPrefs();
      final PlaylistStore store = PlaylistStore(prefs);

      final Playlist p = store.create('Road trip');
      store.addSongs(p.id, <int>[1, 2, 2, 3]);
      expect(store.byId(p.id)!.songIds, <int>[1, 2, 3]);

      store.removeSong(p.id, 2);
      store.rename(p.id, 'Chill');

      final PlaylistStore reloaded = PlaylistStore(prefs);
      expect(reloaded.items.single.name, 'Chill');
      expect(reloaded.items.single.songIds, <int>[1, 3]);

      store.delete(p.id);
      expect(store.items, isEmpty);
    });
  });

  group('Widgets', () {
    testWidgets('StatusMessage shows its text and triggers the action',
        (WidgetTester tester) async {
      final SharedPreferences prefs = (await tester.runAsync(_freshPrefs))!;
      bool tapped = false;

      await tester.pumpWidget(
        _wrap(
          prefs,
          StatusMessage(
            icon: Icons.lock_outline,
            title: 'Permission required',
            message: 'Aura Music needs access to your audio files.',
            actionLabel: 'Grant permission',
            onAction: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Permission required'), findsOneWidget);
      await tester.tap(find.text('Grant permission'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('NeuTabBar reports the tapped tab',
        (WidgetTester tester) async {
      final SharedPreferences prefs = (await tester.runAsync(_freshPrefs))!;
      int selected = 0;

      await tester.pumpWidget(
        _wrap(
          prefs,
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return NeuTabBar(
                labels: const <String>['Songs', 'Artists', 'Albums'],
                selectedIndex: selected,
                onChanged: (int i) => setState(() => selected = i),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle();
      expect(selected, 2);
    });

    testWidgets('choice dialog returns the tapped option',
        (WidgetTester tester) async {
      final SharedPreferences prefs = (await tester.runAsync(_freshPrefs))!;
      int? result;

      await tester.pumpWidget(
        _wrap(
          prefs,
          Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                result = await showNeuChoiceDialog<int>(
                  context,
                  title: 'Pick one',
                  selected: 1,
                  choices: const <NeuChoice<int>>[
                    NeuChoice<int>(value: 1, label: 'One'),
                    NeuChoice<int>(value: 2, label: 'Two'),
                  ],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(result, 2);
    });
  });
}
