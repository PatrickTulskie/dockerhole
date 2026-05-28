#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "Pulling latest images..."
docker compose pull

echo "Restarting containers..."
docker compose up -d --remove-orphans

echo "Pruning unused images..."
docker image prune -f

echo "Checking service health..."
sleep 5

if docker compose ps | grep -q "Up"; then
  echo "Services are running."
else
  echo "Warning: services may not have started correctly. Run: docker compose ps"
  exit 1
fi
