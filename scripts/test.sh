#!/bin/zsh
# Runs the CleaningCore unit tests.
# With only the Command Line Tools installed (no Xcode), swift-testing's macro
# plugin lives in a subfolder the compiler doesn't search, so point it there.
set -euo pipefail
cd "${0:A:h:h}"
PLUGINS=/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
if [[ -d "$PLUGINS" ]]; then
  swift test -Xswiftc -plugin-path -Xswiftc "$PLUGINS" "$@"
else
  swift test "$@"
fi
