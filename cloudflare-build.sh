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

# Prepare BACKEND_URL argument if API_URL environment variable is provided
DART_DEFINES=""
if [ ! -z "$API_URL" ]; then
  CLEAN_URL=$API_URL
  # Add https:// prefix if it's missing (e.g. dirxploreweb-production.up.railway.app)
  if [[ ! $CLEAN_URL =~ ^https?:// ]]; then
    CLEAN_URL="https://$CLEAN_URL"
  fi
  echo "Detected API_URL environment variable. Injecting BACKEND_URL=$CLEAN_URL into the build."
  DART_DEFINES="--dart-define=BACKEND_URL=$CLEAN_URL"
else
  echo "No API_URL environment variable detected. Falling back to localhost:3000"
fi

flutter build web --release $DART_DEFINES

echo "=== Build Complete ==="
