// What the two backends must agree on and neither can read from the other:
// the web side's names for the C header's enums, in the header's order, and
// the defaults the web side carries as constants because the component
// exports no `ripple_session_options_default`. Held here, on the VM, to the
// generated C bindings and to the native engine itself.
@TestOn('vm')
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;
import 'package:ripplefx_engine/ripplefx_engine.dart';
import 'package:ripplefx_engine/src/interop/ripple.g.dart';
import 'package:ripplefx_engine/src/mixer_types.dart'
    show kDefaultGainStep, kDefaultMaxCues;
import 'package:ripplefx_engine/src/web/tables.dart';
import 'package:test/test.dart';

String _cName(String wit) => wit.toUpperCase().replaceAll('-', '_');

void main() {
  void holds(String name, List<String> wit, List<Enum> c, String prefix) {
    test('the web spells $name as the header numbers it', () {
      expect(
        [for (final e in c) e.name],
        [for (final w in wit) '$prefix${_cName(w)}'],
      );
    });
  }

  holds(
    'RippleTurnKind',
    turnKinds,
    RippleTurnKind.values,
    'RIPPLE_TURN_KIND_',
  );
  holds('RippleVerb', verbs, RippleVerb.values, 'RIPPLE_VERB_');
  holds(
    'RippleRunIssue',
    runIssues,
    RippleRunIssue.values,
    'RIPPLE_RUN_ISSUE_',
  );
  holds(
    'RippleTurnOutcome',
    turnOutcomes,
    RippleTurnOutcome.values,
    'RIPPLE_TURN_OUTCOME_',
  );
  holds(
    'RippleLogLevel',
    logLevels,
    RippleLogLevel.values,
    'RIPPLE_LOG_LEVEL_',
  );
  holds(
    'RipplePythonFailureKind',
    pythonFailureKinds,
    RipplePythonFailureKind.values,
    'RIPPLE_PYTHON_FAILURE_KIND_',
  );
  holds(
    'RippleCallbackKind',
    callbackKinds,
    RippleCallbackKind.values,
    'RIPPLE_CALLBACK_KIND_',
  );
  holds(
    'RippleRunEventKind',
    runEventKinds,
    RippleRunEventKind.values,
    'RIPPLE_RUN_EVENT_KIND_',
  );

  test('the web spells PermissionKind as the binding numbers it', () {
    // The header declares no enum for it; ripple_session_permit takes these
    // numbers, and test/senses_test.dart reads a Permit turn's back.
    expect(
      [for (final kind in PermissionKind.values) kind.wire],
      [
        for (final wit in permissionKinds)
          wit.replaceAllMapped(
            RegExp('-(.)'),
            (m) => m.group(1)!.toUpperCase(),
          ),
      ],
    );
  });

  test('every code the header returns is a Code of the same number', () {
    String snake(String camel) => camel
        .replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m.group(0)}')
        .toUpperCase();
    for (final result in RippleResult.values) {
      final code = Code.of(result.value);
      expect(code.value, result.value, reason: result.name);
      expect(
        result.name,
        code == Code.success
            ? 'RIPPLE_SUCCESS'
            : 'RIPPLE_ERROR_${snake(code.name)}',
      );
    }
  });

  test("a callback's name is its tag with the dashes made dots", () {
    for (final (i, kind) in callbackKinds.indexed) {
      expect(
        ripple_callback_kind_name(i).cast<ffi.Utf8>().toDartString(),
        kind.replaceAll('-', '.'),
      );
    }
  });

  test("SessionOptions() is the engine's own", () {
    final given = ffi.calloc<RippleSessionOptions>();
    try {
      ripple_session_options_default(given);
      const o = SessionOptions();
      final g = given.ref;
      expect(o.stepBudget, g.step_budget);
      expect(o.silentJumpLimit, g.silent_jump_limit);
      expect(o.loopLimit, g.loop_limit);
      expect(o.scriptDeadlineMs, g.script_limits.deadline_ms);
      expect(o.scriptMemoryBytes, g.script_limits.memory_bytes);
      expect(o.scriptRecursionDepth, g.script_limits.recursion_depth);
      expect(o.untranslated.index, g.untranslated);
      expect(o.trace, g.trace);
      expect(o.tracePayloads, g.trace_payloads);
    } finally {
      ffi.calloc.free(given);
    }
  });

  test("the mixer's defaults are the header's", () {
    expect(kDefaultMaxCues, RIPPLE_MIXER_DEFAULT_MAX_CUES);
    expect(kDefaultGainStep, RIPPLE_MIXER_DEFAULT_GAIN_STEP);
  });
}
