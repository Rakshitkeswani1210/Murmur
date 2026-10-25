#!/bin/bash
# Runs the tests. With only the Command Line Tools installed, SwiftPM needs to be told
# where Swift Testing lives; with Xcode installed plain `swift test` also works.
set -euo pipefail
cd "$(dirname "$0")/.."

clt=/Library/Developer/CommandLineTools/Library/Developer
if [ -d "$clt/Frameworks/Testing.framework" ]; then
    swift test \
        -Xswiftc -F -Xswiftc "$clt/Frameworks" \
        -Xlinker -F -Xlinker "$clt/Frameworks" \
        -Xlinker -rpath -Xlinker "$clt/Frameworks" \
        -Xlinker -rpath -Xlinker "$clt/usr/lib" "$@"
else
    swift test "$@"
fi
