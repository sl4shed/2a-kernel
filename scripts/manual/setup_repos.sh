#!/bin/bash
# Fetch the toolchain, clone the kernel and apply BakaSU / SUSFS / BBG.
# Run after `source ./scripts/manual/setup_vars.sh`.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

if [ -n "${CLANG_VERSION:-}" ] && [ ! -x "$TOOLCHAIN_DIR/clang-$CLANG_VERSION/bin/clang" ]; then
  echo "Downloading Google clang-$CLANG_VERSION..."
  mkdir -p "$TOOLCHAIN_DIR/clang-$CLANG_VERSION"
  curl -fsSL "https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/$PREBUILTS_BRANCH/clang-$CLANG_VERSION.tar.gz" \
    | tar -xz -C "$TOOLCHAIN_DIR/clang-$CLANG_VERSION"
fi
if [ -n "${CLANG_VERSION:-}" ] && [ ! -x "$TOOLCHAIN_DIR/kernel-build-tools/bin/pahole" ]; then
  echo "Downloading Google kernel build tools..."
  mkdir -p "$TOOLCHAIN_DIR/kernel-build-tools"
  curl -fsSL "https://android.googlesource.com/kernel/prebuilts/build-tools/+archive/refs/heads/$PREBUILTS_BRANCH/linux-x86.tar.gz" \
    | tar -xz -C "$TOOLCHAIN_DIR/kernel-build-tools"
fi

echo "Cloning kernel sources..."
if [ -n "${KERNEL_COMMIT:-}" ]; then
  git init -q "$KERNEL_DIR"
  git -C "$KERNEL_DIR" fetch --depth=1 "$KERNEL_REPO" "$KERNEL_COMMIT"
  git -C "$KERNEL_DIR" checkout -q -b "$KERNEL_BRANCH" FETCH_HEAD
else
  git clone --depth=1 -b "$KERNEL_BRANCH" "$KERNEL_REPO" "$KERNEL_DIR"
fi

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

echo "Setting up BakaSU (formerly ReSukiSU)..."
cd "$KERNEL_DIR"
if [ "${KSU_REF:-latest}" = "latest" ]; then
  curl -LSs "https://raw.githubusercontent.com/Baka-SU/BakaSU/main/kernel/setup.sh" | bash
else
  curl -LSs "https://raw.githubusercontent.com/Baka-SU/BakaSU/$KSU_REF/kernel/setup.sh" | bash -s "$KSU_REF"
fi
echo "BakaSU at $(git -C KernelSU rev-parse HEAD)"
cd "$REPO_ROOT"

if [ "${SUSFS_SUPPORT}" = "true" ]; then
  echo "Cloning SUSFS..."
  if [ "${SUSFS_REF:-latest}" = "latest" ]; then
    git clone --depth=1 -b "$SUSFS_BRANCH" https://gitlab.com/simonpunk/susfs4ksu.git "$SUSFS_DIR"
  else
    git clone --filter=blob:none --no-checkout -b "$SUSFS_BRANCH" https://gitlab.com/simonpunk/susfs4ksu.git "$SUSFS_DIR"
    git -C "$SUSFS_DIR" checkout -q "$SUSFS_REF"
  fi
  echo "SUSFS at $(git -C "$SUSFS_DIR" rev-parse HEAD)"

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
