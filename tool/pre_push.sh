#!/usr/bin/env bash
# The pre-push hook: format, analysis and the whole suite in both variants,
# on the pinned engine. What CI's format and test jobs run, on this machine.
set -euo pipefail
cd "$(dirname "$0")/.."
trap 'dart run tool/variant.dart python >/dev/null' EXIT
dart format --set-exit-if-changed --output=none .
dart analyze --fatal-infos
dart run tool/engine.dart fetch --conformance >/dev/null
RIPPLE_VARIANT=python dart test
dart run tool/variant.dart no-python >/dev/null
RIPPLE_VARIANT=no-python dart test
