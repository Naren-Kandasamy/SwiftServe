#!/bin/bash

# Netlify Build Script for CrisisNet Flutter Monorepo
# This script handles installing Flutter and building both sub-apps.

FLUTTER_VERSION="3.19.0"

echo "--- 🚀 Starting Netlify Build Script ---"

# 1. Install Flutter if it's not already in the cache
if [ ! -d "flutter" ]; then
  echo "📥 Downloading Flutter SDK ($FLUTTER_VERSION)..."
  curl -C - -O https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz
  tar xf flutter_linux_${FLUTTER_VERSION}-stable.tar.xz
else
  echo "✅ Flutter SDK found in cache."
fi

# Add flutter to the path for this session
export PATH="$PATH:`pwd`/flutter/bin"

echo "📦 Running Flutter Pre-flight..."
flutter doctor

# 2. Build Dashboard (Admin)
echo "🏗️ Building Dashboard..."
cd dashboard
flutter pub get
flutter build web --release --base-href "/admin/"
cd ..

# 3. Build Guest App
echo "🏗️ Building Guest App..."
cd guest_app
flutter pub get
flutter build web --release --base-href "/guest/"
cd ..

# 4. Prepare Dist Folder
echo "📂 Consolidating build files into /dist..."
mkdir -p dist/admin
mkdir -p dist/guest

cp -r dashboard/build/web/* dist/admin/
cp -r guest_app/build/web/* dist/guest/

echo "--- ✅ Build Complete! ---"
