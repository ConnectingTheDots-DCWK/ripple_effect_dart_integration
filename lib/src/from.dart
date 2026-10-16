// The engine's structs copied into this binding's records. Every reader here
// copies: nothing it answers points into memory the engine owns, so the
// batch can be freed the moment it is read.
import 'dart:ffi';

import 'effects.dart';
import 'internal.dart';
import 'interop/ripple.g.dart';
import 'records.dart';
import 'value.dart';

Track track(RippleTrack t) => Track(
  media: t.media,
  lane: t.lane,
  start: t.start,
  clipStart: t.clip_start,
  clipEnd: readI64(t.clip_end),
  volume: t.volume,
  speed: t.speed,
  fadeIn: t.fade_in,
  fadeOut: t.fade_out,
  mode: TrackMode.values[t.mode],
  interval: t.interval,
);

Soundscape soundscape(RippleSoundscape s) => Soundscape(
  id: readStr(s.id),
  name: readStr(s.name),
  length: s.length,
  looping: s.looping,
  fadeIn: s.fade_in,
  fadeOut: s.fade_out,
  volume: s.volume,
  tied: s.tied,
  tracks: readList(s.tracks, s.track_count, (i) => track(s.tracks[i])),
);

Entry entry(RippleEntry e) =>
    Entry(readStr(e.id), readStr(e.name), readStr(e.path));

List<Entry> _entries(Pointer<RippleEntry> items, int count) =>
    readList(items, count, (i) => entry(items[i]));

Manifest manifest(RippleManifest m) => Manifest(
  format: m.format,
  generator: readStrOr(m.generator),
  textFormat: readStr(m.text_format),
  project: Project(
    title: readStr(m.project.title),
    description: readStr(m.project.description),
    defaultLocale: readStr(m.project.default_locale),
    locales: readTexts(m.project.locales, m.project.locale_count),
    cover: readStrOr(m.project.cover),
  ),
  entries: readIndices(m.entries, m.entry_count),
  boards: _entries(m.boards, m.board_count),
  passages: _entries(m.passages, m.passage_count),
  components: _entries(m.components, m.component_count),
  scripts: _entries(m.scripts, m.script_count),
  media: _entries(m.media, m.media_count),
  machines: _entries(m.machines, m.machine_count),
  soundscapes: _entries(m.soundscapes, m.soundscape_count),
  cvars: readList(m.cvars, m.cvar_count, (i) {
    final c = m.cvars[i];
    return Cvar(
      readStr(c.name),
      readStr(c.type_name),
      readValue(c.default_value),
    );
  }),
  needs: readTexts(m.needs, m.need_count),
);

Port _port(RipplePort p) => Port(
  readStr(p.id),
  PortKind.values[p.kind],
  readList(
    p.edges,
    p.edge_count,
    (i) => Edge(p.edges[i].node, p.edges[i].port),
  ),
);

Node node(RippleNode n) => Node(
  id: readStr(n.id),
  type: readStr(n.type_name),
  title: readStr(n.title),
  inputs: readList(n.inputs, n.input_count, (i) => _port(n.inputs[i])),
  outputs: readList(n.outputs, n.output_count, (i) => _port(n.outputs[i])),
  data: readValue(n.data),
  metadata: readValue(n.metadata),
);

Board board(RippleBoard b) => Board(
  id: readStr(b.id),
  name: readStr(b.name),
  start: b.start,
  prime: readIndices(b.prime, b.prime_count),
  nodes: readList(b.nodes, b.node_count, (i) => node(b.nodes[i])),
);

Passage passage(RipplePassage p) => Passage(
  node: readStr(p.node),
  title: readStr(p.title),
  text: readStr(p.text),
  choices: readList(p.choices, p.choice_count, (i) {
    final c = p.choices[i];
    return Choice(readStr(c.port), readStr(c.text), available: c.available);
  }),
  sources: p.has_sources
      ? readList(p.sources, p.source_count, (i) {
          final s = p.sources[i];
          return LocaleText(readStr(s.locale), readStr(s.text));
        })
      : null,
  snippets: readList(p.snippets, p.snippet_count, (i) {
    final s = p.snippets[i];
    return Snippet(readStr(s.code), isInline: s.is_inline);
  }),
  media: readList(p.media, p.media_count, (i) {
    final l = p.media[i];
    return MediaLink(readStr(l.link), l.media);
  }),
  untranslated: readStrOr(p.untranslated),
  soundscape: p.soundscape == nullptr ? null : soundscape(p.soundscape.ref),
  silence: p.silence,
);

Prompt prompt(RipplePrompt p) => Prompt(
  readStr(p.node),
  readStr(p.title),
  readList(p.fields, p.field_count, (i) {
    final f = p.fields[i];
    return PromptField(
      readStr(f.name),
      readStr(f.type_name),
      readValue(f.default_value),
    );
  }),
);

Ambience ambience(RippleAmbience a) =>
    Ambience(soundscape(a.soundscape), a.board, readStr(a.node));

List<TraceValue> _traced(Pointer<RippleTraceValue> items, int count) =>
    readList(items, count, (i) {
      final t = items[i];
      final payload = PayloadKind.values[t.payload];
      return TraceValue(
        fromNode: readStr(t.from_node),
        fromPort: readStr(t.from_port),
        toNode: readStrOr(t.to_node),
        toPort: readStrOr(t.to_port),
        payload: payload,
        value: payload == PayloadKind.present
            ? readValue(t.value)
            : const NullValue(),
      );
    });

RunEvent runEvent(RippleRunEvent e) => RunEvent(
  kind: RunEventKind.values[e.kind],
  run: e.at.run,
  board: e.at.board,
  sequence: e.at.sequence,
  node: readStr(e.node),
  step: e.step,
  entry: readStr(e.entry),
  primed: readTexts(e.primed, e.primed_count),
  enteredVia: readStrOr(e.entered_via),
  pulled: e.pulled,
  inputs: _traced(e.inputs, e.input_count),
  outcome: e.outcome,
  outputs: _traced(e.outputs, e.output_count),
  flowed: readTexts(e.flowed, e.flowed_count),
  error: readStrOr(e.error),
  diagnostic: e.diagnostic == nullptr
      ? null
      : RunDiagnostic(
          issue: e.diagnostic.ref.issue,
          message: readStr(e.diagnostic.ref.message),
          node: readStrOr(e.diagnostic.ref.node),
          port: readStrOr(e.diagnostic.ref.port),
          wires: readU32(e.diagnostic.ref.wires),
        ),
  level: e.level,
  message: readStr(e.message),
  data: readValueOr(e.data),
  steps: e.steps,
  cancelled: e.cancelled,
  failedNode: readStrOr(e.failed_node),
);

CallbackEvent callbackEvent(RippleCallbackEvent c) => CallbackEvent(
  callback: readStr(c.callback),
  event: c.event,
  eventName: readCStr(ripple_callback_kind_name(c.event)),
  board: readU32(c.board),
  node: readStrOr(c.node),
  name: readStrOr(c.name),
  from: readValueOr(c.from),
  to: readValueOr(c.to),
  index: readU32(c.index),
);

Entity entity(RippleEntity e) => Entity(
  key: readStr(e.key),
  component: readStrOr(e.component),
  label: readStr(e.label),
  values: readValue(e.values),
);

Memory memory(RippleMemory m) => Memory(
  readValue(m.nodes),
  readList(m.machines, m.machine_count, (i) {
    final s = m.machines[i];
    return (readStr(s.machine), readStr(s.state));
  }),
);

CvarSnapshot cvarSnapshot(RippleCvarSnapshot c) => CvarSnapshot(
  readStr(c.name),
  readStr(c.type_name),
  readValue(c.default_value),
  readValue(c.value),
);

AudioCommand audio(RippleAudioCommand a) => AudioCommand(
  kind: AudioKind.values[a.kind],
  soundscape: a.soundscape == nullptr ? null : soundscape(a.soundscape.ref),
  fadeMs: a.fade_ms,
  media: a.media,
  volume: a.volume,
  speed: a.speed,
  node: readStrOr(a.node),
);

Effect effect(RippleEffect e) {
  final data = e.data;
  return switch (RippleEffectKind.fromValue(e.kind)) {
    RippleEffectKind.RIPPLE_EFFECT_KIND_TRACE => Trace(
      runEvent(data.trace.ref),
    ),
    RippleEffectKind.RIPPLE_EFFECT_KIND_CALLBACK => Callback(
      callbackEvent(data.callback.ref),
    ),
    RippleEffectKind.RIPPLE_EFFECT_KIND_JUMPED => Jumped(
      data.jumped.ref.board,
      readStrOr(data.jumped.ref.node),
    ),
    RippleEffectKind.RIPPLE_EFFECT_KIND_AMBIENCE => AmbienceChanged(
      data.ambience == nullptr ? null : ambience(data.ambience.ref),
    ),
    RippleEffectKind.RIPPLE_EFFECT_KIND_AUDIO => Audio(audio(data.audio.ref)),
    RippleEffectKind.RIPPLE_EFFECT_KIND_CHANGED => _changed(data.changed.ref),
    RippleEffectKind.RIPPLE_EFFECT_KIND_SHOW => Show(passage(data.show.ref)),
    RippleEffectKind.RIPPLE_EFFECT_KIND_ASK => Ask(prompt(data.ask.ref)),
    RippleEffectKind.RIPPLE_EFFECT_KIND_HOLD => Hold(data.hold_ms),
    RippleEffectKind.RIPPLE_EFFECT_KIND_ENDED => Ended(
      readStrOr(data.ended.ref.title),
      ranOut: data.ended.ref.ran_out,
    ),
    RippleEffectKind.RIPPLE_EFFECT_KIND_FAILED => Failed(
      readStr(data.failed.ref.message),
      readStrOr(data.failed.ref.node),
    ),
    _ => const Stopped(),
  };
}

Changed _changed(RippleChanged c) => Changed(
  entities: c.has_entities
      ? readList(c.entities, c.entity_count, (i) => entity(c.entities[i]))
      : null,
  memory: c.memory == nullptr ? null : memory(c.memory.ref),
  cvars: c.has_cvars
      ? readList(c.cvars, c.cvar_count, (i) => cvarSnapshot(c.cvars[i]))
      : null,
);

List<Effect> effects(Pointer<RippleEffect> items, int count) =>
    readList(items, count, (i) => effect(items[i]));

PythonResult python(RipplePythonResult r) => PythonResult(
  readValue(r.value),
  readStr(r.output),
  r.error == nullptr
      ? null
      : PythonFailure(
          kind: r.error.ref.kind,
          exception: readStrOr(r.error.ref.exception),
          message: readStr(r.error.ref.message),
          line: readU32(r.error.ref.line),
          traceback: readStrOr(r.error.ref.traceback),
        ),
);
