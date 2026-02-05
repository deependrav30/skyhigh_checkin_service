#!/bin/bash

# SkyHigh Check-In Service Startup Script

set -e

echo "🚀 Starting SkyHigh Check-In Service..."
echo ""

# Check if Docker services are running
echo "📦 Checking Docker services..."
if ! docker ps | grep -q skyhigh-postgres; then
    echo "Starting Postgres and Redis..."
    docker-compose up -d postgres redis
    echo "⏳ Waiting for services to be ready..."
    sleep 5
fi
echo "✓ Docker services running"
echo ""

# Check if migrations have been applied
echo "🗄️  Checking database migrations..."
cd api
if ! npm run migrate 2>&1 | grep -q "No pending migrations"; then
    echo "✓ Migrations applied"
else
    echo "✓ Database up to date"
fi
cd ..
echo ""

# Start API server
echo "🌐 Starting API server (port 3002)..."
cd api
npx tsx src/server.ts > /dev/null 2>&1 &
API_PID=$!
echo "✓ API server started (PID: $API_PID)"

# Start worker service
echo "⚙️  Starting worker service..."
npx tsx src/worker.ts > /dev/null 2>&1 &
WORKER_PID=$!
echo "✓ Worker started (PID: $WORKER_PID)"
cd ..

# Wait for API to be ready
echo "⏳ Waiting for API to be ready..."
for i in {1..10}; do
    if curl -s http://localhost:3002/health > /dev/null 2>&1; then
        echo "✓ API is ready"
        break
    fi
    sleep 1
done

# Start web UI
echo "🎨 Starting Web UI (port 5173)..."
cd web
npm run dev > /dev/null 2>&1 &
WEB_PID=$!
echo "✓ Web UI started (PID: $WEB_PID)"
cd ..

echo ""
echo "✅ All services started successfully!"
echo ""
echo "🌐 Access the application:"
echo "   • Web UI:    http://localhost:5173"
echo "   • API Docs:  http://localhost:3002/docs"
echo "   • API Health: http://localhost:3002/health"
echo ""
echo "🛑 To stop all services, run:"
echo "   kill $API_PID $WORKER_PID $WEB_PID"
echo ""
echo "💡 Demo credentials: PNR=DEMO123, Last Name=demo"
