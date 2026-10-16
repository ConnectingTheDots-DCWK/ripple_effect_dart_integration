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
/// player answers a hold the frame its time comes.
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
  Player(
    this.session, {
    void Function(Effect effect)? onEffect,
    void Function(Object error, StackTrace stack)? onError,
    SoundscapeDriver? audio,
    Clock? now,
  }) : _onEffect = onEffect,
       _onError = onError,
       _audio = audio,
       _clock = now ?? Clocks.steady();

  /// The session underneath, for what the player does not wrap. A verb
  /// called on it goes round the player.
  final Session session;

  final void Function(Effect effect)? _onEffect;
  final void Function(Object error, StackTrace stack)? _onError;
  final SoundscapeDriver? _audio;
  final Clock _clock;
  final Map<String, void Function(CallbackEvent)> _callbacks = {};
  final List<void Function(CallbackEvent)> _every = [];
  bool _delivering = false;
  bool _disposed = false;

  /// Where the story is: the last Turn delivered.
  Turn? get turn => _turn;
  Turn? _turn;

  /// When the pending hold is due, by the player's clock; null when none is.
  int? get holdDue => _holdDue;
  int? _holdDue;

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

  void setLocale(String locale) =>
      _verb('setLocale', () => session.setLocale(locale));

  void restart() => _verb('restart', session.restart);

  void stop() => _verb('stop', session.stop);

  /// Puts the story down and answers its save — null, and nothing stopped,
  /// unless the story is on a passage or a prompt.
  String? pause() {
    if (_delivering) throw _reentrant('pause');
    _holdDue = null;
    final paused = session.pause();
    _dispatch(paused.effects);
    return paused.save;
  }

  /// What the host calls from its loop: answers a hold whose time has come.
  void update() {
    final due = _holdDue;
    if (due == null || _clock() < due || _delivering) return;
    _holdDue = null;
    final List<Effect> next;
    try {
      next = session.elapsed();
    } on RippleException catch (error, stack) {
      final onError = _onError;
      if (onError == null) rethrow;
      onError(error, stack);
      return;
    }
    _dispatch(next);
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

  void _verb(String name, List<Effect> Function() run) {
    if (_delivering) throw _reentrant(name);
    if (_disposed) return;
    _holdDue = null;
    _dispatch(run());
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

  void _dispatch(List<Effect> effects) {
    if (_disposed) return;
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
