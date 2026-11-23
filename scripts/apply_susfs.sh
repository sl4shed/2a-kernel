#!/usr/bin/env bash
# Apply the SUSFS kernel patch to the kernel tree in the current directory.
#
# Usage: apply_susfs.sh <susfs4ksu dir> <susfs branch> [--force]
#
# If the upstream patch doesn't apply cleanly, retry with a copy that drops
# vendor `#include <trace/hooks/...>` context lines some trees (e.g. the
# Nothing Phone 2a mt6886 kernel) don't have.
set -euo pipefail

susfs_dir="$(realpath "$1")"
susfs_branch="$2"
force="${3:-}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cp "$susfs_dir"/kernel_patches/fs/* ./fs/
cp "$susfs_dir"/kernel_patches/include/linux/* ./include/linux/

patch_file="$susfs_dir/kernel_patches/50_add_susfs_in_${susfs_branch}.patch"

if ! patch -p1 --dry-run -s < "$patch_file" >/dev/null 2>&1; then
  echo "SUSFS patch does not apply cleanly; retrying without vendor trace hook context"
  stripped="$(mktemp)"
  trap 'rm -f "$stripped"' EXIT
  python3 "$script_dir/strip_patch_context.py" "$patch_file" "$stripped" \
    'fs/namespace.c:#include <trace/hooks/blk.h>' \
    'fs/proc/task_mmu.c:#include <trace/hooks/mm.h>'
  patch_file="$stripped"
fi

if [ "$force" = "--force" ]; then
  patch -p1 --forward < "$patch_file" || echo "Continuing despite SUSFS patch failure"
else
  patch -p1 --forward < "$patch_file"
fi
