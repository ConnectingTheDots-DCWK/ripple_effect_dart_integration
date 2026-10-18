#!/usr/bin/env bash
# The pre-push hook: format, analysis and the whole suite in both variants,
# on the pinned engine, natively and in Chrome under both web compilers:
# what CI's format, test and web jobs run, on this machine.
set -euo pipefail
cd "$(dirname "$0")/.."
trap 'dart run tool/variant.dart python >/dev/null' EXIT
dart format --set-exit-if-changed --output=none .
dart analyze --fatal-infos
dart run tool/engine.dart fetch --conformance --web >/dev/null
[ -d tool/web/node_modules ] || (cd tool/web && npm ci --ignore-scripts >/dev/null)
node tool/web/build.mjs >/dev/null
dart run tool/variant.dart python >/dev/null
RIPPLE_VARIANT=python dart test
dart test -p chrome --compiler dart2js,dart2wasm
dart run tool/variant.dart no-python >/dev/null
RIPPLE_VARIANT=no-python dart test
dart test -p chrome --compiler dart2js,dart2wasm
