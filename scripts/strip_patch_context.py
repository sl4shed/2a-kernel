#!/usr/bin/env python3
"""Drop specific *context* lines from a unified diff and fix the hunk headers.

Some kernels (e.g. the Nothing Phone 2a mt6886 tree) are missing vendor
`#include <trace/hooks/...>` lines that upstream patches like SUSFS use as
context, which makes otherwise-correct hunks fail to apply. This removes those
lines from the hunks' context only (never from added/removed lines) and
decrements the hunk line counts to match.

Usage: strip_patch_context.py <in.patch> <out.patch> '<file>:<exact line>' [...]
  e.g. 'fs/namespace.c:#include <trace/hooks/blk.h>'
"""
import re
import sys

HUNK_RE = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)$")


def main() -> int:
    if len(sys.argv) < 4:
        print(__doc__, file=sys.stderr)
        return 2
    src, dst, *drop = sys.argv[1:]
    drop = {(spec.split(":", 1)[0], " " + spec.split(":", 1)[1]) for spec in drop}

    with open(src, encoding="utf-8", errors="surrogateescape") as f:
        lines = f.read().split("\n")

    out = []
    hunk_idx = None
    removed = 0
    stripped = 0
    cur_file = None

    def flush_header():
        nonlocal hunk_idx, removed
        if hunk_idx is None or removed == 0:
            hunk_idx, removed = None, 0
            return
        m = HUNK_RE.match(out[hunk_idx])
        o_start, o_len, n_start, n_len, tail = m.groups()
        o_len = int(o_len if o_len is not None else 1) - removed
        n_len = int(n_len if n_len is not None else 1) - removed
        out[hunk_idx] = f"@@ -{o_start},{o_len} +{n_start},{n_len} @@{tail}"
        hunk_idx, removed = None, 0

    for line in lines:
        if line.startswith("@@ "):
            flush_header()
            hunk_idx = len(out)
            out.append(line)
            continue
        if line.startswith("diff "):
            flush_header()
        elif hunk_idx is None and line.startswith(("--- ", "+++ ")):
            if line.startswith("+++ "):
                cur_file = line[4:].split("\t")[0]
                cur_file = cur_file[2:] if cur_file.startswith("b/") else cur_file
        if hunk_idx is not None and (cur_file, line) in drop:
            removed += 1
            stripped += 1
            continue
        out.append(line)
    flush_header()

    with open(dst, "w", encoding="utf-8", errors="surrogateescape") as f:
        f.write("\n".join(out))
    print(f"strip_patch_context: removed {stripped} context line(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
