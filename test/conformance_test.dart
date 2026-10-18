// Every conformance fixture of the pinned engine release, played through
// this binding's own API — Session and Player — and compared with what the
// fixture says a reader saw, the way the release's FORMAT.md describes. The
// engine's own suites judge its rules; this judges the spelling: that every
// effect crosses into Dart whole, an Int stays an Int and a Float a Float,
// and a host built on these types sees what any host sees.
import 'package:ripplefx_engine/ripplefx_engine.dart';
import 'package:test/test.dart';

import 'support.dart';

const int _stepBudget = 65536;

void main() {
  setUpAll(setUpEngine);

  test(
    'every fixture plays through the session',
    () => _playAll(player: false),
  );

  test('every fixture plays through the player', () => _playAll(player: true));

  test('nothing the engine handed out is left over', () async {
    await _playAll(player: false);
    expect(RippleEngine.outstanding, 0);
  });
}

Future<void> _playAll({required bool player}) async {
  final python = RippleEngine.hasPython;
  var played = 0;
  var skipped = 0;
  for (final name in await fixtureNames()) {
    final input = await fixtureJson(name, 'input.json');
    if (_needsPython(input) && !python) {
      skipped++;
      continue;
    }
    _compare(
      name,
      await _play(name, input, player: player),
      await fixtureJson(name, 'expect.json'),
    );
    played++;
  }
  // Twenty-four fixtures, three of which need the interpreter.
  expect(played + skipped, 24, reason: 'fixtures found');
  expect(
    skipped,
    python ? 0 : 3,
    reason: 'fixtures skipped for want of Python',
  );
}

bool _needsPython(Value input) => switch (input['needs']) {
  ListValue(:final items) => items.contains(const TextValue('python')),
  _ => false,
};

void _compare(String name, _Played got, Value wanted) {
  final trace = (wanted['trace']! as ListValue).items;
  expect(got.trace, hasLength(trace.length), reason: '$name: the trace length');
  for (var i = 0; i < trace.length; i++) {
    expect(
      canonical(got.trace[i]),
      canonical(trace[i]),
      reason: '$name: trace event $i',
    );
  }
  final callbacks = switch (wanted['callbacks']) {
    ListValue(:final items) => items,
    _ => const <Value>[],
  };
  expect(
    got.callbacks,
    hasLength(callbacks.length),
    reason: '$name: the callbacks differ in number',
  );
  for (var i = 0; i < callbacks.length; i++) {
    expect(
      canonical(got.callbacks[i]),
      canonical(callbacks[i]),
      reason: '$name: callback $i',
    );
  }
  expect(
    canonical(MapValue(got.entities)),
    canonical(wanted['entities'] ?? MapValue(const {})),
    reason: '$name: the entities',
  );
}

SessionOptions fixtureOptions() =>
    SessionOptions().copyWith(stepBudget: _stepBudget);

Future<_Played> _play(
  String fixture,
  Value input, {
  required bool player,
}) async {
  final campaign = await openFixture(fixture);
  try {
    final manifest = campaign.manifest;
    final played = _Played();
    final record = _Recorder(
      [for (final board in manifest.boards) board.id],
      campaign,
      played,
    );
    final config = SessionConfig(
      board: manifest.entries.isEmpty ? 0 : manifest.entries.first,
      seed: switch (input['seed']) {
        IntValue(:final value) => value,
        _ => 0,
      },
      locale: switch (input['locale']) {
        TextValue(:final value) => value,
        _ => null,
      },
      options: fixtureOptions(),
    );
    final session = Session.create(campaign, config);
    final _Host host = player
        ? _PlayerHost(campaign, session, config.seed, record)
        : _SessionHost(campaign, session, config.seed, record);
    try {
      String? saved;
      host.start();
      for (final move in (input['moves']! as ListValue).items) {
        if (_over(host.turn) && saved == null) break;
        switch ((move['do']! as TextValue).value) {
          case 'choose':
            if (host.turn is! Show) {
              throw StateError('a move chooses where no passage is showing');
            }
            host.choose((move['choice']! as IntValue).value);
          case 'answer':
            host.answer((move['values']! as MapValue).entries);
          case 'locale':
            host.setLocale((move['locale']! as TextValue).value);
          case 'pause':
            saved =
                host.pause() ??
                (throw StateError(
                  'a move pauses where the story is not waiting',
                ));
          case 'resume':
            host.resume(saved!);
            saved = null;
          case 'restart':
            host.restart();
        }
      }
      // The reader has left: the story goes on by itself until it is over.
      while (!_over(host.turn)) {
        switch (host.turn) {
          case Show():
            host.leave();
          case Ask():
            host.answer(null);
          default:
            host.elapsed();
        }
      }
      for (final entity in host.entities()) {
        played.entities[entity.key] = entity.values;
      }
      return played;
    } finally {
      host.dispose();
    }
  } finally {
    campaign.dispose();
  }
}

bool _over(Turn? turn) => turn == null || turn.isOver;

final class _Played {
  final List<Value> trace = [];
  final List<Value> callbacks = [];
  final Map<String, Value> entities = {};
}

// What a reader saw of one effect, as FORMAT.md's trace records it.
final class _Recorder {
  _Recorder(this.boards, this.campaign, this.into);

  final List<String> boards;
  final Campaign campaign;
  final _Played into;

  void record(Effect effect) {
    switch (effect) {
      case Show(:final passage):
        into.trace.add(
          map([
            ('kind', 'passage'),
            ('node', passage.node),
            ('markdown', passage.text),
            ('choices', [for (final choice in passage.choices) choice.text]),
            if (passage.untranslated case final untranslated?)
              ('untranslated', untranslated),
          ]),
        );
      case Ask(:final prompt):
        into.trace.add(
          map([
            ('kind', 'prompt'),
            ('node', prompt.node),
            (
              'fields',
              [
                for (final field in prompt.fields)
                  {'name': field.name, 'type': field.type},
              ],
            ),
          ]),
        );
      case Jumped(:final board, :final node):
        into.trace.add(
          map([
            ('kind', 'jump'),
            ('board', _board(board)),
            if (node != null) ('node', node),
          ]),
        );
      case Ended(:final title, :final ranOut):
        into.trace.add(
          ranOut
              ? map([('kind', 'ranOut')])
              : map([('kind', 'end'), if (title != null) ('title', title)]),
        );
      case Failed(:final message, :final node):
        into.trace.add(
          map([
            ('kind', 'error'),
            ('message', message),
            if (node != null) ('node', node),
          ]),
        );
      case Hold(:final ms):
        into.trace.add(map([('kind', 'wait'), ('ms', ms)]));
      case AmbienceChanged(:final ambience):
        into.trace.add(
          map([('kind', 'ambience'), ('soundscape', ambience?.soundscape.id)]),
        );
      case Audio(:final command) when command.kind == AudioKind.cue:
        into.trace.add(
          map([
            ('kind', 'sound'),
            if (command.node case final node?) ('node', node),
            ('media', campaign.mediaPath(command.media) ?? ''),
          ]),
        );
      case Callback(:final event):
        into.callbacks.add(
          map([
            ('callback', event.callback),
            ('event', event.eventName),
            if (event.board case final board?) ('board', _board(board)),
            if (event.node case final node?) ('node', node),
            if (event.name case final name?) ('name', name),
            if (event.from case final from? when !from.isNull) ('from', from),
            if (event.to case final to? when !to.isNull) ('to', to),
            if (event.index case final index?) ('index', index),
          ]),
        );
      default:
    }
  }

  String _board(int at) => at < boards.length ? boards[at] : '';
}

// The same verbs whichever API is underneath, and where the story is.
abstract interface class _Host {
  Turn? get turn;
  void start();
  void choose(int index);
  void leave();
  void answer(Map<String, Value>? values);
  void elapsed();
  void setLocale(String locale);
  String? pause();
  void resume(String save);
  void restart();
  List<Entity> entities();
  void dispose();
}

// Through a Session: every batch settled, while it ends on a hold, by saying
// `elapsed` at once — a fixture's clock never waits.
final class _SessionHost implements _Host {
  _SessionHost(this.campaign, this.session, this.seed, this.record);

  final Campaign campaign;
  final int seed;
  final _Recorder record;
  Session session;

  @override
  Turn? turn;

  @override
  void start() => _settle(session.start());

  @override
  void choose(int index) => _settle(session.choose(index));

  @override
  void leave() => _settle(session.leave());

  @override
  void answer(Map<String, Value>? values) => _settle(session.answer(values));

  @override
  void elapsed() => _settle(session.elapsed());

  @override
  void setLocale(String locale) => _settle(session.setLocale(locale));

  @override
  String? pause() {
    final paused = session.pause();
    _settle(paused.effects);
    return paused.save;
  }

  @override
  void resume(String save) {
    final generator = session.generator;
    session.dispose();
    session = Session.resume(
      campaign,
      save,
      seed: seed,
      options: fixtureOptions(),
    )..generator = generator;
    _settle(session.start());
  }

  @override
  void restart() => _settle(session.restart());

  @override
  List<Entity> entities() => session.entities;

  @override
  void dispose() => session.dispose();

  void _settle(List<Effect> batch) {
    while (true) {
      for (final effect in batch) {
        record.record(effect);
        if (effect is Turn) turn = effect;
      }
      if (batch.isEmpty || batch.last is! Hold) return;
      batch = session.elapsed();
    }
  }
}

// Through a Player, on a clock that is a number: every hold it is waiting on
// is run to its end by moving the clock and calling update().
final class _PlayerHost implements _Host {
  _PlayerHost(this.campaign, Session session, this.seed, this.record) {
    player = _make(session);
  }

  final Campaign campaign;
  final int seed;
  final _Recorder record;
  late Player player;
  int now = 0;

  @override
  Turn? get turn => player.turn;

  @override
  void start() => _run(player.start);

  @override
  void choose(int index) => _run(() => player.choose(index));

  @override
  void leave() => _run(player.leave);

  @override
  void answer(Map<String, Value>? values) => _run(() => player.answer(values));

  @override
  void elapsed() => player.session.elapsed().forEach(record.record);

  @override
  void setLocale(String locale) => _run(() => player.setLocale(locale));

  @override
  String? pause() {
    final save = player.pause();
    _flush();
    return save;
  }

  @override
  void resume(String save) {
    final generator = player.session.generator;
    player.dispose();
    player = _make(
      Session.resume(campaign, save, seed: seed, options: fixtureOptions())
        ..generator = generator,
    );
    _run(player.start);
  }

  @override
  void restart() => _run(player.restart);

  @override
  List<Entity> entities() => player.session.entities;

  @override
  void dispose() => player.dispose();

  Player _make(Session session) => Player(
    session,
    onEffect: record.record,
    onError: (error, stack) => fail('$error\n$stack'),
    now: () => now,
  );

  void _run(void Function() verb) {
    verb();
    _flush();
  }

  void _flush() {
    for (var due = player.holdDue; due != null; due = player.holdDue) {
      if (due > now) now = due;
      player.update();
    }
  }
}
