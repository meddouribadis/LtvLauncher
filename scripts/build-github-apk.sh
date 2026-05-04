#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fvm use

echo "Building GitHub release APK..."
fvm flutter build apk --release --flavor github "$@"

echo
echo "Build completed. APKs are available in:"
echo "  build/app/outputs/apk/github/release/"
echo "  build/app/outputs/flutter-apk/"
