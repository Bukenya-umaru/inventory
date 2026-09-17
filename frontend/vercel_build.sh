#!/bin/bash
set -e

# Vercel builders don't ship with Flutter — install it first
if [ ! -d "/tmp/flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable /tmp/flutter
fi
export PATH="/tmp/flutter/bin:$PATH"

flutter config --enable-web --no-analytics

# .env is gitignored, so recreate it at build time from Vercel env vars.
# Set API_BASE_URL in Vercel -> Project Settings -> Environment Variables.
cat > .env <<EOF
API_BASE_URL=${API_BASE_URL:-http://localhost:5000/api}
API_BASE_URL_ANDROID=${API_BASE_URL_ANDROID:-http://10.0.2.2:5000/api}
APP_NAME=${APP_NAME:-Inventory Management}
EOF

flutter pub get
flutter build web --release
