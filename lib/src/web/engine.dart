import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../errors.dart';
import 'js.dart';

/// Which engine a web build loads: `--dart-define=RIPPLEFX_PYTHON=false`
/// for the one without Python. Native builds choose with the build hook's
/// `python` user-define instead; no hook runs for the web.
const bool _pythonDefine = bool.fromEnvironment(
  'RIPPLEFX_PYTHON',
  defaultValue: true,
);

/// Flutter's web builds define it, and serve a package's assets under
/// `assets/packages/`; any other web build serves the package's `lib/` under
/// `packages/`.
const bool _flutter = bool.fromEnvironment('dart.library.ui');

/// For this package's own browser tests, which cannot pass a define to
/// dart2wasm: the variant to load instead of the define's. Not API.
bool? debugPython;

/// The engine library this program loaded, and what it binds.
abstract final class RippleEngine {
  /// The contract these bindings bind: `MAJOR.MINOR`.
  static const String boundContract = '1.6';

  static Future<_Loaded>? _loading;
  static _Loaded? _loaded;

  /// Loads the engine: on the web, imports its glue, compiles it and makes
  /// the instance the engine-level calls answer from. Once; every open
  /// awaits it, so a host need only call it to choose [base] — where the
  /// engine's files are served from, when not from this package's assets (a
  /// CDN, say): a URL holding `python/`, `no-python/`, `wasi.js` and
  /// `bridge.js`.
  static Future<void> load({Uri? base}) async {
    _loaded ??= await (_loading ??= _load(base));
  }

  /// The engine library's version, `1.6.0`.
  static String get version => _require().version;

  /// The contract the loaded engine binds, `1.6`.
  static String get contract {
    final parts = version.split('.');
    return '${parts[0]}.${parts[1]}';
  }

  /// Whether the loaded engine runs scripts: false for the `no-python` one,
  /// which `RIPPLEFX_PYTHON=false` selects on the web.
  static bool get hasPython => _require().python;

  /// How many things the engine handed out and has not had back: always
  /// zero on the web, where everything crosses as a copy and the garbage
  /// collector frees it.
  static int get outstanding => 0;

  /// Native's check that the library is there and binds this contract; on
  /// the web, that [load] has been awaited.
  static void ensureLoaded() => _require();

  static _Loaded _require() =>
      _loaded ??
      (throw EngineNotFoundException(
        'The Ripple Effect engine is not loaded yet: on the web it is '
        'fetched and compiled first. Await RippleEngine.load(), or open a '
        'campaign, which awaits it.',
      ));

  /// A fresh instance of the engine, for one campaign.
  static Future<Instance> instance() async {
    await load();
    final root = await _loaded!.factory
        .callMethod<JSPromise<JSObject>>('instantiate'.toJS)
        .toDart;
    return Instance(root);
  }

  /// The page-wide instance: what `version`, `hasPython`, a `Mixer` made on
  /// its own and a value's story text are asked of.
  static Instance get page => _require().page;

  static Future<_Loaded> _load(Uri? base) async {
    final root =
        base ??
        Uri.parse(web.document.baseURI).resolve(
          _flutter
              ? 'assets/packages/ripplefx_engine/lib/src/web/engine/'
              : 'packages/ripplefx_engine/src/web/engine/',
        );
    final dir = root.path.endsWith('/')
        ? root
        : root.replace(path: '${root.path}/');
    final python = debugPython ?? _pythonDefine;
    try {
      bridge = Bridge(
        await importModule(dir.resolve('bridge.js').toString().toJS).toDart,
      );
      final factory = await bridge
          .engine(dir.toString().toJS, (python ? 'python' : 'no-python').toJS)
          .toDart;
      final page = Instance(
        await factory
            .callMethod<JSPromise<JSObject>>('instantiate'.toJS)
            .toDart,
      );
      final engine = page.namespace('engine');
      final version = str(page.call(engine, 'version'));
      final loaded = _Loaded(
        factory,
        page,
        version,
        flag(page.call(engine, 'hasPython')),
      );
      final contract = version.split('.').take(2).join('.');
      if (contract != boundContract) {
        throw EngineNotFoundException(
          'The engine at $dir binds contract $contract, and these bindings '
          'bind $boundContract.',
        );
      }
      return loaded;
    } on EngineNotFoundException {
      _loading = null;
      rethrow;
    } catch (error) {
      _loading = null;
      throw EngineNotFoundException(
        'The Ripple Effect engine could not be loaded from $dir. A Flutter '
        'web build serves it from this package\'s assets and any other web '
        'build from packages/ripplefx_engine/; a host serving it elsewhere '
        'names the place with RippleEngine.load(base:).',
        error,
      );
    }
  }
}

final class _Loaded {
  _Loaded(this.factory, this.page, this.version, this.python);

  final JSObject factory;
  final Instance page;
  final String version;
  final bool python;
}
