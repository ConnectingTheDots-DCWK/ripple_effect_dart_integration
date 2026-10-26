// AUTO GENERATED FILE, DO NOT EDIT: tool/generate/bin/generate.dart.
// ignore_for_file: type=lint
import 'dart:ffi' as ffi;

import 'package:ripplefx_engine/src/interop/ripple.g.dart';

/// Every generated record with fields: its size, and a probe per field
/// with the offset clang gave that field's first scalar byte.
final Map<
  String,
  (int, Map<String, (int, void Function(ffi.Pointer<ffi.Void>))>)
>
dartLayout = {
  'RippleAmbience': (
    ffi.sizeOf<RippleAmbience>(),
    {
      'soundscape': (
        0,
        (p) => p.cast<RippleAmbience>().ref.soundscape.id.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'board': (96, (p) => p.cast<RippleAmbience>().ref.board = 1),
      'node': (
        104,
        (p) =>
            p.cast<RippleAmbience>().ref.node.ptr = ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleAudioCommand': (
    ffi.sizeOf<RippleAudioCommand>(),
    {
      'kind': (0, (p) => p.cast<RippleAudioCommand>().ref.kind = 1),
      'soundscape': (
        8,
        (p) => p.cast<RippleAudioCommand>().ref.soundscape =
            ffi.Pointer.fromAddress(1),
      ),
      'fade_ms': (16, (p) => p.cast<RippleAudioCommand>().ref.fade_ms = 1),
      'media': (24, (p) => p.cast<RippleAudioCommand>().ref.media = 1),
      'volume': (
        32,
        (p) => p.cast<RippleAudioCommand>().ref.volume = 1.0000000000000002,
      ),
      'speed': (
        40,
        (p) => p.cast<RippleAudioCommand>().ref.speed = 1.0000000000000002,
      ),
      'node': (
        48,
        (p) => p.cast<RippleAudioCommand>().ref.node.ptr =
            ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleBoard': (
    ffi.sizeOf<RippleBoard>(),
    {
      'id': (
        0,
        (p) => p.cast<RippleBoard>().ref.id.ptr = ffi.Pointer.fromAddress(1),
      ),
      'name': (
        16,
        (p) => p.cast<RippleBoard>().ref.name.ptr = ffi.Pointer.fromAddress(1),
      ),
      'start': (32, (p) => p.cast<RippleBoard>().ref.start = 1),
      'prime': (
        40,
        (p) => p.cast<RippleBoard>().ref.prime = ffi.Pointer.fromAddress(1),
      ),
      'prime_count': (48, (p) => p.cast<RippleBoard>().ref.prime_count = 1),
      'nodes': (
        56,
        (p) => p.cast<RippleBoard>().ref.nodes = ffi.Pointer.fromAddress(1),
      ),
      'node_count': (64, (p) => p.cast<RippleBoard>().ref.node_count = 1),
    },
  ),
  'RippleBundleProblem': (
    ffi.sizeOf<RippleBundleProblem>(),
    {
      'message': (
        0,
        (p) => p.cast<RippleBundleProblem>().ref.message.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'location': (
        16,
        (p) => p.cast<RippleBundleProblem>().ref.location.ptr =
            ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleBundleProblems': (
    ffi.sizeOf<RippleBundleProblems>(),
    {
      'items': (
        0,
        (p) => p.cast<RippleBundleProblems>().ref.items =
            ffi.Pointer.fromAddress(1),
      ),
      'count': (8, (p) => p.cast<RippleBundleProblems>().ref.count = 1),
    },
  ),
  'RippleBytes': (
    ffi.sizeOf<RippleBytes>(),
    {
      'ptr': (
        0,
        (p) => p.cast<RippleBytes>().ref.ptr = ffi.Pointer.fromAddress(1),
      ),
      'len': (8, (p) => p.cast<RippleBytes>().ref.len = 1),
    },
  ),
  'RippleCallbackEvent': (
    ffi.sizeOf<RippleCallbackEvent>(),
    {
      'callback': (
        0,
        (p) => p.cast<RippleCallbackEvent>().ref.callback.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'event': (16, (p) => p.cast<RippleCallbackEvent>().ref.event = 1),
      'board': (
        20,
        (p) => p.cast<RippleCallbackEvent>().ref.board.present = true,
      ),
      'node': (
        32,
        (p) => p.cast<RippleCallbackEvent>().ref.node.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'name': (
        48,
        (p) => p.cast<RippleCallbackEvent>().ref.name.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'from': (
        64,
        (p) =>
            p.cast<RippleCallbackEvent>().ref.from = ffi.Pointer.fromAddress(1),
      ),
      'to': (
        72,
        (p) =>
            p.cast<RippleCallbackEvent>().ref.to = ffi.Pointer.fromAddress(1),
      ),
      'index': (
        80,
        (p) => p.cast<RippleCallbackEvent>().ref.index.present = true,
      ),
    },
  ),
  'RippleChanged': (
    ffi.sizeOf<RippleChanged>(),
    {
      'has_entities': (
        0,
        (p) => p.cast<RippleChanged>().ref.has_entities = true,
      ),
      'entities': (
        8,
        (p) =>
            p.cast<RippleChanged>().ref.entities = ffi.Pointer.fromAddress(1),
      ),
      'entity_count': (16, (p) => p.cast<RippleChanged>().ref.entity_count = 1),
      'memory': (
        24,
        (p) => p.cast<RippleChanged>().ref.memory = ffi.Pointer.fromAddress(1),
      ),
      'has_cvars': (32, (p) => p.cast<RippleChanged>().ref.has_cvars = true),
      'cvars': (
        40,
        (p) => p.cast<RippleChanged>().ref.cvars = ffi.Pointer.fromAddress(1),
      ),
      'cvar_count': (48, (p) => p.cast<RippleChanged>().ref.cvar_count = 1),
    },
  ),
  'RippleChoice': (
    ffi.sizeOf<RippleChoice>(),
    {
      'port': (
        0,
        (p) => p.cast<RippleChoice>().ref.port.ptr = ffi.Pointer.fromAddress(1),
      ),
      'text': (
        16,
        (p) => p.cast<RippleChoice>().ref.text.ptr = ffi.Pointer.fromAddress(1),
      ),
      'available': (32, (p) => p.cast<RippleChoice>().ref.available = true),
    },
  ),
  'RippleChoiceTimer': (
    ffi.sizeOf<RippleChoiceTimer>(),
    {
      'after_ms': (0, (p) => p.cast<RippleChoiceTimer>().ref.after_ms = 1),
      'timeout_ms': (8, (p) => p.cast<RippleChoiceTimer>().ref.timeout_ms = 1),
      'visible': (16, (p) => p.cast<RippleChoiceTimer>().ref.visible = true),
      'default_choice': (
        20,
        (p) => p.cast<RippleChoiceTimer>().ref.default_choice = 1,
      ),
    },
  ),
  'RippleConsoleResult': (
    ffi.sizeOf<RippleConsoleResult>(),
    {
      'result': (
        0,
        (p) => p.cast<RippleConsoleResult>().ref.result.value.nodes =
            ffi.Pointer.fromAddress(1),
      ),
      'effects': (
        40,
        (p) => p.cast<RippleConsoleResult>().ref.effects =
            ffi.Pointer.fromAddress(1),
      ),
      'effect_count': (
        48,
        (p) => p.cast<RippleConsoleResult>().ref.effect_count = 1,
      ),
    },
  ),
  'RippleCvar': (
    ffi.sizeOf<RippleCvar>(),
    {
      'name': (
        0,
        (p) => p.cast<RippleCvar>().ref.name.ptr = ffi.Pointer.fromAddress(1),
      ),
      'type_name': (
        16,
        (p) =>
            p.cast<RippleCvar>().ref.type_name.ptr = ffi.Pointer.fromAddress(1),
      ),
      'default_value': (
        32,
        (p) => p.cast<RippleCvar>().ref.default_value.nodes =
            ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleCvarChange': (
    ffi.sizeOf<RippleCvarChange>(),
    {
      'outcome': (0, (p) => p.cast<RippleCvarChange>().ref.outcome = 1),
      'refusal': (
        8,
        (p) => p.cast<RippleCvarChange>().ref.refusal.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'effects': (
        24,
        (p) =>
            p.cast<RippleCvarChange>().ref.effects = ffi.Pointer.fromAddress(1),
      ),
      'effect_count': (
        32,
        (p) => p.cast<RippleCvarChange>().ref.effect_count = 1,
      ),
    },
  ),
  'RippleCvarList': (
    ffi.sizeOf<RippleCvarList>(),
    {
      'items': (
        0,
        (p) => p.cast<RippleCvarList>().ref.items = ffi.Pointer.fromAddress(1),
      ),
      'count': (8, (p) => p.cast<RippleCvarList>().ref.count = 1),
    },
  ),
  'RippleCvarSnapshot': (
    ffi.sizeOf<RippleCvarSnapshot>(),
    {
      'name': (
        0,
        (p) => p.cast<RippleCvarSnapshot>().ref.name.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'type_name': (
        16,
        (p) => p.cast<RippleCvarSnapshot>().ref.type_name.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'default_value': (
        32,
        (p) => p.cast<RippleCvarSnapshot>().ref.default_value.nodes =
            ffi.Pointer.fromAddress(1),
      ),
      'value': (
        48,
        (p) => p.cast<RippleCvarSnapshot>().ref.value.nodes =
            ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleEdge': (
    ffi.sizeOf<RippleEdge>(),
    {
      'node': (0, (p) => p.cast<RippleEdge>().ref.node = 1),
      'port': (8, (p) => p.cast<RippleEdge>().ref.port = 1),
    },
  ),
  'RippleEffect': (
    ffi.sizeOf<RippleEffect>(),
    {
      'kind': (0, (p) => p.cast<RippleEffect>().ref.kind = 1),
      'data': (
        8,
        (p) =>
            p.cast<RippleEffect>().ref.data.trace = ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleEffectData': (
    ffi.sizeOf<RippleEffectData>(),
    {
      'trace': (
        0,
        (p) =>
            p.cast<RippleEffectData>().ref.trace = ffi.Pointer.fromAddress(1),
      ),
      'callback': (
        0,
        (p) => p.cast<RippleEffectData>().ref.callback =
            ffi.Pointer.fromAddress(1),
      ),
      'jumped': (
        0,
        (p) =>
            p.cast<RippleEffectData>().ref.jumped = ffi.Pointer.fromAddress(1),
      ),
      'ambience': (
        0,
        (p) => p.cast<RippleEffectData>().ref.ambience =
            ffi.Pointer.fromAddress(1),
      ),
      'audio': (
        0,
        (p) =>
            p.cast<RippleEffectData>().ref.audio = ffi.Pointer.fromAddress(1),
      ),
      'changed': (
        0,
        (p) =>
            p.cast<RippleEffectData>().ref.changed = ffi.Pointer.fromAddress(1),
      ),
      'show': (
        0,
        (p) => p.cast<RippleEffectData>().ref.show = ffi.Pointer.fromAddress(1),
      ),
      'ask': (
        0,
        (p) => p.cast<RippleEffectData>().ref.ask = ffi.Pointer.fromAddress(1),
      ),
      'hold_ms': (0, (p) => p.cast<RippleEffectData>().ref.hold_ms = 1),
      'ended': (
        0,
        (p) =>
            p.cast<RippleEffectData>().ref.ended = ffi.Pointer.fromAddress(1),
      ),
      'failed': (
        0,
        (p) =>
            p.cast<RippleEffectData>().ref.failed = ffi.Pointer.fromAddress(1),
      ),
      'permit': (
        0,
        (p) =>
            p.cast<RippleEffectData>().ref.permit = ffi.Pointer.fromAddress(1),
      ),
      'notice': (
        0,
        (p) =>
            p.cast<RippleEffectData>().ref.notice = ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleEffects': (
    ffi.sizeOf<RippleEffects>(),
    {
      'items': (
        0,
        (p) => p.cast<RippleEffects>().ref.items = ffi.Pointer.fromAddress(1),
      ),
      'count': (8, (p) => p.cast<RippleEffects>().ref.count = 1),
    },
  ),
  'RippleEnded': (
    ffi.sizeOf<RippleEnded>(),
    {
      'title': (
        0,
        (p) => p.cast<RippleEnded>().ref.title.ptr = ffi.Pointer.fromAddress(1),
      ),
      'ran_out': (16, (p) => p.cast<RippleEnded>().ref.ran_out = true),
    },
  ),
  'RippleEntity': (
    ffi.sizeOf<RippleEntity>(),
    {
      'key': (
        0,
        (p) => p.cast<RippleEntity>().ref.key.ptr = ffi.Pointer.fromAddress(1),
      ),
      'component': (
        16,
        (p) => p.cast<RippleEntity>().ref.component.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'label': (
        32,
        (p) =>
            p.cast<RippleEntity>().ref.label.ptr = ffi.Pointer.fromAddress(1),
      ),
      'values': (
        48,
        (p) => p.cast<RippleEntity>().ref.values.nodes =
            ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleEntityList': (
    ffi.sizeOf<RippleEntityList>(),
    {
      'items': (
        0,
        (p) =>
            p.cast<RippleEntityList>().ref.items = ffi.Pointer.fromAddress(1),
      ),
      'count': (8, (p) => p.cast<RippleEntityList>().ref.count = 1),
    },
  ),
  'RippleEntityRemoval': (
    ffi.sizeOf<RippleEntityRemoval>(),
    {
      'removed': (0, (p) => p.cast<RippleEntityRemoval>().ref.removed = true),
      'effects': (
        8,
        (p) => p.cast<RippleEntityRemoval>().ref.effects =
            ffi.Pointer.fromAddress(1),
      ),
      'effect_count': (
        16,
        (p) => p.cast<RippleEntityRemoval>().ref.effect_count = 1,
      ),
    },
  ),
  'RippleEntries': (
    ffi.sizeOf<RippleEntries>(),
    {
      'ptr': (
        0,
        (p) => p.cast<RippleEntries>().ref.ptr = ffi.Pointer.fromAddress(1),
      ),
      'count': (8, (p) => p.cast<RippleEntries>().ref.count = 1),
    },
  ),
  'RippleEntry': (
    ffi.sizeOf<RippleEntry>(),
    {
      'id': (
        0,
        (p) => p.cast<RippleEntry>().ref.id.ptr = ffi.Pointer.fromAddress(1),
      ),
      'name': (
        16,
        (p) => p.cast<RippleEntry>().ref.name.ptr = ffi.Pointer.fromAddress(1),
      ),
      'path': (
        32,
        (p) => p.cast<RippleEntry>().ref.path.ptr = ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleError': (
    ffi.sizeOf<RippleError>(),
    {
      'code': (0, (p) => p.cast<RippleError>().ref.codeAsInt = 1),
      'message': (
        8,
        (p) =>
            p.cast<RippleError>().ref.message.ptr = ffi.Pointer.fromAddress(1),
      ),
      'location': (
        24,
        (p) =>
            p.cast<RippleError>().ref.location.ptr = ffi.Pointer.fromAddress(1),
      ),
      'found': (40, (p) => p.cast<RippleError>().ref.found = 1),
      'supported': (48, (p) => p.cast<RippleError>().ref.supported = 1),
      'oldest': (56, (p) => p.cast<RippleError>().ref.oldest.present = true),
      'asked': (72, (p) => p.cast<RippleError>().ref.asked = 1),
      'answered': (76, (p) => p.cast<RippleError>().ref.answered = 1),
      'offered': (80, (p) => p.cast<RippleError>().ref.offered = 1),
      'chosen': (84, (p) => p.cast<RippleError>().ref.chosen = 1),
      'subject': (
        88,
        (p) =>
            p.cast<RippleError>().ref.subject.ptr = ffi.Pointer.fromAddress(1),
      ),
      'node': (
        104,
        (p) => p.cast<RippleError>().ref.node.ptr = ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleFailed': (
    ffi.sizeOf<RippleFailed>(),
    {
      'message': (
        0,
        (p) =>
            p.cast<RippleFailed>().ref.message.ptr = ffi.Pointer.fromAddress(1),
      ),
      'node': (
        16,
        (p) => p.cast<RippleFailed>().ref.node.ptr = ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleField': (
    ffi.sizeOf<RippleField>(),
    {
      'key': (
        0,
        (p) => p.cast<RippleField>().ref.key.ptr = ffi.Pointer.fromAddress(1),
      ),
      'value': (
        16,
        (p) =>
            p.cast<RippleField>().ref.value.nodes = ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleFields': (
    ffi.sizeOf<RippleFields>(),
    {
      'fields': (
        0,
        (p) => p.cast<RippleFields>().ref.fields = ffi.Pointer.fromAddress(1),
      ),
      'count': (8, (p) => p.cast<RippleFields>().ref.count = 1),
    },
  ),
  'RippleFile': (
    ffi.sizeOf<RippleFile>(),
    {
      'path': (
        0,
        (p) => p.cast<RippleFile>().ref.path.ptr = ffi.Pointer.fromAddress(1),
      ),
      'bytes': (
        16,
        (p) => p.cast<RippleFile>().ref.bytes = ffi.Pointer.fromAddress(1),
      ),
      'len': (24, (p) => p.cast<RippleFile>().ref.len = 1),
    },
  ),
  'RippleGenerator': (
    ffi.sizeOf<RippleGenerator>(),
    {
      'lo': (0, (p) => p.cast<RippleGenerator>().ref.lo = 1),
      'hi': (4, (p) => p.cast<RippleGenerator>().ref.hi = 1),
    },
  ),
  'RippleGuardReport': (
    ffi.sizeOf<RippleGuardReport>(),
    {
      'abandoned': (
        0,
        (p) => p.cast<RippleGuardReport>().ref.abandoned =
            ffi.Pointer.fromAddress(1),
      ),
      'abandoned_count': (
        8,
        (p) => p.cast<RippleGuardReport>().ref.abandoned_count = 1,
      ),
      'refused': (16, (p) => p.cast<RippleGuardReport>().ref.refused = 1),
      'exhausted': (
        20,
        (p) => p.cast<RippleGuardReport>().ref.exhausted = true,
      ),
    },
  ),
  'RippleIndices': (
    ffi.sizeOf<RippleIndices>(),
    {
      'ptr': (
        0,
        (p) => p.cast<RippleIndices>().ref.ptr = ffi.Pointer.fromAddress(1),
      ),
      'count': (8, (p) => p.cast<RippleIndices>().ref.count = 1),
    },
  ),
  'RippleJumped': (
    ffi.sizeOf<RippleJumped>(),
    {
      'board': (0, (p) => p.cast<RippleJumped>().ref.board = 1),
      'node': (
        8,
        (p) => p.cast<RippleJumped>().ref.node.ptr = ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleLocaleText': (
    ffi.sizeOf<RippleLocaleText>(),
    {
      'locale': (
        0,
        (p) => p.cast<RippleLocaleText>().ref.locale.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'text': (
        16,
        (p) => p.cast<RippleLocaleText>().ref.text.ptr =
            ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleMachineState': (
    ffi.sizeOf<RippleMachineState>(),
    {
      'machine': (
        0,
        (p) => p.cast<RippleMachineState>().ref.machine.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'state': (
        16,
        (p) => p.cast<RippleMachineState>().ref.state.ptr =
            ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleManifest': (
    ffi.sizeOf<RippleManifest>(),
    {
      'format': (0, (p) => p.cast<RippleManifest>().ref.format = 1),
      'generator': (
        8,
        (p) => p.cast<RippleManifest>().ref.generator.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'text_format': (
        24,
        (p) => p.cast<RippleManifest>().ref.text_format.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'project': (
        40,
        (p) => p.cast<RippleManifest>().ref.project.title.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'entries': (
        120,
        (p) =>
            p.cast<RippleManifest>().ref.entries = ffi.Pointer.fromAddress(1),
      ),
      'entry_count': (128, (p) => p.cast<RippleManifest>().ref.entry_count = 1),
      'boards': (
        136,
        (p) => p.cast<RippleManifest>().ref.boards = ffi.Pointer.fromAddress(1),
      ),
      'board_count': (144, (p) => p.cast<RippleManifest>().ref.board_count = 1),
      'passages': (
        152,
        (p) =>
            p.cast<RippleManifest>().ref.passages = ffi.Pointer.fromAddress(1),
      ),
      'passage_count': (
        160,
        (p) => p.cast<RippleManifest>().ref.passage_count = 1,
      ),
      'components': (
        168,
        (p) => p.cast<RippleManifest>().ref.components =
            ffi.Pointer.fromAddress(1),
      ),
      'component_count': (
        176,
        (p) => p.cast<RippleManifest>().ref.component_count = 1,
      ),
      'scripts': (
        184,
        (p) =>
            p.cast<RippleManifest>().ref.scripts = ffi.Pointer.fromAddress(1),
      ),
      'script_count': (
        192,
        (p) => p.cast<RippleManifest>().ref.script_count = 1,
      ),
      'media': (
        200,
        (p) => p.cast<RippleManifest>().ref.media = ffi.Pointer.fromAddress(1),
      ),
      'media_count': (208, (p) => p.cast<RippleManifest>().ref.media_count = 1),
      'machines': (
        216,
        (p) =>
            p.cast<RippleManifest>().ref.machines = ffi.Pointer.fromAddress(1),
      ),
      'machine_count': (
        224,
        (p) => p.cast<RippleManifest>().ref.machine_count = 1,
      ),
      'soundscapes': (
        232,
        (p) => p.cast<RippleManifest>().ref.soundscapes =
            ffi.Pointer.fromAddress(1),
      ),
      'soundscape_count': (
        240,
        (p) => p.cast<RippleManifest>().ref.soundscape_count = 1,
      ),
      'cvars': (
        248,
        (p) => p.cast<RippleManifest>().ref.cvars = ffi.Pointer.fromAddress(1),
      ),
      'cvar_count': (256, (p) => p.cast<RippleManifest>().ref.cvar_count = 1),
      'needs': (
        264,
        (p) => p.cast<RippleManifest>().ref.needs = ffi.Pointer.fromAddress(1),
      ),
      'need_count': (272, (p) => p.cast<RippleManifest>().ref.need_count = 1),
      'permissions': (
        280,
        (p) => p.cast<RippleManifest>().ref.permissions =
            ffi.Pointer.fromAddress(1),
      ),
      'permission_count': (
        288,
        (p) => p.cast<RippleManifest>().ref.permission_count = 1,
      ),
    },
  ),
  'RippleMediaLink': (
    ffi.sizeOf<RippleMediaLink>(),
    {
      'link': (
        0,
        (p) =>
            p.cast<RippleMediaLink>().ref.link.ptr = ffi.Pointer.fromAddress(1),
      ),
      'media': (16, (p) => p.cast<RippleMediaLink>().ref.media = 1),
    },
  ),
  'RippleMemory': (
    ffi.sizeOf<RippleMemory>(),
    {
      'nodes': (
        0,
        (p) =>
            p.cast<RippleMemory>().ref.nodes.nodes = ffi.Pointer.fromAddress(1),
      ),
      'machines': (
        16,
        (p) => p.cast<RippleMemory>().ref.machines = ffi.Pointer.fromAddress(1),
      ),
      'machine_count': (
        24,
        (p) => p.cast<RippleMemory>().ref.machine_count = 1,
      ),
    },
  ),
  'RippleMoment': (
    ffi.sizeOf<RippleMoment>(),
    {
      'utc_ms': (0, (p) => p.cast<RippleMoment>().ref.utc_ms = 1),
      'offset_minutes': (
        8,
        (p) => p.cast<RippleMoment>().ref.offset_minutes = 1,
      ),
    },
  ),
  'RippleNode': (
    ffi.sizeOf<RippleNode>(),
    {
      'id': (
        0,
        (p) => p.cast<RippleNode>().ref.id.ptr = ffi.Pointer.fromAddress(1),
      ),
      'type_name': (
        16,
        (p) =>
            p.cast<RippleNode>().ref.type_name.ptr = ffi.Pointer.fromAddress(1),
      ),
      'title': (
        32,
        (p) => p.cast<RippleNode>().ref.title.ptr = ffi.Pointer.fromAddress(1),
      ),
      'inputs': (
        48,
        (p) => p.cast<RippleNode>().ref.inputs = ffi.Pointer.fromAddress(1),
      ),
      'input_count': (56, (p) => p.cast<RippleNode>().ref.input_count = 1),
      'outputs': (
        64,
        (p) => p.cast<RippleNode>().ref.outputs = ffi.Pointer.fromAddress(1),
      ),
      'output_count': (72, (p) => p.cast<RippleNode>().ref.output_count = 1),
      'data': (
        80,
        (p) => p.cast<RippleNode>().ref.data.nodes = ffi.Pointer.fromAddress(1),
      ),
      'metadata': (
        96,
        (p) => p.cast<RippleNode>().ref.metadata.nodes =
            ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleNotice': (
    ffi.sizeOf<RippleNotice>(),
    {
      'code': (
        0,
        (p) => p.cast<RippleNotice>().ref.code.ptr = ffi.Pointer.fromAddress(1),
      ),
      'kind': (16, (p) => p.cast<RippleNotice>().ref.kind = 1),
      'node': (
        24,
        (p) => p.cast<RippleNotice>().ref.node.ptr = ffi.Pointer.fromAddress(1),
      ),
      'message': (
        40,
        (p) =>
            p.cast<RippleNotice>().ref.message.ptr = ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleOptionalF64': (
    ffi.sizeOf<RippleOptionalF64>(),
    {
      'present': (0, (p) => p.cast<RippleOptionalF64>().ref.present = true),
      'value': (
        8,
        (p) => p.cast<RippleOptionalF64>().ref.value = 1.0000000000000002,
      ),
    },
  ),
  'RippleOptionalI64': (
    ffi.sizeOf<RippleOptionalI64>(),
    {
      'present': (0, (p) => p.cast<RippleOptionalI64>().ref.present = true),
      'value': (8, (p) => p.cast<RippleOptionalI64>().ref.value = 1),
    },
  ),
  'RippleOptionalU32': (
    ffi.sizeOf<RippleOptionalU32>(),
    {
      'present': (0, (p) => p.cast<RippleOptionalU32>().ref.present = true),
      'value': (4, (p) => p.cast<RippleOptionalU32>().ref.value = 1),
    },
  ),
  'RippleOptionalU64': (
    ffi.sizeOf<RippleOptionalU64>(),
    {
      'present': (0, (p) => p.cast<RippleOptionalU64>().ref.present = true),
      'value': (8, (p) => p.cast<RippleOptionalU64>().ref.value = 1),
    },
  ),
  'RipplePassage': (
    ffi.sizeOf<RipplePassage>(),
    {
      'node': (
        0,
        (p) =>
            p.cast<RipplePassage>().ref.node.ptr = ffi.Pointer.fromAddress(1),
      ),
      'title': (
        16,
        (p) =>
            p.cast<RipplePassage>().ref.title.ptr = ffi.Pointer.fromAddress(1),
      ),
      'text': (
        32,
        (p) =>
            p.cast<RipplePassage>().ref.text.ptr = ffi.Pointer.fromAddress(1),
      ),
      'choices': (
        48,
        (p) => p.cast<RipplePassage>().ref.choices = ffi.Pointer.fromAddress(1),
      ),
      'choice_count': (56, (p) => p.cast<RipplePassage>().ref.choice_count = 1),
      'has_sources': (
        64,
        (p) => p.cast<RipplePassage>().ref.has_sources = true,
      ),
      'sources': (
        72,
        (p) => p.cast<RipplePassage>().ref.sources = ffi.Pointer.fromAddress(1),
      ),
      'source_count': (80, (p) => p.cast<RipplePassage>().ref.source_count = 1),
      'snippets': (
        88,
        (p) =>
            p.cast<RipplePassage>().ref.snippets = ffi.Pointer.fromAddress(1),
      ),
      'snippet_count': (
        96,
        (p) => p.cast<RipplePassage>().ref.snippet_count = 1,
      ),
      'media': (
        104,
        (p) => p.cast<RipplePassage>().ref.media = ffi.Pointer.fromAddress(1),
      ),
      'media_count': (112, (p) => p.cast<RipplePassage>().ref.media_count = 1),
      'untranslated': (
        120,
        (p) => p.cast<RipplePassage>().ref.untranslated.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'soundscape': (
        136,
        (p) =>
            p.cast<RipplePassage>().ref.soundscape = ffi.Pointer.fromAddress(1),
      ),
      'silence': (144, (p) => p.cast<RipplePassage>().ref.silence = true),
      'timer': (
        152,
        (p) => p.cast<RipplePassage>().ref.timer = ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RipplePaused': (
    ffi.sizeOf<RipplePaused>(),
    {
      'save': (
        0,
        (p) => p.cast<RipplePaused>().ref.save.ptr = ffi.Pointer.fromAddress(1),
      ),
      'effects': (
        16,
        (p) => p.cast<RipplePaused>().ref.effects = ffi.Pointer.fromAddress(1),
      ),
      'effect_count': (24, (p) => p.cast<RipplePaused>().ref.effect_count = 1),
    },
  ),
  'RipplePermit': (
    ffi.sizeOf<RipplePermit>(),
    {
      'kinds': (
        0,
        (p) => p.cast<RipplePermit>().ref.kinds = ffi.Pointer.fromAddress(1),
      ),
      'kind_count': (8, (p) => p.cast<RipplePermit>().ref.kind_count = 1),
    },
  ),
  'RipplePort': (
    ffi.sizeOf<RipplePort>(),
    {
      'id': (
        0,
        (p) => p.cast<RipplePort>().ref.id.ptr = ffi.Pointer.fromAddress(1),
      ),
      'kind': (16, (p) => p.cast<RipplePort>().ref.kind = 1),
      'edges': (
        24,
        (p) => p.cast<RipplePort>().ref.edges = ffi.Pointer.fromAddress(1),
      ),
      'edge_count': (32, (p) => p.cast<RipplePort>().ref.edge_count = 1),
    },
  ),
  'RipplePosition': (
    ffi.sizeOf<RipplePosition>(),
    {
      'label': (
        0,
        (p) =>
            p.cast<RipplePosition>().ref.label.ptr = ffi.Pointer.fromAddress(1),
      ),
      'latitude': (
        16,
        (p) => p.cast<RipplePosition>().ref.latitude.present = true,
      ),
      'longitude': (
        32,
        (p) => p.cast<RipplePosition>().ref.longitude.present = true,
      ),
      'accuracy': (
        48,
        (p) => p.cast<RipplePosition>().ref.accuracy.present = true,
      ),
      'when': (
        64,
        (p) => p.cast<RipplePosition>().ref.when = ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleProject': (
    ffi.sizeOf<RippleProject>(),
    {
      'title': (
        0,
        (p) =>
            p.cast<RippleProject>().ref.title.ptr = ffi.Pointer.fromAddress(1),
      ),
      'description': (
        16,
        (p) => p.cast<RippleProject>().ref.description.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'default_locale': (
        32,
        (p) => p.cast<RippleProject>().ref.default_locale.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'locales': (
        48,
        (p) => p.cast<RippleProject>().ref.locales = ffi.Pointer.fromAddress(1),
      ),
      'locale_count': (56, (p) => p.cast<RippleProject>().ref.locale_count = 1),
      'cover': (
        64,
        (p) =>
            p.cast<RippleProject>().ref.cover.ptr = ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RipplePrompt': (
    ffi.sizeOf<RipplePrompt>(),
    {
      'node': (
        0,
        (p) => p.cast<RipplePrompt>().ref.node.ptr = ffi.Pointer.fromAddress(1),
      ),
      'title': (
        16,
        (p) =>
            p.cast<RipplePrompt>().ref.title.ptr = ffi.Pointer.fromAddress(1),
      ),
      'fields': (
        32,
        (p) => p.cast<RipplePrompt>().ref.fields = ffi.Pointer.fromAddress(1),
      ),
      'field_count': (40, (p) => p.cast<RipplePrompt>().ref.field_count = 1),
    },
  ),
  'RipplePromptField': (
    ffi.sizeOf<RipplePromptField>(),
    {
      'name': (
        0,
        (p) => p.cast<RipplePromptField>().ref.name.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'type_name': (
        16,
        (p) => p.cast<RipplePromptField>().ref.type_name.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'default_value': (
        32,
        (p) => p.cast<RipplePromptField>().ref.default_value.nodes =
            ffi.Pointer.fromAddress(1),
      ),
      'label': (
        48,
        (p) => p.cast<RipplePromptField>().ref.label.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'placeholder': (
        64,
        (p) => p.cast<RipplePromptField>().ref.placeholder.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'optional': (80, (p) => p.cast<RipplePromptField>().ref.optional = true),
      'options': (
        88,
        (p) => p.cast<RipplePromptField>().ref.options =
            ffi.Pointer.fromAddress(1),
      ),
      'option_count': (
        96,
        (p) => p.cast<RipplePromptField>().ref.option_count = 1,
      ),
    },
  ),
  'RipplePromptOption': (
    ffi.sizeOf<RipplePromptOption>(),
    {
      'id': (
        0,
        (p) => p.cast<RipplePromptOption>().ref.id.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'label': (
        16,
        (p) => p.cast<RipplePromptOption>().ref.label.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'value': (
        32,
        (p) => p.cast<RipplePromptOption>().ref.value.nodes =
            ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RipplePythonFailure': (
    ffi.sizeOf<RipplePythonFailure>(),
    {
      'kind': (0, (p) => p.cast<RipplePythonFailure>().ref.kind = 1),
      'exception': (
        8,
        (p) => p.cast<RipplePythonFailure>().ref.exception.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'message': (
        24,
        (p) => p.cast<RipplePythonFailure>().ref.message.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'line': (
        40,
        (p) => p.cast<RipplePythonFailure>().ref.line.present = true,
      ),
      'traceback': (
        48,
        (p) => p.cast<RipplePythonFailure>().ref.traceback.ptr =
            ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RipplePythonResult': (
    ffi.sizeOf<RipplePythonResult>(),
    {
      'value': (
        0,
        (p) => p.cast<RipplePythonResult>().ref.value.nodes =
            ffi.Pointer.fromAddress(1),
      ),
      'output': (
        16,
        (p) => p.cast<RipplePythonResult>().ref.output.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'error': (
        32,
        (p) =>
            p.cast<RipplePythonResult>().ref.error = ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleRunDiagnostic': (
    ffi.sizeOf<RippleRunDiagnostic>(),
    {
      'issue': (0, (p) => p.cast<RippleRunDiagnostic>().ref.issue = 1),
      'message': (
        8,
        (p) => p.cast<RippleRunDiagnostic>().ref.message.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'node': (
        24,
        (p) => p.cast<RippleRunDiagnostic>().ref.node.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'port': (
        40,
        (p) => p.cast<RippleRunDiagnostic>().ref.port.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'wires': (
        56,
        (p) => p.cast<RippleRunDiagnostic>().ref.wires.present = true,
      ),
    },
  ),
  'RippleRunEvent': (
    ffi.sizeOf<RippleRunEvent>(),
    {
      'kind': (0, (p) => p.cast<RippleRunEvent>().ref.kind = 1),
      'at': (4, (p) => p.cast<RippleRunEvent>().ref.at.run = 1),
      'node': (
        16,
        (p) =>
            p.cast<RippleRunEvent>().ref.node.ptr = ffi.Pointer.fromAddress(1),
      ),
      'step': (32, (p) => p.cast<RippleRunEvent>().ref.step = 1),
      'entry': (
        40,
        (p) =>
            p.cast<RippleRunEvent>().ref.entry.ptr = ffi.Pointer.fromAddress(1),
      ),
      'primed': (
        56,
        (p) => p.cast<RippleRunEvent>().ref.primed = ffi.Pointer.fromAddress(1),
      ),
      'primed_count': (
        64,
        (p) => p.cast<RippleRunEvent>().ref.primed_count = 1,
      ),
      'entered_via': (
        72,
        (p) => p.cast<RippleRunEvent>().ref.entered_via.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'pulled': (88, (p) => p.cast<RippleRunEvent>().ref.pulled = true),
      'inputs': (
        96,
        (p) => p.cast<RippleRunEvent>().ref.inputs = ffi.Pointer.fromAddress(1),
      ),
      'input_count': (104, (p) => p.cast<RippleRunEvent>().ref.input_count = 1),
      'outcome': (112, (p) => p.cast<RippleRunEvent>().ref.outcome = 1),
      'outputs': (
        120,
        (p) =>
            p.cast<RippleRunEvent>().ref.outputs = ffi.Pointer.fromAddress(1),
      ),
      'output_count': (
        128,
        (p) => p.cast<RippleRunEvent>().ref.output_count = 1,
      ),
      'flowed': (
        136,
        (p) => p.cast<RippleRunEvent>().ref.flowed = ffi.Pointer.fromAddress(1),
      ),
      'flowed_count': (
        144,
        (p) => p.cast<RippleRunEvent>().ref.flowed_count = 1,
      ),
      'error': (
        152,
        (p) =>
            p.cast<RippleRunEvent>().ref.error.ptr = ffi.Pointer.fromAddress(1),
      ),
      'diagnostic': (
        168,
        (p) => p.cast<RippleRunEvent>().ref.diagnostic =
            ffi.Pointer.fromAddress(1),
      ),
      'level': (176, (p) => p.cast<RippleRunEvent>().ref.level = 1),
      'message': (
        184,
        (p) => p.cast<RippleRunEvent>().ref.message.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'data': (
        200,
        (p) => p.cast<RippleRunEvent>().ref.data = ffi.Pointer.fromAddress(1),
      ),
      'steps': (208, (p) => p.cast<RippleRunEvent>().ref.steps = 1),
      'cancelled': (212, (p) => p.cast<RippleRunEvent>().ref.cancelled = true),
      'failed_node': (
        216,
        (p) => p.cast<RippleRunEvent>().ref.failed_node.ptr =
            ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleRunPlace': (
    ffi.sizeOf<RippleRunPlace>(),
    {
      'run': (0, (p) => p.cast<RippleRunPlace>().ref.run = 1),
      'board': (4, (p) => p.cast<RippleRunPlace>().ref.board = 1),
      'sequence': (8, (p) => p.cast<RippleRunPlace>().ref.sequence = 1),
    },
  ),
  'RippleScriptLimits': (
    ffi.sizeOf<RippleScriptLimits>(),
    {
      'deadline_ms': (
        0,
        (p) => p.cast<RippleScriptLimits>().ref.deadline_ms = 1,
      ),
      'memory_bytes': (
        8,
        (p) => p.cast<RippleScriptLimits>().ref.memory_bytes = 1,
      ),
      'recursion_depth': (
        16,
        (p) => p.cast<RippleScriptLimits>().ref.recursion_depth = 1,
      ),
    },
  ),
  'RippleSessionConfig': (
    ffi.sizeOf<RippleSessionConfig>(),
    {
      'board': (0, (p) => p.cast<RippleSessionConfig>().ref.board = 1),
      'entry_node': (
        8,
        (p) => p.cast<RippleSessionConfig>().ref.entry_node.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'locale': (
        24,
        (p) => p.cast<RippleSessionConfig>().ref.locale.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'seed': (40, (p) => p.cast<RippleSessionConfig>().ref.seed = 1),
      'digest': (
        48,
        (p) => p.cast<RippleSessionConfig>().ref.digest.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'options': (
        64,
        (p) => p.cast<RippleSessionConfig>().ref.options.step_budget = 1,
      ),
    },
  ),
  'RippleSessionOptions': (
    ffi.sizeOf<RippleSessionOptions>(),
    {
      'step_budget': (
        0,
        (p) => p.cast<RippleSessionOptions>().ref.step_budget = 1,
      ),
      'silent_jump_limit': (
        4,
        (p) => p.cast<RippleSessionOptions>().ref.silent_jump_limit = 1,
      ),
      'loop_limit': (
        8,
        (p) => p.cast<RippleSessionOptions>().ref.loop_limit = 1,
      ),
      'script_limits': (
        16,
        (p) => p.cast<RippleSessionOptions>().ref.script_limits.deadline_ms = 1,
      ),
      'untranslated': (
        40,
        (p) => p.cast<RippleSessionOptions>().ref.untranslated = 1,
      ),
      'trace': (44, (p) => p.cast<RippleSessionOptions>().ref.trace = true),
      'trace_payloads': (
        45,
        (p) => p.cast<RippleSessionOptions>().ref.trace_payloads = true,
      ),
    },
  ),
  'RippleSnippet': (
    ffi.sizeOf<RippleSnippet>(),
    {
      'code': (
        0,
        (p) =>
            p.cast<RippleSnippet>().ref.code.ptr = ffi.Pointer.fromAddress(1),
      ),
      'is_inline': (16, (p) => p.cast<RippleSnippet>().ref.is_inline = true),
    },
  ),
  'RippleSoundscape': (
    ffi.sizeOf<RippleSoundscape>(),
    {
      'id': (
        0,
        (p) =>
            p.cast<RippleSoundscape>().ref.id.ptr = ffi.Pointer.fromAddress(1),
      ),
      'name': (
        16,
        (p) => p.cast<RippleSoundscape>().ref.name.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'length': (32, (p) => p.cast<RippleSoundscape>().ref.length = 1),
      'looping': (40, (p) => p.cast<RippleSoundscape>().ref.looping = true),
      'fade_in': (48, (p) => p.cast<RippleSoundscape>().ref.fade_in = 1),
      'fade_out': (56, (p) => p.cast<RippleSoundscape>().ref.fade_out = 1),
      'volume': (
        64,
        (p) => p.cast<RippleSoundscape>().ref.volume = 1.0000000000000002,
      ),
      'tied': (72, (p) => p.cast<RippleSoundscape>().ref.tied = true),
      'tracks': (
        80,
        (p) =>
            p.cast<RippleSoundscape>().ref.tracks = ffi.Pointer.fromAddress(1),
      ),
      'track_count': (
        88,
        (p) => p.cast<RippleSoundscape>().ref.track_count = 1,
      ),
    },
  ),
  'RippleStr': (
    ffi.sizeOf<RippleStr>(),
    {
      'ptr': (
        0,
        (p) => p.cast<RippleStr>().ref.ptr = ffi.Pointer.fromAddress(1),
      ),
      'len': (8, (p) => p.cast<RippleStr>().ref.len = 1),
    },
  ),
  'RippleStrList': (
    ffi.sizeOf<RippleStrList>(),
    {
      'items': (
        0,
        (p) => p.cast<RippleStrList>().ref.items = ffi.Pointer.fromAddress(1),
      ),
      'count': (8, (p) => p.cast<RippleStrList>().ref.count = 1),
    },
  ),
  'RippleTraceValue': (
    ffi.sizeOf<RippleTraceValue>(),
    {
      'from_node': (
        0,
        (p) => p.cast<RippleTraceValue>().ref.from_node.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'from_port': (
        16,
        (p) => p.cast<RippleTraceValue>().ref.from_port.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'to_node': (
        32,
        (p) => p.cast<RippleTraceValue>().ref.to_node.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'to_port': (
        48,
        (p) => p.cast<RippleTraceValue>().ref.to_port.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'payload': (64, (p) => p.cast<RippleTraceValue>().ref.payload = 1),
      'value': (
        72,
        (p) => p.cast<RippleTraceValue>().ref.value.nodes =
            ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleTrack': (
    ffi.sizeOf<RippleTrack>(),
    {
      'media': (0, (p) => p.cast<RippleTrack>().ref.media = 1),
      'lane': (8, (p) => p.cast<RippleTrack>().ref.lane = 1),
      'start': (16, (p) => p.cast<RippleTrack>().ref.start = 1),
      'clip_start': (24, (p) => p.cast<RippleTrack>().ref.clip_start = 1),
      'clip_end': (
        32,
        (p) => p.cast<RippleTrack>().ref.clip_end.present = true,
      ),
      'volume': (
        48,
        (p) => p.cast<RippleTrack>().ref.volume = 1.0000000000000002,
      ),
      'speed': (
        56,
        (p) => p.cast<RippleTrack>().ref.speed = 1.0000000000000002,
      ),
      'fade_in': (64, (p) => p.cast<RippleTrack>().ref.fade_in = 1),
      'fade_out': (72, (p) => p.cast<RippleTrack>().ref.fade_out = 1),
      'mode': (80, (p) => p.cast<RippleTrack>().ref.mode = 1),
      'interval': (88, (p) => p.cast<RippleTrack>().ref.interval = 1),
    },
  ),
  'RippleValue': (
    ffi.sizeOf<RippleValue>(),
    {
      'nodes': (
        0,
        (p) => p.cast<RippleValue>().ref.nodes = ffi.Pointer.fromAddress(1),
      ),
      'count': (8, (p) => p.cast<RippleValue>().ref.count = 1),
    },
  ),
  'RippleValueData': (
    ffi.sizeOf<RippleValueData>(),
    {
      'boolean': (0, (p) => p.cast<RippleValueData>().ref.boolean = true),
      'integer': (0, (p) => p.cast<RippleValueData>().ref.integer = 1),
      'real': (
        0,
        (p) => p.cast<RippleValueData>().ref.real = 1.0000000000000002,
      ),
      'text': (
        0,
        (p) =>
            p.cast<RippleValueData>().ref.text.ptr = ffi.Pointer.fromAddress(1),
      ),
      'items': (
        0,
        (p) => p.cast<RippleValueData>().ref.items.ptr =
            ffi.Pointer.fromAddress(1),
      ),
      'entries': (
        0,
        (p) => p.cast<RippleValueData>().ref.entries.ptr =
            ffi.Pointer.fromAddress(1),
      ),
    },
  ),
  'RippleValueEntry': (
    ffi.sizeOf<RippleValueEntry>(),
    {
      'key': (
        0,
        (p) =>
            p.cast<RippleValueEntry>().ref.key.ptr = ffi.Pointer.fromAddress(1),
      ),
      'node': (16, (p) => p.cast<RippleValueEntry>().ref.node = 1),
    },
  ),
  'RippleValueNode': (
    ffi.sizeOf<RippleValueNode>(),
    {
      'kind': (0, (p) => p.cast<RippleValueNode>().ref.kind = 1),
      'data': (8, (p) => p.cast<RippleValueNode>().ref.data.boolean = true),
    },
  ),
  'RippleVoiceCommand': (
    ffi.sizeOf<RippleVoiceCommand>(),
    {
      'kind': (0, (p) => p.cast<RippleVoiceCommand>().ref.kind = 1),
      'voice': (8, (p) => p.cast<RippleVoiceCommand>().ref.voice = 1),
      'media': (16, (p) => p.cast<RippleVoiceCommand>().ref.media = 1),
      'from_ms': (24, (p) => p.cast<RippleVoiceCommand>().ref.from_ms = 1),
      'to_ms': (
        32,
        (p) => p.cast<RippleVoiceCommand>().ref.to_ms.present = true,
      ),
      'gain': (
        48,
        (p) => p.cast<RippleVoiceCommand>().ref.gain = 1.0000000000000002,
      ),
      'rate': (
        56,
        (p) => p.cast<RippleVoiceCommand>().ref.rate = 1.0000000000000002,
      ),
      'looping': (64, (p) => p.cast<RippleVoiceCommand>().ref.looping = true),
      'loop_from_ms': (
        72,
        (p) => p.cast<RippleVoiceCommand>().ref.loop_from_ms = 1,
      ),
      'role': (80, (p) => p.cast<RippleVoiceCommand>().ref.role = 1),
      'track': (84, (p) => p.cast<RippleVoiceCommand>().ref.track = 1),
    },
  ),
  'RippleVoiceCommands': (
    ffi.sizeOf<RippleVoiceCommands>(),
    {
      'items': (
        0,
        (p) => p.cast<RippleVoiceCommands>().ref.items =
            ffi.Pointer.fromAddress(1),
      ),
      'count': (8, (p) => p.cast<RippleVoiceCommands>().ref.count = 1),
    },
  ),
};
