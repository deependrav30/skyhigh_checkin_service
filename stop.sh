#!/bin/bash

# Stop all SkyHigh services

echo "🛑 Stopping SkyHigh Check-In Service..."

# Kill Node processes for the project
pkill -f "tsx.*server.ts" && echo "✓ API server stopped"
pkill -f "tsx.*worker.ts" && echo "✓ Worker stopped"
pkill -f "vite.*skyhigh" && echo "✓ Web UI stopped"

# Stop Docker services (optional - comment out if you want to keep them running)
# docker-compose stop postgres redis && echo "✓ Docker services stopped"

echo ""
echo "✅ All services stopped"
