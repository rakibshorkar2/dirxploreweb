#!/bin/bash

# Exit on error
set -e

echo "=== System Info ==="
node -v
npm -v
git --version

echo "=== Downloading Flutter SDK ==="
# Clone only the latest commit from stable branch to minimize download size
git clone https://github.com/flutter/flutter.git -b stable --depth 1

# Add Flutter to PATH
export PATH="$PATH:`pwd`/flutter/bin"

echo "=== Verification ==="
flutter --version

echo "=== Building Flutter Web ==="
flutter config --enable-web
flutter build web --release

echo "=== Build Complete ==="
