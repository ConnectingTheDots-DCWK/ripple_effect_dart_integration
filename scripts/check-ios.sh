#!/usr/bin/env bash
# The Flame example as an iOS device app, built as a consumer builds one, and
# the app held to the pinned engine: the engine dylib the SDK bundles must be
# the release's iOS device build of that variant. Not byte for byte: the
# Dart/Flutter SDK wraps the bundled dylib in `ripple_effect_engine.framework`,
# rewrites its install name to `@rpath` (the reason the 1.5.4 Apple libraries
# carry header padding) and ad-hoc re-signs it, so what is compared is the code
# and the read-only data, `__TEXT,__text` and `__TEXT,__const`, which neither
# the rename nor the signature touches and in which the two variants differ.
# `otool` reads them, so nothing but Xcode's own tools is needed.
#
#   scripts/check-ios.sh [python|no-python]
#
# The device app is built --no-codesign; running it on a device is not
# required, as with check-android.sh. **The simulator is not built here**: the
# engine ships an arm64 simulator slice only (`aarch64-apple-ios-sim`, no
# x86_64), so `flutter build ios --simulator` — which produces a fat app for
# every simulator architecture — asks for an x86_64 engine that does not exist
# and fails. The simulator is proved instead by the CI job's integration test,
# which builds for one booted arm64 simulator, asserts the bound contract and
# plays a fixture to its end. Needs Flutter and Xcode.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
variant="${1:-python}"
cd "$root"
die() { echo "check-ios: $*" >&2; exit 1; }

# A framework binary's code and read-only data, as one digest. `-X` drops the
# addresses and headers otool would otherwise print, leaving only the bytes.
code() {
  { otool -X -s __TEXT __text "$1"; otool -X -s __TEXT __const "$1"; } | shasum -a 256 | cut -d' ' -f1
}

trap 'dart run tool/variant.dart python >/dev/null' EXIT
dart run tool/variant.dart "$variant" >/dev/null
dart run tool/engine.dart fetch --conformance >/dev/null
engine="$(jq -r .engine engine.json)"

# The example is a package of its own; its user-defines are its pubspec's, so
# the variant is written there too for the build.
example="$root/example/flame_player"
cp "$example/pubspec.yaml" "$example/pubspec.yaml.bak"
trap 'mv "$example/pubspec.yaml.bak" "$example/pubspec.yaml"; dart run tool/variant.dart python >/dev/null' EXIT
if [ "$variant" = no-python ]; then
  printf '\nhooks:\n  user_defines:\n    ripplefx_engine:\n      python: false\n' >> "$example/pubspec.yaml"
fi
(cd "$example" && dart run tool/prepare.dart >/dev/null && flutter build ios --no-codesign)

triple="aarch64-apple-ios"
app="$example/build/ios/iphoneos/Runner.app"
fw="$app/Frameworks/ripple_effect_engine.framework/ripple_effect_engine"
[ -f "$fw" ] || die "the app has no ripple_effect_engine.framework at $fw"

id="$(otool -D "$fw" | tail -1)"
[ "$id" = "@rpath/ripple_effect_engine.framework/ripple_effect_engine" ] \
  || die "the framework install name is '$id', not an @rpath one"
# The iOS device SDK is platform 2 (the simulator would be 7); a device build
# carrying a simulator slice would be the wrong archive bundled.
platform="$(otool -l "$fw" | awk '/LC_BUILD_VERSION/{f=1} f&&/platform/{print $2; f=0}' | head -1)"
[ "$platform" = 2 ] || die "the framework is platform $platform, not 2 (iOS device)"
case "$(lipo -archs "$fw")" in *arm64*) ;; *) die "the framework is not arm64" ;; esac

dart run tool/engine.dart fetch --target "$triple" --variant "$variant" >/dev/null
want="$root/out/engine/$engine/$variant/$triple/lib/libripple_effect_engine.dylib"
[ -f "$want" ] || die "no pinned engine at $want"
[ "$(code "$fw")" = "$(code "$want")" ] \
  || die "ripple_effect_engine.framework is not engine $engine's $variant $triple build"
echo "check-ios: the device framework is engine $engine's $variant $triple build, @rpath, platform 2"
