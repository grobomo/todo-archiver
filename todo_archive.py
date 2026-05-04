#!/usr/bin/env python3
"""Archive completed tasks from TODO.md to TODO-COMPLETED.md.

Usage:
    python todo_archive.py                       # archive all completed tasks
    python todo_archive.py path/to/TODO.md       # explicit path
    python todo_archive.py --keep-recent 5       # keep last 5 completed sections visible
    python todo_archive.py --dry-run             # preview without writing
    python todo_archive.py --keep-recent 5 --dry-run path/to/TODO.md

Log rotation mode (--keep-recent N):
    Keeps the N most recent fully-completed sections in TODO.md so Claude
    can see where it left off. Only archives older completed sections.
    Without this flag, all completed tasks are archived.
"""

import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ARCHIVE_COMMENT = '<!-- See TODO-COMPLETED.md for history -->'
COMPLETED_RE = re.compile(r'(previously\s+)?(completed|done)\b', re.IGNORECASE)
TASK_RE = re.compile(r'^(\s*)- \[([ xX])\] ')
CHECKED_RE = re.compile(r'^\s*- \[[xX]\] ')


def parse_sections(text):
    """Split into preamble lines + list of (header, body_lines) sections."""
    lines = text.split('\n')
    preamble = []
    sections = []
    header = None
    body = []

    for line in lines:
        if line.startswith('## '):
            if header is not None:
                sections.append((header, body))
            header = line
            body = []
        elif header is None:
            preamble.append(line)
        else:
            body.append(line)

    if header is not None:
        sections.append((header, body))

    return preamble, sections


def is_completed_header(header):
    """Check if header indicates completed/done tasks."""
    title = re.sub(r'^#+\s*', '', header).strip()
    return bool(COMPLETED_RE.match(title))


def classify_items(body):
    """Parse body lines into items: ('task', checked, lines) or ('content', None, lines)."""
    items = []
    i = 0
    while i < len(body):
        m = TASK_RE.match(body[i])
        if m:
            indent = len(m.group(1))
            checked = m.group(2).lower() == 'x'
            task_lines = [body[i]]
            i += 1
            while i < len(body):
                nxt = body[i]
                nm = TASK_RE.match(nxt)
                if nm and len(nm.group(1)) <= indent:
                    break
                if nxt.strip() and not nm:
                    nxt_indent = len(nxt) - len(nxt.lstrip())
                    if nxt_indent <= indent:
                        break
                task_lines.append(nxt)
                i += 1
            items.append(('task', checked, task_lines))
        else:
            content = [body[i]]
            i += 1
            while i < len(body) and not TASK_RE.match(body[i]):
                content.append(body[i])
                i += 1
            items.append(('content', None, content))

    return items


def process_section(header, body):
    """Return (keep_lines, archive_lines, is_fully_archivable) for one section."""
    if is_completed_header(header):
        return [], [header] + body, True

    items = classify_items(body)
    tasks = [it for it in items if it[0] == 'task']

    if not tasks:
        return [header] + body, [], False

    checked = [t for t in tasks if t[1]]
    unchecked = [t for t in tasks if not t[1]]

    if not checked:
        return [header] + body, [], False

    if not unchecked:
        return [], [header] + body, True

    # Mixed: keep header + content + unchecked; archive header + checked
    keep = [header]
    archive = [header]
    for kind, is_checked, lines in items:
        if kind == 'content':
            keep.extend(lines)
        elif is_checked:
            archive.extend(lines)
        else:
            keep.extend(lines)

    return keep, archive, False


def clean_blanks(text):
    """Collapse 3+ consecutive newlines to 2."""
    return re.sub(r'\n{3,}', '\n\n', text)


def archive_todos(todo_path, dry_run=False, keep_recent=None):
    todo_path = Path(todo_path)
    if not todo_path.exists():
        print(f"Error: {todo_path} not found")
        return 1

    text = todo_path.read_text(encoding='utf-8')
    preamble, sections = parse_sections(text)

    # Classify each section, tracking position for keep-recent
    results = []  # [(keep_lines, archive_lines, is_fully_archivable)]
    for header, body in sections:
        results.append(process_section(header, body))

    # Apply --keep-recent: retain the last N fully-archivable sections
    if keep_recent is not None and keep_recent > 0:
        full_archive_indices = [i for i, (k, a, full) in enumerate(results) if full]
        if len(full_archive_indices) <= keep_recent:
            retain = set(full_archive_indices)
        else:
            retain = set(full_archive_indices[-keep_recent:])
        for i in retain:
            k, a, full = results[i]
            results[i] = (a, [], False)

    keep_all = [k for k, a, f in results if k]
    archive_all = [a for k, a, f in results if a]

    if not archive_all:
        print("Nothing to archive.")
        return 0

    # Build new TODO.md
    new_lines = list(preamble)
    if ARCHIVE_COMMENT not in '\n'.join(preamble):
        idx = next((i + 1 for i, l in enumerate(new_lines) if l.startswith('# ')), len(new_lines))
        new_lines.insert(idx, '')
        new_lines.insert(idx + 1, ARCHIVE_COMMENT)

    for section in keep_all:
        new_lines.append('')
        new_lines.extend(section)

    new_todo = clean_blanks('\n'.join(new_lines)).rstrip('\n') + '\n'

    # Build archive block
    ts = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')
    archive_lines = [f'## Archived {ts}', '']
    for section in archive_all:
        archive_lines.extend(section)
        archive_lines.append('')
    archive_block = clean_blanks('\n'.join(archive_lines)).rstrip('\n') + '\n'

    # Stats
    task_count = sum(1 for s in archive_all for l in s if CHECKED_RE.match(l))
    section_count = len(archive_all)
    orig_lines = len(text.splitlines())
    new_line_count = len(new_todo.splitlines())
    kept_count = keep_recent if keep_recent and keep_recent > 0 else 0

    if dry_run:
        print(f"DRY RUN - would archive {task_count} tasks from {section_count} sections")
        if kept_count:
            print(f"  (keeping {kept_count} most recent completed sections)")
        print(f"  TODO.md: {orig_lines} -> {new_line_count} lines")
        print()
        print("--- Archive block preview ---")
        print(archive_block)
        return 0

    # Write TODO.md
    todo_path.write_text(new_todo, encoding='utf-8')

    # Append to TODO-COMPLETED.md
    completed_path = todo_path.parent / 'TODO-COMPLETED.md'
    if completed_path.exists():
        existing = completed_path.read_text(encoding='utf-8')
        if not existing.endswith('\n'):
            existing += '\n'
        completed_path.write_text(existing + '\n' + archive_block, encoding='utf-8')
    else:
        stem = todo_path.stem
        completed_path.write_text(f'# {stem} - Completed Tasks\n\n{archive_block}', encoding='utf-8')

    msg = f"Archived {task_count} tasks from {section_count} sections"
    if kept_count:
        msg += f" (keeping {kept_count} recent)"
    print(msg)
    print(f"  TODO.md: {orig_lines} -> {new_line_count} lines")
    print(f"  -> {completed_path.name}")
    return 0


def main():
    args = sys.argv[1:]
    dry_run = '--dry-run' in args
    if dry_run:
        args.remove('--dry-run')

    if '--help' in args or '-h' in args:
        print(__doc__.strip())
        return 0

    keep_recent = None
    if '--keep-recent' in args:
        idx = args.index('--keep-recent')
        keep_recent = int(args[idx + 1])
        del args[idx:idx + 2]

    todo_path = args[0] if args else 'TODO.md'
    return archive_todos(todo_path, dry_run=dry_run, keep_recent=keep_recent)


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    sys.exit(main())
