#!/usr/bin/env bash
# The Flame example as an Android app, built as a consumer builds one, and
# its APK held to the pinned engine: each 64-bit ABI's library must be the
# release's Android build of that ABI and variant — a name in the right
# folder proves nothing about what is inside it. Not byte for byte: the
# Android Gradle plugin strips every native library it packages, so what is
# compared is the code and the read-only data, `.text` and `.rodata`, which
# a strip never touches and in which the two variants differ.
#
#   scripts/check-android.sh [python|no-python]
#
# Needs Flutter, an Android SDK (ANDROID_HOME) with its NDK, and a JDK 17.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
variant="${1:-python}"
cd "$root"
die() { echo "check-android: $*" >&2; exit 1; }
objcopy="$(command -v llvm-objcopy || ls "${ANDROID_HOME:-$HOME/Android/Sdk}"/ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-objcopy 2>/dev/null | tail -1)"
[ -x "$objcopy" ] || die "no llvm-objcopy, on PATH or in the Android NDK"
# A library's code and read-only data, as one digest.
code() {
  "$objcopy" --dump-section .text="$work/text" --dump-section .rodata="$work/rodata" "$1" "$work/discard"
  cat "$work/text" "$work/rodata" | sha256sum | cut -d' ' -f1
}

trap 'dart run tool/variant.dart python >/dev/null' EXIT
dart run tool/variant.dart "$variant" >/dev/null
dart run tool/engine.dart fetch --conformance >/dev/null
engine="$(jq -r .engine engine.json)"

# The example is a package of its own; its user-defines are its pubspec's,
# so the variant is written there too for the build.
example="$root/example/flame_player"
cp "$example/pubspec.yaml" "$example/pubspec.yaml.bak"
trap 'mv "$example/pubspec.yaml.bak" "$example/pubspec.yaml"; dart run tool/variant.dart python >/dev/null' EXIT
if [ "$variant" = no-python ]; then
  printf '\nhooks:\n  user_defines:\n    ripplefx_engine:\n      python: false\n' >> "$example/pubspec.yaml"
fi
(cd "$example" && dart run tool/prepare.dart >/dev/null && flutter build apk --debug)
apk="$example/build/app/outputs/flutter-apk/app-debug.apk"
[ -f "$apk" ] || die "no APK at $apk"

work="$(mktemp -d)"
trap 'rm -rf "$work"; mv "$example/pubspec.yaml.bak" "$example/pubspec.yaml"; dart run tool/variant.dart python >/dev/null' EXIT
for pair in arm64-v8a:aarch64-linux-android x86_64:x86_64-linux-android; do
  abi="${pair%%:*}" triple="${pair##*:}"
  dart run tool/engine.dart fetch --target "$triple" --variant "$variant" >/dev/null
  want="$root/out/engine/$engine/$variant/$triple/lib/libripple_effect_engine.so"
  unzip -o -q "$apk" "lib/$abi/libripple_effect_engine.so" -d "$work/$abi" \
    || die "the APK has no lib/$abi/libripple_effect_engine.so"
  got="$work/$abi/lib/$abi/libripple_effect_engine.so"
  [ "$(code "$got")" = "$(code "$want")" ] || die "lib/$abi/libripple_effect_engine.so is not engine $engine's $variant $triple build"
  echo "check-android: lib/$abi is engine $engine's $variant $triple build"
done
