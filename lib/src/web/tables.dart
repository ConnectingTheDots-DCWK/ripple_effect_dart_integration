// The WIT's names for what the C header numbers, in the header's order — so
// a record read on the web carries the number a native host reads. Pure Dart,
// so test/tables_test.dart can hold every list to the generated C
// enums on the VM.

/// `RippleTurnKind`.
const List<String> turnKinds = [
  'present',
  'ask',
  'wait',
  'ended',
  'failed',
  'stopped',
  'permit',
];

/// `RippleVerb`.
const List<String> verbs = [
  'choose',
  'answer',
  'elapsed',
  'begin-countdown',
  'expire',
];

/// `RippleRunIssue`.
const List<String> runIssues = [
  'ambiguous-flow',
  'multiple-inputs',
  'producer-not-run',
  'reentered',
  'nothing-on-wire',
];

/// `RippleTurnOutcome`.
const List<String> turnOutcomes = ['done', 'failed'];

/// `RippleLogLevel`.
const List<String> logLevels = ['debug', 'info', 'warning', 'error'];

/// `RipplePythonFailureKind`.
const List<String> pythonFailureKinds = [
  'python',
  'timeout',
  'refused',
  'closed',
  'host-error',
  'unavailable',
];

/// `RippleCallbackKind`; the author's name for each is the tag with its
/// dashes made dots (`cvar-changed` is `cvar.changed`).
const List<String> callbackKinds = [
  'story-started',
  'board-entered',
  'soundscape-changed',
  'passage-shown',
  'choice-taken',
  'delay-started',
  'delay-elapsed',
  'story-ended',
  'story-failed',
  'cvar-changed',
  'entity-spawned',
  'entity-removed',
  'entity-renamed',
  'entity-field-changed',
  'machine-state-entered',
  'node-entered',
  'node-exited',
  'node-failed',
  'countdown-started',
  'countdown-expired',
];

/// `PermissionKind`'s order, the C ABI's numbers. The header declares no
/// enum for it, so test/tables_test.dart holds it to `ripple_session_permit`
/// instead.
const List<String> permissionKinds = ['date-time', 'location'];

/// `RippleRunEventKind`.
const List<String> runEventKinds = [
  'run-started',
  'node-started',
  'node-finished',
  'memo-hit',
  'diagnostic',
  'log',
  'run-finished',
];
