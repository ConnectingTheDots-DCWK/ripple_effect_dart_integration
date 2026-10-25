import '../errors.dart';
import 'internal.dart';
import '../interop/ripple.g.dart';

/// The engine library this program loaded, and what it binds.
abstract final class RippleEngine {
  /// The contract these bindings bind: `MAJOR.MINOR`.
  static const String boundContract = '1.6';

  static bool _checked = false;

  /// Loads the engine and checks it binds [boundContract]. On a native
  /// platform the library is already in the process and this answers at
  /// once; on the web it fetches and compiles the engine, and [base] names
  /// where its files are served from. Opening a campaign awaits it, so a
  /// host need only call it to choose [base].
  static Future<void> load({Uri? base}) async => ensureLoaded();

  /// The engine library's version, `1.6.0` — the one loaded, not the one
  /// built against.
  static String get version {
    ensureLoaded();
    return readCStr(ripple_engine_version());
  }

  /// The contract the loaded library binds, `1.6`.
  static String get contract {
    ensureLoaded();
    return readCStr(ripple_engine_contract());
  }

  /// Whether the loaded library runs scripts: false for the `no-python` one,
  /// which the `python: false` user-define selects.
  static bool get hasPython {
    ensureLoaded();
    return ripple_engine_has_python();
  }

  /// How many things the engine handed out and has not had back. Zero
  /// whenever nothing of this binding is mid-call: everything it reads, it
  /// copies and frees before a verb returns.
  static int get outstanding {
    ensureLoaded();
    return ripple_outstanding();
  }

  /// Loads the library and checks it binds [boundContract], once. Every
  /// handle's constructor calls it, so the first failure is this one, saying
  /// what went wrong, rather than a bare lookup error deep inside a verb.
  static void ensureLoaded() {
    if (_checked) return;
    final String loaded;
    try {
      loaded = readCStr(ripple_engine_contract());
    } on ArgumentError catch (e) {
      throw EngineNotFoundException(
        'The Ripple Effect engine library (ripple_effect_engine) is not '
        'bundled with this program. The ripplefx_engine build hook bundles '
        'it for `dart run`, `dart test`, `dart build` and every `flutter` '
        'build, for 64-bit Windows, macOS, Linux and Android and for iOS on '
        'arm64; a 32-bit device has no engine build, and a program compiled '
        'some other way has no library to load.',
        e,
      );
    }
    if (loaded != boundContract) {
      throw EngineNotFoundException(
        'The engine library loaded binds contract $loaded, and these bindings '
        'bind $boundContract. An engine_dir or engine_tree user-define names '
        'a library of another contract.',
      );
    }
    _checked = true;
  }
}
