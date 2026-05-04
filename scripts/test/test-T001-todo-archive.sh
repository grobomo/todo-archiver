#!/usr/bin/env bash
# Test todo_archive.py — verifies archival of completed tasks
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ARCHIVE="$PROJECT_DIR/todo_archive.py"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

PASS=0
FAIL=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $label"
    ((++PASS))
  else
    echo "  FAIL: $label"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    ((++FAIL))
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF -- "$needle"; then
    echo "  PASS: $label"
    ((++PASS))
  else
    echo "  FAIL: $label"
    echo "    expected to contain: $needle"
    ((++FAIL))
  fi
}

assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF -- "$needle"; then
    echo "  FAIL: $label"
    echo "    should NOT contain: $needle"
    ((++FAIL))
  else
    echo "  PASS: $label"
    ((++PASS))
  fi
}

# --- Test 1: All-completed section gets archived ---
echo "Test 1: All-completed section archived"
cat > "$TMPDIR/TODO.md" << 'EOF'
# My Project

## Completed
- [x] Task A
- [x] Task B

## Active
- [ ] Task C
EOF

python "$ARCHIVE" "$TMPDIR/TODO.md"
TODO=$(cat "$TMPDIR/TODO.md")
DONE=$(cat "$TMPDIR/TODO-COMPLETED.md")

assert_not_contains "TODO has no Completed header" "## Completed" "$TODO"
assert_contains "TODO keeps Active section" "## Active" "$TODO"
assert_contains "TODO keeps unchecked task" "- [ ] Task C" "$TODO"
assert_contains "TODO has archive comment" "<!-- See TODO-COMPLETED.md" "$TODO"
assert_contains "Archive has Task A" "- [x] Task A" "$DONE"
assert_contains "Archive has Task B" "- [x] Task B" "$DONE"
assert_contains "Archive has timestamp header" "## Archived" "$DONE"

# --- Test 2: Mixed section splits correctly ---
echo "Test 2: Mixed section splits"
rm -f "$TMPDIR/TODO.md" "$TMPDIR/TODO-COMPLETED.md"
cat > "$TMPDIR/TODO.md" << 'EOF'
# Project

## Work Items
- [x] Done item
- [ ] Pending item
- [x] Another done
EOF

python "$ARCHIVE" "$TMPDIR/TODO.md"
TODO=$(cat "$TMPDIR/TODO.md")
DONE=$(cat "$TMPDIR/TODO-COMPLETED.md")

assert_contains "TODO keeps header" "## Work Items" "$TODO"
assert_contains "TODO keeps pending" "- [ ] Pending item" "$TODO"
assert_not_contains "TODO removes done item" "- [x] Done item" "$TODO"
assert_contains "Archive has done item" "- [x] Done item" "$DONE"
assert_contains "Archive has another done" "- [x] Another done" "$DONE"

# --- Test 3: Section with all [x] archived entirely ---
echo "Test 3: All-checked section archived"
rm -f "$TMPDIR/TODO.md" "$TMPDIR/TODO-COMPLETED.md"
cat > "$TMPDIR/TODO.md" << 'EOF'
# Project

## Bug Fixes
- [x] Fix bug 1
- [x] Fix bug 2

## Future
- [ ] Plan something
EOF

python "$ARCHIVE" "$TMPDIR/TODO.md"
TODO=$(cat "$TMPDIR/TODO.md")

assert_not_contains "TODO removes Bug Fixes header" "## Bug Fixes" "$TODO"
assert_contains "TODO keeps Future" "## Future" "$TODO"

# --- Test 4: No completed tasks = no changes ---
echo "Test 4: Nothing to archive"
rm -f "$TMPDIR/TODO.md" "$TMPDIR/TODO-COMPLETED.md"
cat > "$TMPDIR/TODO.md" << 'EOF'
# Project

## Tasks
- [ ] Task 1
- [ ] Task 2
EOF

OUTPUT=$(python "$ARCHIVE" "$TMPDIR/TODO.md")
assert_contains "Reports nothing to archive" "Nothing to archive" "$OUTPUT"
[ ! -f "$TMPDIR/TODO-COMPLETED.md" ] && echo "  PASS: No completed file created" && ((++PASS)) || { echo "  FAIL: Completed file should not exist"; ((++FAIL)); }

# --- Test 5: Dry run doesn't modify files ---
echo "Test 5: Dry run"
rm -f "$TMPDIR/TODO.md" "$TMPDIR/TODO-COMPLETED.md"
cat > "$TMPDIR/TODO.md" << 'EOF'
# Project

## Done
- [x] Finished task
EOF

BEFORE=$(cat "$TMPDIR/TODO.md")
OUTPUT=$(python "$ARCHIVE" --dry-run "$TMPDIR/TODO.md")
AFTER=$(cat "$TMPDIR/TODO.md")

assert_eq "File unchanged after dry run" "$BEFORE" "$AFTER"
assert_contains "Dry run output mentions DRY RUN" "DRY RUN" "$OUTPUT"
[ ! -f "$TMPDIR/TODO-COMPLETED.md" ] && echo "  PASS: No completed file in dry run" && ((++PASS)) || { echo "  FAIL: Completed file should not exist"; ((++FAIL)); }

# --- Test 6: Preamble preserved ---
echo "Test 6: Preamble preserved"
rm -f "$TMPDIR/TODO.md" "$TMPDIR/TODO-COMPLETED.md"
cat > "$TMPDIR/TODO.md" << 'EOF'
# My Project

Some description here.
Multiple preamble lines.

## Completed
- [x] Old task
EOF

python "$ARCHIVE" "$TMPDIR/TODO.md"
TODO=$(cat "$TMPDIR/TODO.md")

assert_contains "Preamble title kept" "# My Project" "$TODO"
assert_contains "Preamble description kept" "Some description here." "$TODO"
assert_contains "Preamble multi-line kept" "Multiple preamble lines." "$TODO"

# --- Test 7: Append to existing TODO-COMPLETED.md ---
echo "Test 7: Append to existing archive"
rm -f "$TMPDIR/TODO.md" "$TMPDIR/TODO-COMPLETED.md"
cat > "$TMPDIR/TODO-COMPLETED.md" << 'EOF'
# TODO - Completed Tasks

## Archived 2025-01-01 00:00 UTC

- [x] Old archived task
EOF

cat > "$TMPDIR/TODO.md" << 'EOF'
# Project

## Done
- [x] New done task
EOF

python "$ARCHIVE" "$TMPDIR/TODO.md"
DONE=$(cat "$TMPDIR/TODO-COMPLETED.md")

assert_contains "Old archive preserved" "Old archived task" "$DONE"
assert_contains "New archive appended" "New done task" "$DONE"

# --- Test 8: Completed header variants ---
echo "Test 8: Header variants"
rm -f "$TMPDIR/TODO.md" "$TMPDIR/TODO-COMPLETED.md"
cat > "$TMPDIR/TODO.md" << 'EOF'
# Project

## Completed (logging)
- [x] Log task

## Done
- [x] Done task

## Previously Completed
- [x] Old task

## Active
- [ ] Active task
EOF

python "$ARCHIVE" "$TMPDIR/TODO.md"
TODO=$(cat "$TMPDIR/TODO.md")

assert_not_contains "Completed (logging) archived" "## Completed (logging)" "$TODO"
assert_not_contains "Done archived" "## Done" "$TODO"
assert_not_contains "Previously Completed archived" "## Previously Completed" "$TODO"
assert_contains "Active kept" "## Active" "$TODO"

# --- Test 9: Non-task content preserved in mixed sections ---
echo "Test 9: Non-task content preserved"
rm -f "$TMPDIR/TODO.md" "$TMPDIR/TODO-COMPLETED.md"
cat > "$TMPDIR/TODO.md" << 'EOF'
# Project

## Feature Work

WHY: Important context here.

- [x] Done feature
- [ ] Pending feature
EOF

python "$ARCHIVE" "$TMPDIR/TODO.md"
TODO=$(cat "$TMPDIR/TODO.md")

assert_contains "WHY content preserved" "WHY: Important context here." "$TODO"
assert_contains "Pending feature kept" "- [ ] Pending feature" "$TODO"
assert_not_contains "Done feature removed" "- [x] Done feature" "$TODO"

# --- Summary ---
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
