#!/bin/bash
# Clone the kernel and apply ReSukiSU / SUSFS / BBG.
# Run after `source ./scripts/manual/setup_vars.sh`.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

echo "Cloning kernel sources..."
git clone --depth=1 -b "$KERNEL_BRANCH" "$KERNEL_REPO" "$KERNEL_DIR"

if [ -n "${EXTRA_PATCHES_DIR:-}" ]; then
  patch_dir="$REPO_ROOT/$EXTRA_PATCHES_DIR"
  if [ ! -d "$patch_dir" ]; then
    echo "Extra patches dir not found: $patch_dir" >&2
    exit 1
  fi
  echo "Applying extra patches from $EXTRA_PATCHES_DIR..."
  cd "$KERNEL_DIR"
  while IFS= read -r -d '' p; do
    echo "Applying $p"
    patch -p1 < "$p"
  done < <(find "$patch_dir" -maxdepth 1 -type f \( -name '*.patch' -o -name '*.diff' \) -print0 | sort -z)
  cd "$REPO_ROOT"
fi

if [ "${CLONE_KERNEL_MODULES}" = "true" ]; then
  echo "Cloning kernel modules..."
  git clone --depth=1 -b "$KERNEL_MODULES_BRANCH" "$KERNEL_MODULES_REPO" "$KERNEL_MODULES_PATH"
fi

echo "Cloning AnyKernel3..."
git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git "$ANYKERNEL_DIR"
rm -rf "$ANYKERNEL_DIR/.git"

echo "Setting up ReSukiSU..."
cd "$KERNEL_DIR"
curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash
cd "$REPO_ROOT"

if [ "${SUSFS_SUPPORT}" = "true" ]; then
  echo "Cloning SUSFS..."
  git clone --depth=1 -b "$SUSFS_BRANCH" https://gitlab.com/simonpunk/susfs4ksu.git "$SUSFS_DIR"

  echo "Applying SUSFS patches..."
  force=""
  [ "${SUSFS_FORCE}" = "true" ] && force="--force"
  cd "$KERNEL_DIR"
  "$REPO_ROOT/scripts/apply_susfs.sh" "$SUSFS_DIR" "$SUSFS_BRANCH" $force
  cd "$REPO_ROOT"
fi

if [ "${BBG_SUPPORT}" = "true" ]; then
  echo "Applying BBG patches..."
  cd "$KERNEL_DIR"
  wget -O- https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh | bash
  sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/selinux/selinux,baseband_guard/ } }' security/Kconfig
  cd "$REPO_ROOT"
fi

echo "Done!"
