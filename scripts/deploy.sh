#!/bin/bash
set -e

echo "=== RAG Assistant - Backend Deployment ==="

# Check for .env
if [ ! -f rag-backend/.env ]; then
    echo "Error: rag-backend/.env not found"
    echo "Copy .env.production.example and fill in your values:"
    echo "  cp rag-backend/.env.production.example rag-backend/.env"
    exit 1
fi

echo "[1/3] Building Docker images..."
cd rag-backend
docker compose build

echo "[2/3] Starting services..."
docker compose up -d

echo "[3/3] Waiting for health check..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
        echo "Backend is healthy!"
        echo ""
        echo "=== Deployment Complete ==="
        echo "  API:     http://localhost:8000"
        echo "  Docs:    http://localhost:8000/docs"
        echo "  Health:  http://localhost:8000/health"
        exit 0
    fi
    sleep 1
done

echo "Error: Health check failed after 30 seconds"
docker compose logs --tail=20
exit 1
