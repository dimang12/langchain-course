#!/bin/bash
set -e

echo "=== RAG Assistant - Flutter Build ==="

cd rag_assistant

echo "[1/5] Getting dependencies..."
flutter pub get

echo "[2/5] Running analysis..."
flutter analyze

echo "[3/5] Building Web..."
flutter build web --release
echo "  Web build: build/web/"

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "[4/5] Building macOS..."
    flutter build macos --release
    echo "  macOS build: build/macos/Build/Products/Release/"
else
    echo "[4/5] Skipping macOS (not on macOS)"
fi

echo "[5/5] Build summary:"
echo "  Web:     rag_assistant/build/web/ (deploy to any static host)"
echo "  Android: Run 'flutter build appbundle --release'"
echo "  iOS:     Run 'flutter build ipa --release' (requires Xcode)"
echo "  macOS:   See above"
echo "  Windows: Run 'flutter build windows --release' (requires Windows)"

echo ""
echo "=== Build Complete ==="
