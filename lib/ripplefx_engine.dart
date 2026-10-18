/// Play a campaign written in the Ripple Effect editor: open its bundle,
/// start a [Session], and answer the Turn every verb ends on.
///
/// ```dart
/// final campaign = await Campaign.openDirectory('campaigns/the-choir');
/// final session = Session.create(
///   campaign,
///   SessionConfig(board: campaign.manifest.entries.first),
/// );
/// for (var batch = session.start(); !batch.last.isOver;) {
///   batch = switch (batch.last) {
///     Show(:final passage) => session.choose(pick(passage)),
///     Ask(:final prompt) => session.answer(fill(prompt)),
///     Hold(:final ms) => await wait(ms, session.elapsed), // your clock
///     _ => throw StateError('every batch ends on a Turn'),
///   };
/// }
/// ```
///
/// [Player] is that loop written once, for a game loop; [SoundscapeDriver]
/// plays a story's soundscapes through a [Speaker] of your own.
library;

export 'src/bundle_file.dart';
export 'src/campaign.dart' show Campaign;
export 'src/effects.dart';
export 'src/engine.dart' show RippleEngine;
export 'src/errors.dart';
export 'src/mixer.dart' show Mixer;
export 'src/mixer_types.dart' show Phase, VoiceCommand, VoiceKind;
export 'src/player.dart';
export 'src/records.dart';
export 'src/session.dart' show Session;
export 'src/session_types.dart';
export 'src/soundscape_driver.dart';
export 'src/speaker.dart' hide VoiceInbox, VoiceReport;
export 'src/value.dart'
    show
        BoolValue,
        FloatValue,
        IntValue,
        ListValue,
        MapValue,
        NullValue,
        TextValue,
        Value;
