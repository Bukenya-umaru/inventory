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
if [ -z "$API_BASE_URL" ]; then
  echo "ERROR: API_BASE_URL is not set."
  echo "Add it in Vercel -> Project Settings -> Environment Variables"
  echo "(e.g. https://your-backend.onrender.com/api) and redeploy."
  exit 1
fi

cat > .env <<EOF
API_BASE_URL=${API_BASE_URL}
API_BASE_URL_ANDROID=${API_BASE_URL_ANDROID:-http://10.0.2.2:5000/api}
APP_NAME=${APP_NAME:-Inventory Management}
EOF

echo "Building with API_BASE_URL=${API_BASE_URL}"

flutter pub get
flutter build web --release
