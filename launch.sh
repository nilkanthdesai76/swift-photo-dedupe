#!/bin/bash
set -e

# PhotoHashKit One-Click Launcher & Tester
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo "==================================================================="
echo "  📸 PhotoHashKit — Cool & Fast Photo Deduplication Engine"
echo "  dHash + pHash Dual Fingerprinting • Zero Device Heating"
echo "==================================================================="

echo "🔨 Building Swift Photo Dedupe package..."
swift build -c release

echo "🧪 Running unit tests..."
swift test

echo ""
echo "🚀 Running CLI Benchmark Mode..."
.build/release/PhotoDedupeCLI

echo ""
echo "🖥️ Launching SwiftUI PhotoDedupeApp GUI..."
.build/release/PhotoDedupeApp &
APP_PID=$!
echo "✅ App launched with PID: $APP_PID"
