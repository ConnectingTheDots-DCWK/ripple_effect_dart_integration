// What the bundle holds and what a verb answers, as records the engine's C
// structs are copied into. Nothing here points into the engine: a record
// outlives the call that made it, the session and the campaign. Times are
// milliseconds throughout.
import 'value.dart';

enum TrackMode { once, looping, auto }

enum PortKind { control, data }

/// One clip on a soundscape's timeline.
final class Track {
  const Track({
    required this.media,
    this.lane = 0,
    this.start = 0,
    this.clipStart = 0,
    this.clipEnd,
    this.volume = 1.0,
    this.speed = 1.0,
    this.fadeIn = 0,
    this.fadeOut = 0,
    this.mode = TrackMode.once,
    this.interval = 0,
  });

  /// The medium, by index into the manifest's media.
  final int media;
  final int lane;
  final int start;
  final int clipStart;
  final int? clipEnd;
  final double volume;
  final double speed;
  final int fadeIn;
  final int fadeOut;
  final TrackMode mode;
  final int interval;
}

/// A timeline of clips a passage plays.
final class Soundscape {
  const Soundscape({
    this.id = '',
    this.name = '',
    this.length = 0,
    this.looping = false,
    this.fadeIn = 0,
    this.fadeOut = 0,
    this.volume = 1.0,
    this.tied = false,
    this.tracks = const [],
  });

  final String id;
  final String name;
  final int length;
  final bool looping;
  final int fadeIn;
  final int fadeOut;
  final double volume;
  final bool tied;
  final List<Track> tracks;
}

final class Snippet {
  const Snippet(this.code, {required this.isInline});

  final String code;
  final bool isInline;
}

/// A row of one of the manifest's tables: a board, a passage, a medium…
final class Entry {
  const Entry(this.id, this.name, this.path);

  final String id;
  final String name;
  final String path;
}

final class Project {
  const Project({
    this.title = '',
    this.description = '',
    this.defaultLocale = '',
    this.locales = const [],
    this.cover,
  });

  final String title;
  final String description;
  final String defaultLocale;
  final List<String> locales;
  final String? cover;
}

/// A console variable the campaign declares.
final class Cvar {
  const Cvar(this.name, this.type, this.defaultValue);

  final String name;
  final String type;
  final Value defaultValue;
}

/// `campaign.json`: what the bundle holds, table by table.
final class Manifest {
  const Manifest({
    required this.format,
    this.generator,
    required this.textFormat,
    required this.project,
    required this.entries,
    required this.boards,
    required this.passages,
    required this.components,
    required this.scripts,
    required this.media,
    required this.machines,
    required this.soundscapes,
    required this.cvars,
    required this.needs,
    this.permissions = const [],
  });

  final int format;
  final String? generator;

  /// `markdown`, or `html`: what a passage's text is written in.
  final String textFormat;
  final Project project;

  /// The boards a story may begin on, by index into [boards].
  final List<int> entries;
  final List<Entry> boards;
  final List<Entry> passages;
  final List<Entry> components;
  final List<Entry> scripts;
  final List<Entry> media;
  final List<Entry> machines;
  final List<Entry> soundscapes;
  final List<Cvar> cvars;

  /// What the campaign needs of its host: `python`, when it runs scripts.
  final List<String> needs;

  /// What the story reads of the world outside it, by wire name —
  /// `dateTime`, `location` ([PermissionKind.wire]). The compiler lists
  /// them, and a session asks about each before the story begins.
  final List<String> permissions;
}

final class Edge {
  const Edge(this.node, this.port);

  final int node;
  final int port;
}

final class Port {
  const Port(this.id, this.kind, this.edges);

  final String id;
  final PortKind kind;
  final List<Edge> edges;
}

final class Node {
  const Node({
    required this.id,
    required this.type,
    required this.title,
    required this.inputs,
    required this.outputs,
    required this.data,
    required this.metadata,
  });

  final String id;
  final String type;
  final String title;
  final List<Port> inputs;
  final List<Port> outputs;
  final Value data;
  final Value metadata;
}

final class Board {
  const Board({
    required this.id,
    required this.name,
    required this.start,
    required this.prime,
    required this.nodes,
  });

  final String id;
  final String name;
  final int start;
  final List<int> prime;
  final List<Node> nodes;
}

final class BundleProblem {
  const BundleProblem(this.message, this.location);

  final String message;
  final String location;

  @override
  String toString() => '$location: $message';
}

/// One choice a passage offers. [available] is false for a choice the
/// author limited and the reader used up.
final class Choice {
  const Choice(this.port, this.text, {required this.available});

  final String port;
  final String text;
  final bool available;
}

final class LocaleText {
  const LocaleText(this.locale, this.text);

  final String locale;
  final String text;
}

/// A link in a passage's prose and the medium it names, by index into the
/// manifest's media.
final class MediaLink {
  const MediaLink(this.link, this.media);

  final String link;
  final int media;
}

/// A passage's countdown — `campaign-host-api.md` §4b. The host's clock
/// waits [afterMs] and calls `beginCountdown`, waits [timeoutMs] and calls
/// `expire`; the engine measures none of it. `Player` does both when asked.
final class ChoiceTimer {
  const ChoiceTimer({
    required this.afterMs,
    required this.timeoutMs,
    required this.visible,
    required this.defaultChoice,
  });

  /// How long before the countdown begins; zero is at once.
  final int afterMs;

  /// How long it runs once begun; never zero.
  final int timeoutMs;

  /// Whether the author meant the reader to see it count.
  final bool visible;

  /// The index into the passage's choices taken when it runs out.
  final int defaultChoice;
}

/// A passage the reader is on.
final class Passage {
  const Passage({
    required this.node,
    required this.title,
    required this.text,
    required this.choices,
    this.sources,
    required this.snippets,
    required this.media,
    this.untranslated,
    this.soundscape,
    required this.silence,
    this.timer,
  });

  final String node;
  final String title;

  /// Markdown, or HTML when the manifest's [Manifest.textFormat] says so.
  final String text;
  final List<Choice> choices;
  final List<LocaleText>? sources;
  final List<Snippet> snippets;
  final List<MediaLink> media;

  /// The locale this passage fell back from, when it has no translation.
  final String? untranslated;
  final Soundscape? soundscape;
  final bool silence;

  /// The passage's countdown; null when it waits for the reader for as long
  /// as they like. A re-rendered passage — `setLocale` — is the same visit,
  /// with the same countdown.
  final ChoiceTimer? timer;
}

/// One fixed answer a form field offers.
final class PromptOption {
  const PromptOption(this.id, this.label, this.value);

  /// What a host answers with; stable across languages.
  final String id;

  /// What the reader is shown, in the reader's language.
  final String label;

  /// What the story is handed when it is picked, of the field's type.
  final Value value;
}

/// One field of a form. [name] is its ID, what an answer is keyed by;
/// [label] is what the reader is shown.
final class PromptField {
  const PromptField(
    this.name,
    this.type,
    this.defaultValue, {
    this.label = '',
    this.placeholder = '',
    this.optional = false,
    this.options = const [],
  });

  final String name;
  final String type;

  /// What the control is filled in with: a default nobody edits is the
  /// answer. Null for a field that declares none.
  final Value defaultValue;

  /// What the reader is shown for the field, in the reader's language —
  /// [name] where the author wrote nothing.
  final String label;

  /// The hint drawn while the field is empty; empty for none. Never the
  /// answer.
  final String placeholder;

  /// Whether the reader may leave the field empty, which answers null. A
  /// required field is not submitted empty: a host keeps the form open.
  final bool optional;

  /// The fixed answers the reader picks from, in order: one for a scalar
  /// type, any number for a `…List`. Empty for a field the reader types
  /// into. Answer with the picked options' [PromptOption.id]s, never their
  /// labels or values.
  final List<PromptOption> options;
}

/// A form the story asks the reader to fill.
final class Prompt {
  const Prompt(this.node, this.title, this.fields);

  final String node;
  final String title;
  final List<PromptField> fields;
}

/// The soundscape in force, and the node that set it.
final class Ambience {
  const Ambience(this.soundscape, this.board, this.node);

  final Soundscape soundscape;
  final int board;
  final String node;
}

enum RunEventKind {
  runStarted,
  nodeStarted,
  nodeFinished,
  memoHit,
  diagnostic,
  log,
  runFinished,
}

enum PayloadKind { present, withheld, absent }

/// What a story may read of the world outside it (ADR
/// *a-campaign-asks-before-it-reads*), in the C header's order. The
/// microphone is not one.
enum PermissionKind {
  dateTime('dateTime'),
  location('location');

  const PermissionKind(this.wire);

  /// The name the manifest's `permissions` and a stand-in's failure use.
  final String wire;

  /// The kind [wire] names, or null for one this binding does not know.
  static PermissionKind? fromWire(String wire) {
    for (final kind in values) {
      if (kind.wire == wire) return kind;
    }
    return null;
  }
}

/// An instant from the host: milliseconds since the epoch, and the offset in
/// minutes the reader's wall clock is at. What `datetime.now()` answers in a
/// story, once the reader allowed [PermissionKind.dateTime].
final class Moment {
  const Moment(this.utcMs, this.offsetMinutes);

  /// [time] as an instant, at its own offset: a local [DateTime] keeps the
  /// zone the program runs in, a UTC one is at zero.
  Moment.of(DateTime time)
    : utcMs = time.millisecondsSinceEpoch,
      offsetMinutes = time.timeZoneOffset.inMinutes;

  /// Now, on this machine's clock and in its zone.
  factory Moment.now() => Moment.of(DateTime.now());

  final int utcMs;
  final int offsetMinutes;

  @override
  bool operator ==(Object other) =>
      other is Moment &&
      other.utcMs == utcMs &&
      other.offsetMinutes == offsetMinutes;

  @override
  int get hashCode => Object.hash(utcMs, offsetMinutes);
}

/// A position fix, any field of which may be absent — shaped after the
/// web's `GeolocationPosition`, as `location_get()` hands it to a story.
final class Position {
  const Position({
    this.label,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.when,
  });

  /// A place's name, when the fix has one.
  final String? label;
  final double? latitude;
  final double? longitude;

  /// In metres.
  final double? accuracy;

  /// When the fix was taken.
  final Moment? when;
}

final class TraceValue {
  const TraceValue({
    required this.fromNode,
    required this.fromPort,
    this.toNode,
    this.toPort,
    required this.payload,
    required this.value,
  });

  final String fromNode;
  final String fromPort;
  final String? toNode;
  final String? toPort;
  final PayloadKind payload;

  /// Set when [payload] is [PayloadKind.present].
  final Value value;
}

final class RunDiagnostic {
  const RunDiagnostic({
    required this.issue,
    required this.message,
    this.node,
    this.port,
    this.wires,
  });

  /// A `RippleRunIssue`.
  final int issue;
  final String message;
  final String? node;
  final String? port;
  final int? wires;
}

/// One event of the run's trace, read by [kind] as `RippleRunEvent` is.
final class RunEvent {
  const RunEvent({
    required this.kind,
    required this.run,
    required this.board,
    required this.sequence,
    required this.node,
    required this.step,
    required this.entry,
    required this.primed,
    this.enteredVia,
    required this.pulled,
    required this.inputs,
    required this.outcome,
    required this.outputs,
    required this.flowed,
    this.error,
    this.diagnostic,
    required this.level,
    required this.message,
    this.data,
    required this.steps,
    required this.cancelled,
    this.failedNode,
  });

  final RunEventKind kind;
  final int run;
  final int board;
  final int sequence;
  final String node;
  final int step;
  final String entry;
  final List<String> primed;
  final String? enteredVia;
  final bool pulled;
  final List<TraceValue> inputs;

  /// A `RippleTurnOutcome`.
  final int outcome;
  final List<TraceValue> outputs;
  final List<String> flowed;
  final String? error;
  final RunDiagnostic? diagnostic;

  /// A `RippleLogLevel`.
  final int level;
  final String message;
  final Value? data;
  final int steps;
  final bool cancelled;
  final String? failedNode;
}

/// A named callback the author declared, fired — `campaign-host-api.md` §5b.
final class CallbackEvent {
  const CallbackEvent({
    required this.callback,
    required this.event,
    required this.eventName,
    this.board,
    this.node,
    this.name,
    this.from,
    this.to,
    this.index,
  });

  /// The name the author gave it, which a handler is registered by.
  final String callback;

  /// A `RippleCallbackKind`; [eventName] spells it.
  final int event;

  /// The event in the author's vocabulary: `cvar.changed`.
  final String eventName;
  final int? board;
  final String? node;
  final String? name;
  final Value? from;
  final Value? to;
  final int? index;
}

final class Entity {
  const Entity({
    required this.key,
    this.component,
    required this.label,
    required this.values,
  });

  final String key;
  final String? component;
  final String label;

  /// A map, field by field.
  final Value values;
}

final class Memory {
  const Memory(this.nodes, this.machines);

  /// A map, node by node.
  final Value nodes;

  /// Each state machine and the state it is in, in order.
  final List<(String machine, String state)> machines;
}

final class CvarSnapshot {
  const CvarSnapshot(this.name, this.type, this.defaultValue, this.value);

  final String name;
  final String type;
  final Value defaultValue;
  final Value value;
}

enum AudioKind { play, stop, cut, cue }

/// What the session asks the speaker — for `SoundscapeDriver.apply`.
final class AudioCommand {
  const AudioCommand({
    required this.kind,
    this.soundscape,
    this.fadeMs = 0,
    this.media = 0,
    this.volume = 1.0,
    this.speed = 1.0,
    this.node,
  });

  final AudioKind kind;

  /// Play: what to play.
  final Soundscape? soundscape;

  /// Play: the fade-in; stop: the fade-out.
  final int fadeMs;

  /// Cue: the medium, by index into the manifest's media.
  final int media;
  final double volume;
  final double speed;
  final String? node;
}

/// What a script came to, when it failed.
final class PythonFailure {
  const PythonFailure({
    required this.kind,
    this.exception,
    required this.message,
    this.line,
    this.traceback,
  });

  /// A `RipplePythonFailureKind`.
  final int kind;
  final String? exception;
  final String message;
  final int? line;
  final String? traceback;
}

final class PythonResult {
  const PythonResult(this.value, this.output, this.error);

  final Value value;
  final String output;
  final PythonFailure? error;
}
