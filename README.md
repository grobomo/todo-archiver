# todo-archiver

Keep `TODO.md` lean by archiving completed tasks to `TODO-COMPLETED.md`.

## Problem

Project TODO files grow unbounded as tasks complete. A 30K-token TODO.md wastes context window on every AI session start.

## Usage

```bash
python todo_archive.py                  # archive ./TODO.md
python todo_archive.py path/to/TODO.md  # explicit path
python todo_archive.py --dry-run        # preview without writing
```

## What it does

1. Parses `TODO.md` into `##` sections
2. Archives completed tasks to `TODO-COMPLETED.md` with timestamp:
   - Entire sections with "Completed" / "Done" headers
   - Sections where all tasks are `[x]`
   - Individual `[x]` lines from mixed sections (keeps header + unchecked items)
3. Adds `<!-- See TODO-COMPLETED.md for history -->` comment
4. Preserves preamble (everything before first `##`)
5. Appends to existing `TODO-COMPLETED.md` (safe to run repeatedly)

## Requirements

Python 3.8+ (stdlib only, no dependencies).

## License

MIT
