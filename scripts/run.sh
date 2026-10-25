#!/bin/bash
# Rebuilds and relaunches Murmur. Extra arguments go to the app, e.g. --allow-capture.
set -euo pipefail
cd "$(dirname "$0")/.."

app="$(scripts/build.sh "${CONFIG:-release}" | tail -1)"
pkill -x Murmur 2>/dev/null || true
sleep 0.3
open -n "$app" --args "$@"
