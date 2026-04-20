#!/usr/bin/env bash
# generate.sh — Build and run the HALGEN SVD generator
#
# Usage:
#   ./generate.sh [CLI args...]
#
# The script builds the `SwiftAVRGeneratorCLI` target and forwards any
# additional arguments to the resulting executable.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$SCRIPT_DIR/SwiftAVRGenerator.xcodeproj"
SCHEME="SwiftAVRGeneratorCLI"
DERIVED_DATA="$SCRIPT_DIR/.build"
BINARY="$DERIVED_DATA/Build/Products/Release/$SCHEME"
BUILD_LOG="$(mktemp)"

printf "\033[1mHALGEN\033[0m — SVD Generator\n\n"

printf "  Building... "
if xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "$DERIVED_DATA" \
  -quiet \
  >"$BUILD_LOG" 2>&1; then
  printf "\033[32mdone\033[0m\n\n"
else
  printf "\033[31mFAILED\033[0m\n\n"
  cat "$BUILD_LOG"
  rm -f "$BUILD_LOG"
  exit 1
fi
rm -f "$BUILD_LOG"

exec "$BINARY" "$@"
