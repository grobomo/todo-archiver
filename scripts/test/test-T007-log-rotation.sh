#!/usr/bin/env bash
# Test --keep-recent log rotation mode
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ARCHIVE="$PROJECT_DIR/todo_archive.py"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

PASS=0
FAIL=0

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

# --- Test 1: --keep-recent keeps last N completed sections ---
echo "Test 1: Keep last 2 completed sections"
cat > "$TMPDIR/TODO.md" << 'EOF'
# Project

## Completed (batch 1)
- [x] Old task 1
- [x] Old task 2

## Completed (batch 2)
- [x] Medium task 1

## Completed (batch 3)
- [x] Recent task 1

## Completed (batch 4)
- [x] Latest task 1

## Active
- [ ] Pending work
EOF

python "$ARCHIVE" --keep-recent 2 "$TMPDIR/TODO.md"
TODO=$(cat "$TMPDIR/TODO.md")
DONE=$(cat "$TMPDIR/TODO-COMPLETED.md")

assert_not_contains "Old batch 1 archived" "## Completed (batch 1)" "$TODO"
assert_not_contains "Old batch 2 archived" "## Completed (batch 2)" "$TODO"
assert_contains "Recent batch 3 kept" "## Completed (batch 3)" "$TODO"
assert_contains "Latest batch 4 kept" "## Completed (batch 4)" "$TODO"
assert_contains "Active kept" "## Active" "$TODO"
assert_contains "Archive has batch 1" "Old task 1" "$DONE"
assert_contains "Archive has batch 2" "Medium task 1" "$DONE"
assert_not_contains "Archive lacks batch 3" "Recent task 1" "$DONE"
assert_not_contains "Archive lacks batch 4" "Latest task 1" "$DONE"

# --- Test 2: --keep-recent with all-checked non-completed-header sections ---
echo "Test 2: All-checked sections count for keep-recent"
rm -f "$TMPDIR/TODO.md" "$TMPDIR/TODO-COMPLETED.md"
cat > "$TMPDIR/TODO.md" << 'EOF'
# Project

## Session 1
- [x] Done in session 1

## Session 2
- [x] Done in session 2

## Session 3
- [x] Done in session 3

## Active
- [ ] Still working
EOF

python "$ARCHIVE" --keep-recent 1 "$TMPDIR/TODO.md"
TODO=$(cat "$TMPDIR/TODO.md")
DONE=$(cat "$TMPDIR/TODO-COMPLETED.md")

assert_not_contains "Session 1 archived" "## Session 1" "$TODO"
assert_not_contains "Session 2 archived" "## Session 2" "$TODO"
assert_contains "Session 3 kept (most recent)" "## Session 3" "$TODO"
assert_contains "Active kept" "## Active" "$TODO"

# --- Test 3: --keep-recent 0 archives everything (same as no flag) ---
echo "Test 3: --keep-recent 0 archives all"
rm -f "$TMPDIR/TODO.md" "$TMPDIR/TODO-COMPLETED.md"
cat > "$TMPDIR/TODO.md" << 'EOF'
# Project

## Done
- [x] Task A

## Active
- [ ] Task B
EOF

python "$ARCHIVE" --keep-recent 0 "$TMPDIR/TODO.md"
TODO=$(cat "$TMPDIR/TODO.md")

assert_not_contains "Done section archived" "## Done" "$TODO"
assert_contains "Active kept" "## Active" "$TODO"

# --- Test 4: --keep-recent larger than archivable sections keeps all ---
echo "Test 4: keep-recent larger than available"
rm -f "$TMPDIR/TODO.md" "$TMPDIR/TODO-COMPLETED.md"
cat > "$TMPDIR/TODO.md" << 'EOF'
# Project

## Done
- [x] Task A

## Active
- [ ] Task B
EOF

python "$ARCHIVE" --keep-recent 10 "$TMPDIR/TODO.md"
TODO=$(cat "$TMPDIR/TODO.md")

assert_contains "Done section kept" "## Done" "$TODO"
assert_contains "Active kept" "## Active" "$TODO"
[ ! -f "$TMPDIR/TODO-COMPLETED.md" ] && echo "  PASS: No archive created" && ((++PASS)) || { echo "  FAIL: Should not archive anything"; ((++FAIL)); }

# --- Test 5: Mixed sections always split regardless of --keep-recent ---
echo "Test 5: Mixed sections always split"
rm -f "$TMPDIR/TODO.md" "$TMPDIR/TODO-COMPLETED.md"
cat > "$TMPDIR/TODO.md" << 'EOF'
# Project

## Work
- [x] Done work
- [ ] Pending work

## Completed (old)
- [x] Old task

## Completed (new)
- [x] New task
EOF

python "$ARCHIVE" --keep-recent 1 "$TMPDIR/TODO.md"
TODO=$(cat "$TMPDIR/TODO.md")

assert_contains "Work header kept" "## Work" "$TODO"
assert_contains "Pending work kept" "- [ ] Pending work" "$TODO"
assert_not_contains "Done work removed from mixed" "- [x] Done work" "$TODO"
assert_not_contains "Old completed archived" "## Completed (old)" "$TODO"
assert_contains "New completed kept (recent)" "## Completed (new)" "$TODO"

# --- Test 6: Dry run with --keep-recent ---
echo "Test 6: Dry run with --keep-recent"
rm -f "$TMPDIR/TODO.md" "$TMPDIR/TODO-COMPLETED.md"
cat > "$TMPDIR/TODO.md" << 'EOF'
# Project

## Completed (old)
- [x] Old task

## Completed (new)
- [x] New task

## Active
- [ ] Pending
EOF

BEFORE=$(cat "$TMPDIR/TODO.md")
OUTPUT=$(python "$ARCHIVE" --keep-recent 1 --dry-run "$TMPDIR/TODO.md")
AFTER=$(cat "$TMPDIR/TODO.md")

if [ "$BEFORE" = "$AFTER" ]; then
  echo "  PASS: Dry run unchanged"
  ((++PASS))
else
  echo "  FAIL: Dry run modified file"
  ((++FAIL))
fi
assert_contains "Dry run mentions keeping" "keeping 1" "$OUTPUT"

# --- Test 7: Without --keep-recent, all completed archived (backward compat) ---
echo "Test 7: No --keep-recent archives all (backward compat)"
rm -f "$TMPDIR/TODO.md" "$TMPDIR/TODO-COMPLETED.md"
cat > "$TMPDIR/TODO.md" << 'EOF'
# Project

## Session 1
- [x] Task 1

## Session 2
- [x] Task 2

## Active
- [ ] Task 3
EOF

python "$ARCHIVE" "$TMPDIR/TODO.md"
TODO=$(cat "$TMPDIR/TODO.md")

assert_not_contains "Session 1 archived" "## Session 1" "$TODO"
assert_not_contains "Session 2 archived" "## Session 2" "$TODO"
assert_contains "Active kept" "## Active" "$TODO"

# --- Summary ---
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
