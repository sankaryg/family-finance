#!/bin/bash
set -e

echo "🚀 Starting FamilyFinance Development"
mkdir -p /workspaces/family-finance/logs

if ! docker ps | grep -q postgres-dev; then
  docker start postgres-dev 2>/dev/null || \
  docker run -d --name postgres-dev --network host \
    -e POSTGRES_DB=familyfinance -e POSTGRES_USER=dev -e POSTGRES_PASSWORD=devpass \
    -p 5432:5432 postgres:15-alpine
  sleep 5
fi

echo "🔧 Starting Backend..."
cd /workspaces/family-finance/backend
./mvnw spring-boot:run > /workspaces/family-finance/logs/backend.log 2>&1 &
BACKEND_PID=$!

echo "⏳ Waiting for backend..."
timeout 120 bash -c 'until curl -s http://localhost:8080/api/health > /dev/null; do sleep 2; done'
echo "✅ Backend ready!"

echo "🎨 Starting Flutter..."
cd /workspaces/family-finance/flutter_app
flutter run -d web-server --web-port=5000 --web-hostname=0.0.0.0 \
  --dart-define=CODESPACE_NAME="${CODESPACE_NAME:-}" > /workspaces/family-finance/logs/flutter.log 2>&1 &
FLUTTER_PID=$!

echo ""
echo "✅ All services started!"
echo ""
if [ -n "$CODESPACE_NAME" ]; then
  echo "📱 Backend: https://${CODESPACE_NAME}-8080.preview.app.github.dev/api"
  echo "📱 Flutter: https://${CODESPACE_NAME}-5000.preview.app.github.dev"
else
  echo "📱 Backend: http://localhost:8080/api"
  echo "📱 Flutter: http://localhost:5000"
fi
echo ""
echo "📝 Logs: tail -f logs/backend.log or logs/flutter.log"
echo "🛑 Stop: Press Ctrl+C"

trap "echo ''; echo 'Stopping...'; kill $BACKEND_PID $FLUTTER_PID 2>/dev/null; echo 'Stopped'; exit" INT
wait
