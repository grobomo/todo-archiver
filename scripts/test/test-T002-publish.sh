#!/usr/bin/env bash
# Test T002: Verify project structure for grobomo publishing
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0

check() {
  local label="$1" path="$2"
  if [ -f "$PROJECT_DIR/$path" ]; then
    echo "  PASS: $label"
    ((++PASS))
  else
    echo "  FAIL: $label ($path missing)"
    ((++FAIL))
  fi
}

echo "Test: Project structure for grobomo publish"
check "publish.json exists" ".github/publish.json"
check "README.md exists" "README.md"
check "LICENSE exists" "LICENSE"
check "todo_archive.py exists" "todo_archive.py"

# Verify publish.json content
if [ -f "$PROJECT_DIR/.github/publish.json" ]; then
  WIN_PATH=$(cygpath -w "$PROJECT_DIR/.github/publish.json" 2>/dev/null || echo "$PROJECT_DIR/.github/publish.json")
  ACCOUNT=$(python -c "import json,sys; print(json.load(open(sys.argv[1]))['github_account'])" "$WIN_PATH")
  if [ "$ACCOUNT" = "grobomo" ]; then
    echo "  PASS: publish.json has grobomo account"
    ((++PASS))
  else
    echo "  FAIL: publish.json account is $ACCOUNT, expected grobomo"
    ((++FAIL))
  fi
fi

# Verify git config
cd "$PROJECT_DIR"
GIT_NAME=$(git config user.name || echo "")
if [ "$GIT_NAME" = "grobomo" ]; then
  echo "  PASS: git user.name is grobomo"
  ((++PASS))
else
  echo "  FAIL: git user.name is '$GIT_NAME', expected grobomo"
  ((++FAIL))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
