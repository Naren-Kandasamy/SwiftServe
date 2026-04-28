#!/bin/bash
set -e

# Build dashboard → /admin
cd dashboard
flutter build web --base-href /admin/
cd ..

# Build guest_app → /guest
cd guest_app
flutter build web --base-href /guest/
cd ..

# Assemble into a single output dir
mkdir -p dist/admin
mkdir -p dist/guest

cp -r dashboard/build/web/. dist/admin/
cp -r guest_app/build/web/. dist/guest/
