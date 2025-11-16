#!/bin/bash
set -e

echo "🚀 Setting up development environment..."

export PATH="$PATH:/home/codespace/flutter/bin"
mkdir -p /workspaces/family-finance/logs

echo "🗄️ Starting PostgreSQL..."
docker run -d --name postgres-dev --network host \
  -e POSTGRES_DB=familyfinance \
  -e POSTGRES_USER=dev \
  -e POSTGRES_PASSWORD=devpass \
  -p 5432:5432 postgres:15-alpine

echo "⏳ Waiting for PostgreSQL..."
timeout 60 bash -c 'until docker exec postgres-dev pg_isready 2>/dev/null; do sleep 2; done'

if [ -f "/workspaces/family-finance/backend/pom.xml" ]; then
  cd /workspaces/family-finance/backend && chmod +x mvnw && ./mvnw dependency:resolve -q
fi

if [ -f "/workspaces/family-finance/flutter_app/pubspec.yaml" ]; then
  cd /workspaces/family-finance/flutter_app && flutter pub get
fi

chmod +x /workspaces/family-finance/scripts/*.sh

echo "✅ Setup complete! Run: ./scripts/dev.sh"
