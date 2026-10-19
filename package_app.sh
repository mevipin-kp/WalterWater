#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
"$ROOT/build_app.sh"
pkgbuild \
    --component "$ROOT/build/Walter Water.app" \
    --install-location /Applications \
    --identifier com.walterwater.reminder \
    --version 1.0 \
    "$ROOT/build/Walter Water.pkg"
printf 'Created %s\n' "$ROOT/build/Walter Water.pkg"
