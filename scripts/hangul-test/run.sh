#!/bin/bash
# Standalone test runner for HangulComposer + CheonjiinInput.
# Tests the pure-Foundation Korean composition logic without launching iOS sim.
#
# Usage: ./scripts/hangul-test/run.sh
set -e
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"
cp "$ROOT/ClipKeyboardExtension/HangulComposer.swift" .
cp "$ROOT/ClipKeyboardExtension/CheonjiinInput.swift" .
swiftc main.swift HangulComposer.swift CheonjiinInput.swift -o runner
./runner
