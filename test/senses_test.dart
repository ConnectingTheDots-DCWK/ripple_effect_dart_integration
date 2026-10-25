// What contract 1.6 hands a host that the fixtures' traces do not spell in
// full: a Permit turn's kinds by the C ABI's numbers, the readings a host
// pushes in and the refusals it gets back, a passage's countdown driven by
// hand and by a Player on a clock that is a number, and a form's labels and
// options. The engine judges the rules; this judges that each crosses whole,
// on both backends.
import 'package:ripplefx_engine/ripplefx_engine.dart';
import 'package:test/test.dart';

import 'support.dart';

Future<(Campaign, Session)> _open(String fixture) async {
  final campaign = await openFixture(fixture);
  final session = Session.create(
    campaign,
    SessionConfig(board: campaign.manifest.entries.first),
  );
  addTearDown(() {
    session.dispose();
    campaign.dispose();
  });
  return (campaign, session);
}

Matcher _refused(Code code, [String subject = '']) => throwsA(
  isA<HostException>()
      .having((e) => e.code, 'code', code)
      .having((e) => e.failure.subject, 'subject', subject),
);

void main() {
  setUpAll(setUpEngine);

  test('a story that reads the world asks first, and is told', () async {
    final (campaign, session) = await _open('the-weathervane');
    // The manifest names the kinds; the Permit turn numbers them. The same
    // list both ways is the C ABI's numbering read right.
    expect(campaign.manifest.permissions, ['dateTime', 'location']);
    final asked = session.start();
    expect(asked.whereType<Turn>(), hasLength(1));
    expect([
      for (final kind in (asked.last as Permit).kinds) kind.wire,
    ], campaign.manifest.permissions);

    session.setNow(const Moment(1792427400000, 120));
    expect(
      session.permit(PermissionKind.dateTime, granted: true).whereType<Turn>(),
      isEmpty,
    );
    final begun = session.permit(PermissionKind.location, granted: false);
    final shown = (begun.last as Show).passage;
    expect(shown.text, contains('2026-10-19T18:30:00+02:00'));

    // Denied, a fix is refused by name; a stand-in that does not read too.
    expect(
      () => session.setPosition(const Position(latitude: 1, longitude: 2)),
      _refused(Code.notPermitted, 'location'),
    );
    expect(
      () => session.setStandIn(PermissionKind.dateTime, 'teatime'),
      _refused(Code.standIn, 'dateTime'),
    );

    session.setStandIn(
      PermissionKind.location,
      '41.9028, 12.4964',
      localOffsetMinutes: 0,
    );
    final read = session.choose(0);
    final notice = read.whereType<Notice>().single;
    expect(notice.code, 'I.RT.05');
    expect(notice.kind, PermissionKind.location);
    expect(notice.node, 'location_get_5');
    expect(read.indexOf(notice), lessThan(read.length - 1));
    expect((read.last as Show).passage.text, contains('41.9028'));
  });

  test('a player asks about what is left to answer', () async {
    final (_, session) = await _open('the-weathervane');
    final player = Player(session, wallClock: () => const Moment(0, 0));
    player.start();
    expect((player.turn! as Permit).kinds, [
      PermissionKind.dateTime,
      PermissionKind.location,
    ]);
    player.permit(PermissionKind.dateTime, granted: true);
    expect((player.turn! as Permit).kinds, [PermissionKind.location]);
    player.permit(PermissionKind.location, granted: false);
    expect((player.turn! as Show).passage.text, contains('1970-01-01'));
    player.dispose();
  });

  test('a countdown is the host\'s to begin and to run out', () async {
    final (_, session) = await _open('the-hesitation');
    final timer = (session.start().last as Show).passage.timer!;
    expect(
      (timer.afterMs, timer.timeoutMs, timer.visible, timer.defaultChoice),
      (2000, 5000, true, 1),
    );

    expect(session.expire, _refused(Code.countdownNotBegun));
    final begun = session.beginCountdown();
    expect(begun.whereType<Turn>(), isEmpty);
    expect(
      begun.whereType<Callback>().single.event.eventName,
      'countdown.started',
    );

    final expired = session.expire();
    final callbacks = expired.whereType<Callback>().map((c) => c.event);
    expect(callbacks.first.eventName, 'countdown.expired');
    expect(callbacks.first.index, 1);
    expect(expired.last, isA<Show>());

    // Another passage without one refuses both verbs.
    final (_, plain) = await _open('the-choir');
    plain.start();
    expect(plain.beginCountdown, _refused(Code.noCountdown));
  });

  test('a player runs a countdown on its clock', () async {
    final (_, session) = await _open('the-hesitation');
    var now = 0;
    final events = <String>[];
    final player = Player(
      session,
      now: () => now,
      onEffect: (effect) {
        if (effect case Callback(:final event)) events.add(event.eventName);
      },
    );
    player.start();
    expect((player.countdown!.begun, player.countdown!.due), (false, 2000));

    now = 1999;
    player.update();
    expect(player.countdown!.begun, isFalse);
    now = 2000;
    player.update();
    expect((player.countdown!.begun, player.countdown!.due), (true, 7000));
    expect(events, ['countdown.started']);

    // The same passage in another language is the same visit.
    player.setLocale('it-IT');
    expect((player.countdown!.begun, player.countdown!.due), (true, 7000));

    now = 7000;
    player.update();
    expect(events, ['countdown.started', 'countdown.expired']);
    final next = (player.turn! as Show).passage;
    expect(next.node, 'narration_3');
    expect((player.countdown!.begun, player.countdown!.due), (false, 7000));

    // A reader who chooses ends the visit, and what was begun with it.
    now = 7500;
    player.choose(0);
    expect(player.countdown?.begun ?? false, isFalse);
    player.dispose();
  });

  test('a form carries its labels, and its options by id', () async {
    final (_, session) = await _open('the-chosen');
    var fields = (session.start().last as Ask).prompt.fields;
    expect([for (final f in fields) f.name], ['calling', 'companions']);
    expect([for (final f in fields) f.optional], [false, true]);
    expect(
      [for (final o in fields[1].options) o.id],
      ['alone', 'pair', 'band'],
    );
    expect(fields[1].options.first.value, isA<IntValue>());
    final english = [for (final o in fields[0].options) o.label];
    expect(fields[0].label, isNotEmpty);

    fields = (session.setLocale('it-IT').last as Ask).prompt.fields;
    expect([for (final o in fields[0].options) o.id], ['fighter', 'wizard']);
    expect([for (final o in fields[0].options) o.label], isNot(english));
  });
}
