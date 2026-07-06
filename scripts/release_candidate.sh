#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: scripts/release_candidate.sh <version>" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Running tests"
swift test

echo "==> Building DMGs"
scripts/package_dmg.sh "$VERSION" arm64
scripts/package_dmg.sh "$VERSION" x86_64

echo "==> Release candidate ready"
echo "$ROOT_DIR/dist/树懒书摘-$VERSION-arm64.dmg"
echo "$ROOT_DIR/dist/树懒书摘-$VERSION-x86_64.dmg"
