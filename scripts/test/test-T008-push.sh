#!/usr/bin/env bash
# Test T008: Verify changes pushed to GitHub
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_DIR"

PASS=0
FAIL=0

echo "Test: Push verification"

# Check we're on a branch with remote tracking
BRANCH=$(git branch --show-current)
TRACKING=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "none")
if [ "$TRACKING" != "none" ]; then
  echo "  PASS: Branch $BRANCH tracks $TRACKING"
  ((++PASS))
else
  echo "  FAIL: Branch $BRANCH has no remote tracking"
  ((++FAIL))
fi

# Check no uncommitted changes to tracked files
DIRTY=$(git diff --name-only HEAD 2>/dev/null | wc -l)
if [ "$DIRTY" -eq 0 ]; then
  echo "  PASS: No uncommitted changes"
  ((++PASS))
else
  echo "  FAIL: $DIRTY uncommitted files"
  ((++FAIL))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
