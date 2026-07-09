#!/usr/bin/env bash
# approve.sh — Blog Engine v2 Approve Post
# Moves a reviewed draft from content/posts/ to content/posts/approved/
# Usage: ./approve.sh <post-slug>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BLOG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
POSTS_DIR="$BLOG_DIR/content/posts"
APPROVED_DIR="$POSTS_DIR/approved"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ $# -lt 1 ]; then
  echo "Usage: $0 <post-slug>"
  echo ""
  echo "Available posts in content/posts/:"
  ls -1 "$POSTS_DIR"/*.md 2>/dev/null | sed 's|.*/||; s|\.md$||' || echo "  (none)"
  exit 1
fi

SLUG="$1"
POST_FILE="$SLUG.md"
POST_PATH="$POSTS_DIR/$POST_FILE"

if [ ! -f "$POST_PATH" ]; then
  echo -e "${RED}Error: '$POST_FILE' not found in $POSTS_DIR${NC}"
  exit 1
fi

# Check if already approved
if [ -f "$APPROVED_DIR/$POST_FILE" ]; then
  echo -e "${YELLOW}⚠️  Post '$SLUG' is already approved.${NC}"
  exit 0
fi

echo -e "${GREEN}✅ Approving post: $SLUG${NC}"
mkdir -p "$APPROVED_DIR"
cp "$POST_PATH" "$APPROVED_DIR/$POST_FILE"
echo -e "${GREEN}✅ Post moved to approved queue: $APPROVED_DIR/$POST_FILE${NC}"

echo ""
echo "The post is now in the publish queue."
echo "The scheduler will publish it per freshness rules."
echo "To publish immediately:  ./scripts/publish.sh $SLUG"
