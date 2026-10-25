import 'effects.dart';
import 'errors.dart';
import 'records.dart';
import 'session.dart';
import 'soundscape_driver.dart';
import 'speaker.dart';
import 'value.dart';

/// The loop over a session, written once.
///
/// It delivers every effect in order, keeps the Turn the last one named,
/// answers a hold from its clock when [update] finds it due, applies the
/// sound to the driver, and is the table the author's named callbacks are
/// dispatched through (`campaign-host-api.md` §5b). A verb from inside a
/// handler is refused: the rest of the batch would arrive after the new one.
///
/// In a game, call [update] from the loop — Flame's `update(dt)` — and the
/// player answers a hold the frame its time comes, and runs a passage's
/// countdown the same way (`campaign-host-api.md` §4b).
final class Player {
  /// Plays [session], which the player owns from here and disposes.
  ///
  /// [onEffect] hears every effect, in the order the engine produced it.
  /// [onError] hears a failure of a verb the player made by itself — the
  /// `elapsed` after a hold — and any handler's exception; delivery goes on
  /// either way. Without it, a self-made verb's failure is thrown from
  /// [update], and a handler's is lost. [audio] is where the story's sound
  /// goes; without one, nothing is heard. [now] is the clock in
  /// milliseconds: [Clocks.steady] unless a test says otherwise.
  ///
  /// [countdowns] runs a passage's countdown on that clock — `beginCountdown`
  /// its wait after the passage was shown, `expire` when it runs out — and
  /// [countdown] says where it stands. Turn it off to offer the reader no
  /// time limit at all (WCAG 2.2.1), or to say when yourself.
  ///
  /// [wallClock] is what time it is for the story, handed to the session
  /// before every verb that can step — [Moment.now] for the reader's own
  /// clock. Without it the story has no clock, whatever the reader allowed.
  Player(
    this.session, {
    void Function(Effect effect)? onEffect,
    void Function(Object error, StackTrace stack)? onError,
    SoundscapeDriver? audio,
    Clock? now,
    bool countdowns = true,
    Moment Function()? wallClock,
  }) : _onEffect = onEffect,
       _onError = onError,
       _audio = audio,
       _clock = now ?? Clocks.steady(),
       _countdowns = countdowns,
       _wallClock = wallClock;

  /// The session underneath, for what the player does not wrap. A verb
  /// called on it goes round the player.
  final Session session;

  final void Function(Effect effect)? _onEffect;
  final void Function(Object error, StackTrace stack)? _onError;
  final SoundscapeDriver? _audio;
  final Clock _clock;
  final bool _countdowns;
  final Moment Function()? _wallClock;
  final Map<String, void Function(CallbackEvent)> _callbacks = {};
  final List<void Function(CallbackEvent)> _every = [];
  bool _delivering = false;
  bool _disposed = false;

  /// Where the story is: the last Turn delivered — or, once [permit] has
  /// answered some of a [Permit] turn's kinds, that turn less them.
  Turn? get turn => _turn;
  Turn? _turn;

  /// When the pending hold is due, by the player's clock; null when none is.
  int? get holdDue => _holdDue;
  int? _holdDue;

  /// The shown passage's countdown and where it stands; null when it has
  /// none, or when the player was made with `countdowns: false`.
  Countdown? get countdown => _countdown;
  Countdown? _countdown;

  /// How many callbacks fired with nothing registered under their name —
  /// not a failure: the author and the host declare their halves apart.
  int get callbackMisses => _callbackMisses;
  int _callbackMisses = 0;

  /// Calls [handler] whenever the callback named [name] fires, replacing any
  /// handler already under that name.
  void onCallback(String name, void Function(CallbackEvent event) handler) =>
      _callbacks[name] = handler;

  void removeCallback(String name) => _callbacks.remove(name);

  /// Calls [handler] for every callback that fires, registered or not.
  void onAnyCallback(void Function(CallbackEvent event) handler) =>
      _every.add(handler);

  void clearCallbacks() {
    _callbacks.clear();
    _every.clear();
  }

  void start() => _verb('start', session.start);

  void choose(int index) => _verb('choose', () => session.choose(index));

  void leave() => _verb('leave', session.leave);

  void answer(Map<String, Value>? fields) =>
      _verb('answer', () => session.answer(fields));

  /// The reader's answer for one kind; the answer to the last a [Permit]
  /// turn asked about begins the story. Until then [turn] is that Permit
  /// less the kinds answered, so a host asks about what is left.
  void permit(PermissionKind kind, {required bool granted}) {
    final asked = _turn;
    _verb('permit', () => session.permit(kind, granted: granted));
    if (asked is Permit && identical(_turn, asked)) {
      _turn = Permit(List.unmodifiable([...asked.kinds]..remove(kind)));
    }
  }

  /// Begins the shown passage's countdown now. The player does it by itself
  /// unless it was made with `countdowns: false`.
  void beginCountdown() => _verb('beginCountdown', session.beginCountdown);

  /// Runs the shown passage's countdown out now: its default is taken. The
  /// player does it by itself unless it was made with `countdowns: false`.
  void expire() => _verb('expire', session.expire);

  /// Reads on in another language. A passage shown again is the same visit,
  /// so its countdown keeps its time.
  void setLocale(String locale) =>
      _verb('setLocale', () => session.setLocale(locale), sameVisit: true);

  void restart() => _verb('restart', session.restart);

  void stop() => _verb('stop', session.stop);

  /// Puts the story down and answers its save — null, and nothing stopped,
  /// unless the story is on a passage or a prompt.
  String? pause() {
    if (_delivering) throw _reentrant('pause');
    _holdDue = null;
    _countdown = null;
    final paused = session.pause();
    _dispatch(paused.effects);
    return paused.save;
  }

  /// What the host calls from its loop: answers a hold whose time has come,
  /// and moves a countdown on when its time has.
  void update() {
    if (_delivering || _disposed) return;
    final now = _clock();
    if (_holdDue case final due? when now >= due) {
      _holdDue = null;
      _selfMade(session.elapsed);
    } else if (_countdown case final countdown? when now >= countdown.due) {
      if (countdown.begun) {
        _countdown = null;
        _selfMade(session.expire);
      } else {
        // Timed from when it was due, not from this frame, so a slow frame
        // does not lengthen it.
        _countdown = Countdown._(
          countdown.timer,
          begun: true,
          due: countdown.due + countdown.timer.timeoutMs,
        );
        _selfMade(session.beginCountdown, sameVisit: true);
      }
    }
  }

  /// Delivers nothing more, moves the story no further, and disposes the
  /// session.
  void dispose() {
    _holdDue = null;
    _disposed = true;
    session.dispose();
  }

  static ReentrantVerbException _reentrant(String verb) =>
      ReentrantVerbException(
        Failure(
          Code.reentrant,
          '$verb() was called while the player was delivering a batch; '
          'call it after the handler returns',
        ),
      );

  void _verb(
    String name,
    List<Effect> Function() run, {
    bool sameVisit = false,
  }) {
    if (_delivering) throw _reentrant(name);
    if (_disposed) return;
    _holdDue = null;
    _tellTime();
    _dispatch(run(), sameVisit: sameVisit);
  }

  // A verb the player made by itself: its failure is the host's to hear.
  void _selfMade(List<Effect> Function() run, {bool sameVisit = false}) {
    final List<Effect> next;
    try {
      _tellTime();
      next = run();
    } on RippleException catch (error, stack) {
      final onError = _onError;
      if (onError == null) rethrow;
      onError(error, stack);
      return;
    }
    _dispatch(next, sameVisit: sameVisit);
  }

  void _tellTime() {
    if (_wallClock case final wallClock?) session.setNow(wallClock());
  }

  // A handler's error is the host's bug and not the story's: reported, and
  // the rest of the batch still delivered.
  void _absorb(void Function() handler) {
    try {
      handler();
    } catch (error, stack) {
      _onError?.call(error, stack);
    }
  }

  void _dispatch(List<Effect> effects, {bool sameVisit = false}) {
    if (_disposed) return;
    // A batch with a Turn in it ends the visit, unless it is the same
    // passage shown again; one with none — a countdown begun — keeps it.
    if (effects.any((effect) => effect.isTurn)) {
      final shown = switch (effects.last) {
        Show(:final passage) => passage.timer,
        _ => null,
      };
      if (!sameVisit || shown == null) {
        _countdown = _countdowns && shown != null
            ? Countdown._(shown, begun: false, due: _clock() + shown.afterMs)
            : null;
      }
    }
    _delivering = true;
    try {
      for (final effect in effects) {
        if (_disposed) break;
        if (effect is Turn) _turn = effect;
        if (effect case Audio(:final command)) {
          if (_audio case final driver?) _absorb(() => driver.apply(command));
        }
        if (effect case Callback(:final event)) _fire(event);
        if (_onEffect case final onEffect?) _absorb(() => onEffect(effect));
      }
    } finally {
      _delivering = false;
    }
    if (effects.isNotEmpty && !_disposed && effects.last is Hold) {
      _holdDue = _clock() + (effects.last as Hold).ms;
    }
  }

  void _fire(CallbackEvent fired) {
    final handler = _callbacks[fired.callback];
    if (handler != null) {
      _absorb(() => handler(fired));
    } else {
      _callbackMisses++;
    }
    for (final each in List.of(_every)) {
      _absorb(() => each(fired));
    }
  }
}

/// A passage's countdown as a [Player] runs it: the [timer] the passage
/// carried, whether it has [begun], and when its next step is [due] by the
/// player's clock — its beginning, or, once begun, its end. A host that
/// draws it shows `due - now` while [begun] and the timer is
/// [ChoiceTimer.visible].
final class Countdown {
  const Countdown._(this.timer, {required this.begun, required this.due});

  final ChoiceTimer timer;
  final bool begun;
  final int due;
}
