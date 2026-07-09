#!/usr/bin/env bash
# scheduler.sh — Blog Engine v2 Publish Scheduler
# Checks the approved queue and publishes per freshness rules.
# Designed to run as a daily cron job.
# 
# Rules:
#   1. Never publish if queue is empty
#   2. Minimum 4-day gap between publishes
#   3. Never publish two posts on the same day
#   4. Never publish 3 consecutive posts with the same primary tag

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BLOG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APPROVED_DIR="$BLOG_DIR/content/posts/approved"
PUBLISHED_DIR="$BLOG_DIR/content/posts"
SCHEDULER_LOG="$BLOG_DIR/content/posts/publish-scheduler.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$SCHEDULER_LOG"; echo -e "$1"; }

# --- Rule 1: Empty queue check ---
shopt -s nullglob
APPROVED_POSTS=("$APPROVED_DIR"/*.md)
if [ ${#APPROVED_POSTS[@]} -eq 0 ]; then
  log "${YELLOW}⏭️  Queue empty — nothing to publish${NC}"
  exit 0
fi

log "${YELLOW}📋 Scheduler check — ${#APPROVED_POSTS[@]} post(s) in queue${NC}"

# --- Rule 2: Minimum 4-day gap ---
# Find the most recently published post
LAST_PUB_DATE=""
for f in "$PUBLISHED_DIR"/*.md; do
  BASENAME=$(basename "$f" .md)
  # Extract date from filename YYYY-MM-DD-slug
  if [[ "$BASENAME" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
    FDATE="${BASH_REMATCH[1]}"
    if [[ "$FDATE" > "$LAST_PUB_DATE" || -z "$LAST_PUB_DATE" ]]; then
      LAST_PUB_DATE="$FDATE"
    fi
  fi
done

if [ -n "$LAST_PUB_DATE" ]; then
  TODAY=$(date +%Y-%m-%d)
  # Calculate days since last publish
  LAST_SEC=$(date -d "$LAST_PUB_DATE" +%s 2>/dev/null || echo 0)
  TODAY_SEC=$(date -d "$TODAY" +%s 2>/dev/null || echo 0)
  if [ "$LAST_SEC" -gt 0 ] && [ "$TODAY_SEC" -gt 0 ]; then
    DAYS_SINCE=$(( (TODAY_SEC - LAST_SEC) / 86400 ))
    if [ "$DAYS_SINCE" -lt 4 ]; then
      log "${YELLOW}⏳ Too soon — last publish was $LAST_PUB_DATE ($DAYS_SINCE days ago, need 4)${NC}"
      exit 0
    fi
  fi
fi

# --- Rule 3: Never publish two on the same day ---
TODAY=$(date +%Y-%m-%d)
for f in "$PUBLISHED_DIR"/*.md; do
  BASENAME=$(basename "$f" .md)
  if [[ "$BASENAME" == "$TODAY"* ]]; then
    log "${YELLOW}⚠️  Already published today — skipping${NC}"
    exit 0
  fi
done

# --- Rule 4: Tag diversity check ---
# Get primary tag of the approved post (first tag)
CANDIDATE="${APPROVED_POSTS[0]}"
CANDIDATE_TAG=$(grep -m1 '^\s*-\s' "$CANDIDATE" | sed 's/^\s*-\s*//' | sed 's/"//g' || echo "")

if [ -n "$CANDIDATE_TAG" ]; then
  # Count last 2 published posts' primary tags
  TAG_COUNT=0
  for f in $(ls -t "$PUBLISHED_DIR"/*.md 2>/dev/null | head -2); do
    PTAG=$(grep -m1 '^\s*-\s' "$f" | sed 's/^\s*-\s*//' | sed 's/"//g' || echo "")
    if [ "$PTAG" = "$CANDIDATE_TAG" ]; then
      TAG_COUNT=$((TAG_COUNT + 1))
    fi
  done
  if [ "$TAG_COUNT" -ge 2 ]; then
    log "${YELLOW}⛔ Tag diversity violation — '$CANDIDATE_TAG' would be 3rd consecutive with same tag${NC}"
    exit 0
  fi
fi

# --- All checks passed — publish ---
CANDIDATE_SLUG=$(basename "$CANDIDATE" .md)
log "${GREEN}🚀 Publishing: $CANDIDATE_SLUG${NC}"

"$SCRIPT_DIR/publish.sh" "$CANDIDATE_SLUG" 2>&1 | while IFS= read -r line; do
  log "  $line"
done

log "${GREEN}✅ Scheduler complete${NC}"
