// What a handle's dispose means: a disposed campaign or session refuses a
// call rather than handing the engine a pointer it has freed, and a session
// outlives the campaign it was made from.
import 'package:ripplefx_engine/ripplefx_engine.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  setUpAll(setUpEngine);

  test('a disposed handle refuses a call', () async {
    final campaign = await openFixture('the-choir');
    final session = Session.create(
      campaign,
      SessionConfig(board: campaign.manifest.entries.first),
    );
    session.dispose();
    expect(session.start, throwsStateError);
    campaign.dispose();
    expect(() => campaign.manifest, throwsStateError);
    // Twice is nothing.
    session.dispose();
    campaign.dispose();
  });

  test('a session outlives its campaign', () async {
    final campaign = await openFixture('the-choir');
    final session = Session.create(
      campaign,
      SessionConfig(board: campaign.manifest.entries.first),
    );
    campaign.dispose();
    addTearDown(session.dispose);
    var batch = session.start();
    expect(batch.last, isA<Show>());
    batch = session.choose(0);
    expect(batch.last.isTurn, isTrue);
  });

  test(
    'a campaign opened from its files plays as from its folder',
    testOn: 'vm',
    () async {
      final fromFiles = await Campaign.openFiles(
        await fixtureFiles('the-choir'),
      );
      final fromFolder = await Campaign.openDirectory(
        fixtureFolder('the-choir'),
      );
      addTearDown(fromFiles.dispose);
      addTearDown(fromFolder.dispose);
      expect(fromFiles.folder, isNull);
      expect(
        fromFiles.manifest.passages.length,
        fromFolder.manifest.passages.length,
      );
      String first(Campaign c) {
        final session = Session.create(
          c,
          SessionConfig(board: c.manifest.entries.first),
        );
        try {
          return (session.start().last as Show).passage.text;
        } finally {
          session.dispose();
        }
      }

      expect(first(fromFiles), first(fromFolder));
    },
  );
}
