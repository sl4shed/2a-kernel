#!/bin/bash
# Build settings shared by the manual build and the GitHub workflow.
# Source this file: `source ./scripts/manual/setup_vars.sh`
#
# Every value can be overridden by exporting it before sourcing (an empty
# value counts as unset), which is how the workflow passes its inputs in.
#
# Defaults build the kernel the Nothing Phone (2a) actually ships: Google's
# generic GKI kernel (ACK android13-5.15), at the exact commit, config,
# toolchain and version string of firmware Pacman B4.1-260928-1157, plus
# BakaSU (formerly ReSukiSU) and SUSFS. Nothing's own kernel tree is not what runs on the phone.

# BASH_SOURCE in bash, %x prompt expansion in zsh.
if [ -n "${BASH_SOURCE[0]:-}" ]; then _self="${BASH_SOURCE[0]}"; else _self="$(eval 'echo ${(%):-%x}')"; fi
_repo_root="$(cd "$(dirname "$_self")/../.." && pwd)"

export KERNEL_DIR="${KERNEL_DIR:-$_repo_root/kernel}"
export ANYKERNEL_DIR="${ANYKERNEL_DIR:-$_repo_root/AnyKernel3}"
export SUSFS_DIR="${SUSFS_DIR:-$_repo_root/susfs4ksu}"
export TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-$_repo_root/toolchain}"

# Overriding the kernel source or defconfig drops the stock-specific defaults
# below (pinned commit, stock config, stock version string).
_stock=true
[ -n "${KERNEL_REPO:-}${KERNEL_BRANCH:-}${DEFCONFIG:-}" ] && _stock=false

# Kernel source. KERNEL_COMMIT (optional) pins an exact commit on KERNEL_BRANCH.
export KERNEL_TYPE="${KERNEL_TYPE:-GKI}"
export KERNEL_REPO="${KERNEL_REPO:-https://android.googlesource.com/kernel/common}"
export KERNEL_BRANCH="${KERNEL_BRANCH:-android13-5.15-2026-03}"
if $_stock; then
  export KERNEL_COMMIT="${KERNEL_COMMIT-2d8ad9139b89c200eba47ce69c7f2130b60f6e6f}"
  export BASE_CONFIG="${BASE_CONFIG-configs/pacman_B4.1-260928-1157_stock.config}"
  # Stock: 5.15.197-android13-8-00005-g2d8ad9139b89-ab15063902
  # (build-user@build-host) ... #1 SMP PREEMPT Fri Mar 20 11:14:06 UTC 2026
  export SCMVERSION="${SCMVERSION--android13-8-00005-g2d8ad9139b89}"
  export BUILD_NUMBER="${BUILD_NUMBER-15063902}"
  export KBUILD_BUILD_TIMESTAMP="${KBUILD_BUILD_TIMESTAMP-Fri Mar 20 11:14:06 UTC 2026}"
else
  export KERNEL_COMMIT="${KERNEL_COMMIT:-}"
  export BASE_CONFIG="${BASE_CONFIG:-}"
  export SCMVERSION="${SCMVERSION:-}"
  export BUILD_NUMBER="${BUILD_NUMBER:-}"
  export KBUILD_BUILD_TIMESTAMP="${KBUILD_BUILD_TIMESTAMP:-}"
fi

# Config: BASE_CONFIG (a full .config, relative to the repo root) wins over
# DEFCONFIG. The stock config was extracted from the 260928 boot.img.
export DEFCONFIG="${DEFCONFIG:-gki_defconfig}"
export DEFCONFIG_FRAGS="${DEFCONFIG_FRAGS:-}"
# Stock vendor_boot carries Google-signed zram/zsmalloc modules; our kernel has
# a different signing key, so GKI module protection would refuse them.
export EXTRA_USER_CFG="${EXTRA_USER_CFG:-CONFIG_MODULE_SIG_PROTECT=n}"

# Vendor modules repo (only useful for Nothing's own tree).
export CLONE_KERNEL_MODULES="${CLONE_KERNEL_MODULES:-false}"
export KERNEL_MODULES_REPO="${KERNEL_MODULES_REPO:-https://github.com/NothingOSS/android_kernel_modules_nothing_mt6886/}"
export KERNEL_MODULES_BRANCH="${KERNEL_MODULES_BRANCH:-mt6886/Pacman/16b}"
export KERNEL_MODULES_PATH="${KERNEL_MODULES_PATH:-$KERNEL_DIR/vendor/mediatek/kernel_modules}"
# Repo-local directory of extra patches applied right after cloning the kernel.
export EXTRA_PATCHES_DIR="${EXTRA_PATCHES_DIR:-patches/ack-android13-5.15}"

# Toolchain: Google's clang (same as stock, from build.config.constants) and
# Google's kernel build tools (pahole 1.23 etc.). Empty CLANG_VERSION = host clang.
export CLANG_VERSION="${CLANG_VERSION-r450784e}"
export PREBUILTS_BRANCH="${PREBUILTS_BRANCH:-master-kernel-build-2022}"

# Version string pieces (match stock: build-user@build-host).
export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-build-user}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-build-host}"

# BakaSU and SUSFS are pinned to a tested pair (they must stay compatible with
# each other). Set either to "latest" to follow upstream, or to a commit/tag.
export KSU_REF="${KSU_REF:-57b2db6076f439cfd489f14576444e8f0f2f0a25}"
export SUSFS_REF="${SUSFS_REF:-c1d1da42b74771944207ec45aaceff9c57e84985}"

export KPM_SUPPORT="${KPM_SUPPORT:-false}"
export SUSFS_SUPPORT="${SUSFS_SUPPORT:-true}"
export SUSFS_BRANCH="${SUSFS_BRANCH:-gki-android13-5.15}" # this kernel is android13-5.15 GKI
export SUSFS_FORCE="${SUSFS_FORCE:-false}"
export BBG_SUPPORT="${BBG_SUPPORT:-false}"

if [ -n "$CLANG_VERSION" ]; then
  case ":$PATH:" in
    *":$TOOLCHAIN_DIR/clang-$CLANG_VERSION/bin:"*) ;;
    *) export PATH="$TOOLCHAIN_DIR/clang-$CLANG_VERSION/bin:$TOOLCHAIN_DIR/kernel-build-tools/bin:$PATH" ;;
  esac
fi

export MAKE_ARGS="
        ARCH=arm64
        CROSS_COMPILE=aarch64-linux-gnu-
        LLVM=1 LLVM_IAS=1
        O=$KERNEL_DIR/out
"

unset _repo_root _stock _self
