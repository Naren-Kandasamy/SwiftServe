#!/bin/bash

echo "========================================================"
echo "       SwiftServe Platform - Web-Only Starter           "
echo "========================================================"

# Check and setup .env files automatically if missing
if [ ! -f "dashboard/.env" ]; then
    echo "⚠️  dashboard/.env not found! Auto-generating from .env.example..."
    cp dashboard/.env.example dashboard/.env
    echo "👉 Remember to fill in your API keys in dashboard/.env"
fi

if [ ! -f "guest_app/.env" ]; then
    echo "⚠️  guest_app/.env not found! Auto-generating from .env.example..."
    cp guest_app/.env.example guest_app/.env
    echo "👉 Remember to fill in your API keys in guest_app/.env"
fi

echo ""
echo "📦 Running Flutter pub get..."
(cd dashboard && flutter pub get > /dev/null)
(cd guest_app && flutter pub get > /dev/null)

echo ""
echo "🚀 Launching Dashboard (Admin Portal) in Chrome..."
cd dashboard
# Dashboard on port 5000
flutter run -d chrome --web-port 5000 &
DASHBOARD_PID=$!
cd ..

echo "🚀 Launching Guest App in Chrome..."
cd guest_app
# Guest app forced to Chrome on port 8080
flutter run -d chrome --web-port 8080 &
GUEST_APP_PID=$!
cd ..

echo ""
echo "✅ Apps are starting up in Chrome windows! "
echo "🛑 Press [CTRL+C] anytime to gracefully stop both servers."
echo "========================================================"

# Trap CTRL+C to kill both background Flutter processes
trap "echo -e '\nStopping servers...'; kill $DASHBOARD_PID; kill $GUEST_APP_PID; exit" INT

wait
