#!/usr/bin/env bash
# `mise run doctor`: this machine against what the repository says it needs,
# and the command that fixes each thing it lacks.
#
# It reads the pins rather than knowing them — mise.toml through
# scripts/mise_pin.sh, and the files that keep their own — and holds a machine
# to two tiers. **Required** is what working on this repository at all needs:
# a commit runs the hooks, a push runs the suite. A miss there fails. The rest
# belongs to one group (a platform, a maintainer's task) and only warns.
#
# It probes with mise's shims first on PATH, as the secret-scan hook puts
# them, and with mise's auto-install off: a shim installs a pin it lacks the
# first time it runs, and a check should report that rather than download it.
#
# The part above "This repository" is the same in every binding; below it is
# this one's list.
set -uo pipefail
cd "$(dirname "$0")/.."

shims="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims"
[ -d "$shims" ] && PATH="$shims:$PATH"
export PATH MISE_AUTO_INSTALL=0

failed=0
fixes=()

have() { command -v "$1" > /dev/null 2>&1; }

# The first version-shaped string a command prints, or nothing.
version_of() { "$@" 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1; }

section() { printf '\n%s\n' "$1"; }

# row <ok 0|1> <required 0|1> <name> <detail> <fix>
row() {
  local mark='✓'
  if [ "$1" != 1 ]; then
    if [ "$2" = 1 ]; then mark='✗' && failed=1; else mark='!'; fi
    fixes+=("$5")
  fi
  printf '  %s %-30s %s\n' "$mark" "$3" "$4"
}

# tool <required> <name> <fix> <command> [args to print a version]
tool() {
  local required=$1 name=$2 fix=$3
  shift 3
  if have "$1"; then
    local found
    found=$(version_of "$@")
    row 1 "$required" "$name" "${found:-present}" "$fix"
  else
    row 0 "$required" "$name" missing "$fix"
  fi
}

# pin <required> <mise.toml key> <command> [version flag]
pin() {
  local required=$1 key=$2 command=$3 flag=${4:---version} wanted found
  wanted=$(bash scripts/mise_pin.sh "$key")
  found=$(have "$command" && version_of "$command" "$flag")
  if [ "$found" = "$wanted" ]; then
    row 1 "$required" "$command" "$wanted" 'mise install'
  else
    row 0 "$required" "$command" "${found:-missing}, wants $wanted" 'mise install'
  fi
}

# check <required> <name> <fix> <test...>
check() {
  local required=$1 name=$2 fix=$3
  shift 3
  if "$@" > /dev/null 2>&1; then row 1 "$required" "$name" '' "$fix"; else row 0 "$required" "$name" '' "$fix"; fi
}

hooks_installed() {
  local dir
  dir=$(git rev-parse --git-path hooks) || return 1
  grep -q pre-commit "$dir/pre-commit" 2> /dev/null && grep -q pre-commit "$dir/pre-push" 2> /dev/null
}

report() {
  if [ ${#fixes[@]} -eq 0 ]; then
    printf '\nEverything this repository asks for is here.\n'
    return
  fi
  printf '\nTo fix:\n'
  printf '%s\n' "${fixes[@]}" | awk '!seen[$0]++ { print "  " $0 }'
  if [ "$failed" = 1 ]; then
    printf '\n✗ is needed to work on this repository at all; ! only by the group it is in.\n'
  fi
}

windows=0
case "$(uname -s)" in MINGW* | MSYS* | CYGWIN*) windows=1 ;; esac

# --- This repository ----------------------------------------------------------

# The SDK the hook and CI's Flutter jobs use is .fvmrc's; fvm keeps it under
# its cache, and `dart` on PATH is whichever the shell put there.
flutter_pin=$(sed -n 's/.*"flutter": *"\([^"]*\)".*/\1/p' .fvmrc)
fvm_sdk="${FVM_CACHE_PATH:-$HOME/fvm}/versions/$flutter_pin"
dart_floor=$(sed -n 's/^ *sdk: *\^\{0,1\}\([0-9.]*\).*/\1/p' pubspec.yaml | head -1)

# at_least <found> <floor>: true when found sorts at or after floor.
at_least() { [ -n "$1" ] && [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

section required
tool 1 fvm 'https://fvm.app/documentation/getting-started/installation' fvm --version
check 1 "Flutter $flutter_pin (.fvmrc)" "fvm install $flutter_pin" test -x "$fvm_sdk/bin/flutter"
dart_found=$(have dart && version_of dart --version)
row "$(at_least "$dart_found" "$dart_floor" && echo 1 || echo 0)" 1 "dart on PATH" "${dart_found:-missing}, the pubspec wants $dart_floor or later" \
  "export PATH=\"$fvm_sdk/bin:\$PATH\""
pin 1 node node
# The hook's web leg runs the suite in Chrome.
if have google-chrome || have chromium || have chromium-browser || [ -n "${CHROME_EXECUTABLE:-}" ]; then
  row 1 1 Chrome '' ''
else
  row 0 1 Chrome missing 'install Chrome or Chromium, or set CHROME_EXECUTABLE'
fi
pin 1 aqua:jqlang/jq jq
pin 1 aqua:trufflesecurity/trufflehog trufflehog
if [ "$windows" = 1 ]; then
  tool 1 pre-commit 'pip install pre-commit' pre-commit --version
else
  pin 1 aqua:pre-commit/pre-commit pre-commit
fi
check 1 'hooks installed' 'pre-commit install --hook-type pre-commit --hook-type pre-push' hooks_installed

section 'the web backend (tool/web)'
check 0 'its packages installed' '(cd tool/web && npm ci --ignore-scripts)' test -d tool/web/node_modules

section 'pinning an engine (scripts/pin-engine.sh)'
tool 0 curl 'your package manager: curl' curl --version
openssl_major=$(have openssl && version_of openssl version | cut -d. -f1)
row "$([ "${openssl_major:-0}" -ge 3 ] && echo 1 || echo 0)" 0 'OpenSSL 3' "${openssl_major:+$(version_of openssl version)}" 'your package manager: openssl 3'

section 'regenerating the bindings (tool/generate)'
tool 0 clang 'your package manager: clang and libclang-dev' clang --version

section android
jdk_major=$(have javac && version_of javac -version | cut -d. -f1)
row "$([ "${jdk_major:-0}" = 17 ] && echo 1 || echo 0)" 0 'JDK 17' "${jdk_major:-missing}" 'your package manager: a JDK 17'
check 0 'Android SDK ($ANDROID_HOME)' 'sdkmanager, then export ANDROID_HOME' test -d "${ANDROID_HOME:-/nonexistent}"

if [ "$(uname -s)" = Linux ]; then
  section 'the Flame example on a Linux desktop'
  check 0 "gstreamer's headers" 'your package manager: libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev' \
    pkg-config --exists gstreamer-1.0 gstreamer-plugins-base-1.0
fi

if [ "$(uname -s)" = Darwin ]; then
  section ios
  tool 0 Xcode 'the App Store' xcodebuild -version
fi

report
exit "$failed"
