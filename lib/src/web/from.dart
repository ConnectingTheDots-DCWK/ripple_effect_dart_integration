// The component's answers copied into this binding's records — the web's
// twin of native/from.dart, reading jco's objects where that one reads C
// structs, and giving every field the value a native host would read: an
// enum by the C header's number, a name by the header's spelling.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../effects.dart';
import '../mixer_types.dart';
import '../records.dart';
import '../session_types.dart';
import '../speaker.dart';
import '../value.dart';
import 'js.dart';
import 'tables.dart';

extension on JSAny? {
  JSAny? operator [](String key) =>
      (this! as JSObject).getProperty<JSAny?>(key.toJS);
}

/// A WIT `value`: its arena of nodes, the root first. A child that is not
/// after its parent, or past the end, reads as null — the engine's rule.
Value value(JSAny? arena) {
  final nodes = (arena['nodes']! as JSArray<JSAny?>).toDart;
  Value node(int at) {
    if (at >= nodes.length) return const NullValue();
    final n = nodes[at];
    Value child(int of) =>
        of > at && of < nodes.length ? node(of) : const NullValue();
    return switch (tagOf(n)) {
      'boolean' => BoolValue(flag(valOf(n))),
      'int' => IntValue(wide(valOf(n))),
      'float' => FloatValue(real(valOf(n))),
      'text' => TextValue(str(valOf(n))),
      'items' => ListValue([for (final i in indices(valOf(n))) child(i)]),
      'entries' => MapValue({
        for (final pair in (valOf(n)! as JSArray<JSArray<JSAny?>>).toDart)
          str(pair.toDart[0]): child(num(pair.toDart[1])),
      }),
      _ => const NullValue(),
    };
  }

  return node(0);
}

Value? valueOr(JSAny? arena) => arena == null ? null : value(arena);

Track track(JSAny? t) => Track(
  media: wide(t['media']),
  lane: wide(t['lane']),
  start: wide(t['start']),
  clipStart: wide(t['clipStart']),
  clipEnd: wideOr(t['clipEnd']),
  volume: real(t['volume']),
  speed: real(t['speed']),
  fadeIn: wide(t['fadeIn']),
  fadeOut: wide(t['fadeOut']),
  mode: TrackMode.values.byName(str(t['mode'])),
  interval: wide(t['interval']),
);

Soundscape soundscape(JSAny? s) => Soundscape(
  id: str(s['id']),
  name: str(s['name']),
  length: wide(s['length']),
  looping: flag(s['looping']),
  fadeIn: wide(s['fadeIn']),
  fadeOut: wide(s['fadeOut']),
  volume: real(s['volume']),
  tied: flag(s['tied']),
  tracks: List.unmodifiable(list(s['tracks'], track)),
);

Entry entry(JSAny? e) => Entry(str(e['id']), str(e['name']), str(e['path']));

List<Entry> _entries(JSAny? items) => List.unmodifiable(list(items, entry));

Manifest manifest(JSAny? m) => Manifest(
  format: wide(m['format']),
  generator: strOr(m['generator']),
  textFormat: str(m['textFormat']),
  project: Project(
    title: str(m['project']['title']),
    description: str(m['project']['description']),
    defaultLocale: str(m['project']['defaultLocale']),
    locales: List.unmodifiable(list(m['project']['locales'], str)),
    cover: strOr(m['project']['cover']),
  ),
  entries: indices(m['entries']),
  boards: _entries(m['boards']),
  passages: _entries(m['passages']),
  components: _entries(m['components']),
  scripts: _entries(m['scripts']),
  media: _entries(m['media']),
  machines: _entries(m['machines']),
  soundscapes: _entries(m['soundscapes']),
  cvars: List.unmodifiable(
    list(
      m['cvars'],
      (c) => Cvar(str(c['name']), str(c['type']), value(c['default'])),
    ),
  ),
  needs: List.unmodifiable(list(m['needs'], str)),
);

Port _port(JSAny? p) => Port(
  str(p['id']),
  PortKind.values.byName(str(p['kind'])),
  List.unmodifiable(
    list(p['edges'], (e) => Edge(wide(e['node']), wide(e['port']))),
  ),
);

Node node(JSAny? n) => Node(
  id: str(n['id']),
  type: str(n['type']),
  title: str(n['title']),
  inputs: List.unmodifiable(list(n['inputs'], _port)),
  outputs: List.unmodifiable(list(n['outputs'], _port)),
  data: value(n['data']),
  metadata: value(n['metadata']),
);

Board board(JSAny? b) => Board(
  id: str(b['id']),
  name: str(b['name']),
  start: wide(b['start']),
  prime: indices(b['prime']),
  nodes: List.unmodifiable(list(b['nodes'], node)),
);

List<String> _pair(JSAny? pair) => [
  for (final item in (pair! as JSArray<JSAny?>).toDart)
    item.isA<JSString>()
        ? (item! as JSString).toDart
        : '${(item! as JSNumber).toDartInt}',
];

Passage passage(JSAny? p) => Passage(
  node: str(p['node']),
  title: str(p['title']),
  text: str(p['text']),
  choices: List.unmodifiable(
    list(
      p['choices'],
      (c) => Choice(
        str(c['port']),
        str(c['text']),
        available: flag(c['available']),
      ),
    ),
  ),
  sources: p['source'] == null
      ? null
      : List.unmodifiable(
          list(p['source'], (s) {
            final pair = _pair(s);
            return LocaleText(pair[0], pair[1]);
          }),
        ),
  snippets: List.unmodifiable(
    list(
      p['snippets'],
      (s) => Snippet(str(s['code']), isInline: flag(s['isInline'])),
    ),
  ),
  media: List.unmodifiable(
    list(p['media'], (m) {
      final pair = _pair(m);
      return MediaLink(pair[0], int.parse(pair[1]));
    }),
  ),
  untranslated: strOr(p['untranslated']),
  soundscape: p['soundscape'] == null ? null : soundscape(p['soundscape']),
  silence: flag(p['silence']),
);

Prompt prompt(JSAny? p) => Prompt(
  str(p['node']),
  str(p['title']),
  List.unmodifiable(
    list(
      p['fields'],
      (f) => PromptField(str(f['name']), str(f['type']), value(f['default'])),
    ),
  ),
);

Ambience ambience(JSAny? a) =>
    Ambience(soundscape(a['soundscape']), num(a['board']), str(a['node']));

List<TraceValue> _traced(JSAny? items) => List.unmodifiable(
  list(items, (t) {
    final payload = PayloadKind.values.byName(tagOf(t['payload']));
    return TraceValue(
      fromNode: str(t['fromNode']),
      fromPort: str(t['fromPort']),
      toNode: strOr(t['toNode']),
      toPort: strOr(t['toPort']),
      payload: payload,
      value: payload == PayloadKind.present
          ? value(valOf(t['payload']))
          : const NullValue(),
    );
  }),
);

/// A run event, flattened into the one record native hosts read: the fields
/// its kind does not carry are their C defaults — empty, zero, false.
RunEvent runEvent(JSAny? e) {
  final tag = tagOf(e);
  final v = valOf(e);
  final at = v['at'];
  final diagnostic = tag == 'diagnostic' ? v['diagnostic'] : null;
  return RunEvent(
    kind: RunEventKind.values[runEventKinds.indexOf(tag)],
    run: num(at['run']),
    board: num(at['board']),
    sequence: num(at['sequence']),
    node: strOr(v['node']) ?? '',
    step: numOr(v['step']) ?? 0,
    entry: strOr(v['entry']) ?? '',
    primed: v['primed'] == null
        ? const []
        : List.unmodifiable(list(v['primed'], str)),
    enteredVia: strOr(v['enteredVia']),
    pulled: v['pulled'] == null ? false : flag(v['pulled']),
    inputs: v['inputs'] == null ? const [] : _traced(v['inputs']),
    outcome: v['outcome'] == null ? 0 : turnOutcomes.indexOf(str(v['outcome'])),
    outputs: v['outputs'] == null ? const [] : _traced(v['outputs']),
    flowed: v['flowed'] == null
        ? const []
        : List.unmodifiable(list(v['flowed'], str)),
    error: strOr(v['error']),
    diagnostic: diagnostic == null
        ? null
        : RunDiagnostic(
            issue: runIssues.indexOf(str(diagnostic['issue'])),
            message: str(diagnostic['message']),
            node: strOr(diagnostic['node']),
            port: strOr(diagnostic['port']),
            wires: numOr(diagnostic['wires']),
          ),
    level: v['level'] == null ? 0 : logLevels.indexOf(str(v['level'])),
    message: strOr(v['message']) ?? '',
    data: valueOr(v['data']),
    steps: numOr(v['steps']) ?? 0,
    cancelled: v['cancelled'] == null ? false : flag(v['cancelled']),
    failedNode: strOr(v['failedNode']),
  );
}

CallbackEvent callbackEvent(JSAny? c) {
  final kind = str(c['event']);
  return CallbackEvent(
    callback: str(c['callback']),
    event: callbackKinds.indexOf(kind),
    eventName: kind.replaceAll('-', '.'),
    board: numOr(c['board']),
    node: strOr(c['node']),
    name: strOr(c['name']),
    from: valueOr(c['from']),
    to: valueOr(c['to']),
    index: numOr(c['index']),
  );
}

Entity entity(JSAny? e) => Entity(
  key: str(e['key']),
  component: strOr(e['component']),
  label: str(e['label']),
  values: value(e['values']),
);

Memory memory(JSAny? m) => Memory(
  value(m['nodes']),
  List.unmodifiable(
    list(m['machines'], (s) {
      final pair = _pair(s);
      return (pair[0], pair[1]);
    }),
  ),
);

CvarSnapshot cvarSnapshot(JSAny? c) => CvarSnapshot(
  str(c['name']),
  str(c['type']),
  value(c['default']),
  value(c['value']),
);

AudioCommand audio(JSAny? a) {
  final v = valOf(a);
  return switch (tagOf(a)) {
    'play' => AudioCommand(
      kind: AudioKind.play,
      soundscape: soundscape(v['soundscape']),
      fadeMs: wide(v['fadeInMs']),
    ),
    'stop' => AudioCommand(kind: AudioKind.stop, fadeMs: wide(v)),
    'cue' => AudioCommand(
      kind: AudioKind.cue,
      media: num(v['media']),
      volume: real(v['volume']),
      speed: real(v['speed']),
      node: strOr(v['node']),
    ),
    _ => const AudioCommand(kind: AudioKind.cut),
  };
}

Effect effect(JSAny? e) {
  final v = valOf(e);
  return switch (tagOf(e)) {
    'trace' => Trace(runEvent(v)),
    'callback' => Callback(callbackEvent(v)),
    'jumped' => Jumped(num(v['board']), strOr(v['node'])),
    'ambience' => AmbienceChanged(v == null ? null : ambience(v)),
    'audio' => Audio(audio(v)),
    'changed' => Changed(
      entities: v['entities'] == null
          ? null
          : List.unmodifiable(list(v['entities'], entity)),
      memory: v['memory'] == null ? null : memory(v['memory']),
      cvars: v['cvars'] == null
          ? null
          : List.unmodifiable(list(v['cvars'], cvarSnapshot)),
    ),
    'show' => Show(passage(v)),
    'ask' => Ask(prompt(v)),
    'hold' => Hold(wide(v)),
    'ended' => Ended(strOr(v['title']), ranOut: flag(v['ranOut'])),
    'failed' => Failed(str(v['message']), strOr(v['node'])),
    _ => const Stopped(),
  };
}

List<Effect> effects(JSAny? items) => List.unmodifiable(list(items, effect));

PythonResult python(JSAny? r) {
  final error = r['error'];
  return PythonResult(
    value(r['value']),
    str(r['output']),
    error == null
        ? null
        : PythonFailure(
            kind: pythonFailureKinds.indexOf(tagOf(error['kind'])),
            exception: tagOf(error['kind']) == 'python'
                ? strOr(valOf(error['kind']))
                : null,
            message: str(error['message']),
            line: numOr(error['line']),
            traceback: strOr(error['traceback']),
          ),
  );
}

GuardReport guard(JSAny? g) => GuardReport(
  List.unmodifiable(list(g['abandoned'], str)),
  num(g['refused']),
  exhausted: flag(g['exhausted']),
);

VoiceCommand voiceCommand(JSAny? c) {
  final v = valOf(c);
  return switch (tagOf(c)) {
    'open' => VoiceCommand(
      kind: VoiceKind.open,
      voice: wide(v['voice']),
      media: num(v['media']),
      fromMs: wide(v['fromMs']),
      toMs: wideOr(v['toMs']),
      gain: real(v['gain']),
      rate: real(v['rate']),
      looping: flag(v['looping']),
      loopFromMs: wide(v['loopFromMs']),
      role: tagOf(v['role']) == 'cue' ? VoiceRole.cue : VoiceRole.track,
      track: tagOf(v['role']) == 'cue' ? 0 : num(valOf(v['role'])),
    ),
    'gain' => VoiceCommand(
      kind: VoiceKind.gain,
      voice: wide(v['voice']),
      gain: real(v['gain']),
    ),
    'stop' => VoiceCommand(kind: VoiceKind.stop, voice: wide(v)),
    'pause' => const VoiceCommand(kind: VoiceKind.pause, voice: 0),
    _ => const VoiceCommand(kind: VoiceKind.resume, voice: 0),
  };
}
