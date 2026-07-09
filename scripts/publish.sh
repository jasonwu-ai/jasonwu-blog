#!/usr/bin/env bash
# publish.sh — Blog Engine v2 Publish Script
# Moves an approved post from queue, builds, commits, pushes.
# Usage: ./publish.sh <post-slug>
#   <post-slug> matches filename in content/posts/approved/<post-slug>.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BLOG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APPROVED_DIR="$BLOG_DIR/content/posts/approved"
PUBLISHED_DIR="$BLOG_DIR/content/posts"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ $# -lt 1 ]; then
  echo "Usage: $0 <post-slug>"
  echo ""
  echo "Available approved posts:"
  ls -1 "$APPROVED_DIR"/*.md 2>/dev/null | sed 's|.*/||; s|\.md$||' || echo "  (none)"
  exit 1
fi

SLUG="$1"
POST_FILE="$SLUG.md"
APPROVED_PATH="$APPROVED_DIR/$POST_FILE"

if [ ! -f "$APPROVED_PATH" ]; then
  echo -e "${RED}Error: '$POST_FILE' not found in $APPROVED_DIR${NC}"
  echo "Available approved posts:"
  ls -1 "$APPROVED_DIR"/*.md 2>/dev/null | sed 's|.*/||; s|\.md$||' || echo "  (none)"
  exit 1
fi

echo -e "${YELLOW}📋 Publishing: $SLUG${NC}"

# Read the current post to check frontmatter
HEADER=$(head -20 "$APPROVED_PATH")

# Check if already published
if echo "$HEADER" | grep -q "status: published"; then
  echo -e "${YELLOW}⚠️  Post '$SLUG' is already published. Skipping.${NC}"
  exit 0
fi

# Compute target path
TODAY=$(date +%Y-%m-%d)
PUBLISH_PATH="$PUBLISHED_DIR/$POST_FILE"

# Update frontmatter: set date=today, draft=false, status=published
echo -e "${GREEN}📝 Updating frontmatter...${NC}"
# Use awk to modify the frontmatter
awk -v today="$TODAY" '
BEGIN { in_frontmatter = 0 }
/^\+\+\+$/ {
  in_frontmatter++
  if (in_frontmatter == 2) {
    print "date: " today
    print "draft: false"
    print "status: published"
  }
  print
  next
}
in_frontmatter == 1 {
  # Skip existing date, draft, status lines
  if ($0 ~ /^date:/) next
  if ($0 ~ /^draft:/) next
  if ($0 ~ /^status:/) next
}
{ print }
' "$APPROVED_PATH" > "$PUBLISH_PATH"

# Verify the post was written
if [ ! -f "$PUBLISH_PATH" ]; then
  echo -e "${RED}Error: Failed to write published post${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Post written to: $PUBLISH_PATH${NC}"

# Build Hugo
echo -e "${YELLOW}🏗️  Building Hugo site...${NC}"
cd "$BLOG_DIR"
if hugo --minify 2>&1; then
  echo -e "${GREEN}✅ Hugo build successful${NC}"
else
  echo -e "${RED}Error: Hugo build failed${NC}"
  exit 1
fi

# Remove from approved queue
rm "$APPROVED_PATH"
echo -e "${GREEN}✅ Removed from approved queue${NC}"

# Git commit and push
echo -e "${YELLOW}📤 Committing and pushing to GitHub...${NC}"
cd "$BLOG_DIR"
git add -A
git commit -m "publish: $SLUG — $TODAY"
git push origin main

echo -e "${GREEN}✅ Published: $SLUG → https://blog.jasonwu.ai/posts/$SLUG/${NC}"
echo -e "${GREEN}✅ Cloudflare Pages deploying...${NC}"
