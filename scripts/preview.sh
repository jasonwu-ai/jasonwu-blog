#!/usr/bin/env bash
# preview.sh — Blog Engine v2 Review Preview Server
# Starts Hugo dev server on Tailscale IP for Jason to preview drafts.
# Usage: ./preview.sh [port]
#   Default port: 8080

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BLOG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PORT="${1:-8080}"

# Get Tailscale IP
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "100.x.x.x")

echo "============================================"
echo "  Blog Engine v2 — Review Preview Server"
echo "============================================"
echo ""
echo "  Review URL: http://$TAILSCALE_IP:$PORT"
echo "  Post URL:   http://$TAILSCALE_IP:$PORT/posts/<slug>/"
echo ""
echo "  Serving content from: $BLOG_DIR/content"
echo "  Press Ctrl+C to stop"
echo "============================================"

cd "$BLOG_DIR"
exec hugo server \
  --bind 0.0.0.0 \
  --port "$PORT" \
  --baseURL "http://$TAILSCALE_IP:$PORT" \
  --buildDrafts \
  --disableFastRender \
  --navigateToChanged
