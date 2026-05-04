# todo-archiver

Reusable Python script to keep TODO.md lean by archiving completed tasks.

## Task 1: Create todo_archive.py

Standalone Python script (no deps beyond stdlib). Reusable across all projects.

### Behavior

1. Read TODO.md, parse into sections (## headers)
2. Identify completed tasks (`- [x]` lines)
3. Move completed tasks to TODO-COMPLETED.md:
   - Entire sections where header says "Completed" / "Done" / "Previously Completed"
   - Entire sections where ALL tasks are `[x]`
   - Individual `[x]` lines from mixed sections (keep header + unchecked items)
4. Add HTML comment reference in TODO.md: `<!-- See TODO-COMPLETED.md for history -->`
5. Append to TODO-COMPLETED.md with timestamp header (`## Archived YYYY-MM-DD HH:MM UTC`)
6. Never touch the first section (title/preamble before first ##)

### CLI

```
python todo_archive.py                  # uses ./TODO.md
python todo_archive.py path/to/TODO.md  # explicit path
python todo_archive.py --dry-run        # preview without writing
```

### Test

Run on hook-runner's TODO.md (30K tokens, mostly completed tasks) to verify it trims properly.
Also test on ai-skill-marketplace's TODO.md.

## Task 2: Init git repo, publish to grobomo

Standard grobomo project: `.github/publish.json`, README, MIT license.

## Origin

Created because hook-runner's TODO.md grew to 30K tokens across 50+ sessions.
Every project accumulates completed task history that bloats context windows.
