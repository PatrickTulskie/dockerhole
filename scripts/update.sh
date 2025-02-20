#!/bin/bash

# Exit on any error
set -e

echo "🔄 Starting Docker environment update process..."

# Change to the project directory (assumes script is run from scripts directory)
cd "$(dirname "$0")/.."

echo "⬇️  Pulling latest images..."
docker compose pull

echo "🚀 Updating containers..."
docker compose up -d --remove-orphans

echo "🧹 Pruning unused images..."
docker image prune -f

echo "✨ Update complete!"

# Check if services are healthy
echo "🔍 Checking service health..."
sleep 5  # Give services a moment to start

if docker compose ps | grep -q "Up"; then
    echo "✅ Services are running properly!"
else
    echo "❌ Warning: Services might not have started correctly. Please check 'docker compose ps'"
    exit 1
fi