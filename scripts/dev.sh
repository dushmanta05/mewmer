#!/usr/bin/env bash

cleanup() {
  echo ""
  echo "Shutting down servers..."
  if [ -n "$BACKEND_PID" ]; then
    kill "$BACKEND_PID" 2>/dev/null || true
  fi
  if [ -n "$FRONTEND_PID" ]; then
    kill "$FRONTEND_PID" 2>/dev/null || true
  fi
  wait 2>/dev/null || true
  exit 0
}

trap cleanup INT TERM EXIT

echo " Starting Go backend on http://localhost:3030..."
(cd server && PORT=3030 go run main.go) &
BACKEND_PID=$!

sleep 1

echo " Starting Astro frontend on http://localhost:3031..."
(cd frontend && pnpm dev) &
FRONTEND_PID=$!

wait
