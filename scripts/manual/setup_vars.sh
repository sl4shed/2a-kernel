#!/bin/bash
# Build settings shared by the manual build and the GitHub workflow.
# Source this file: `source ./scripts/manual/setup_vars.sh`
#
# Every value can be overridden by exporting it before sourcing (an empty
# value counts as unset), which is how the workflow passes its inputs in.

_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

export KERNEL_DIR="${KERNEL_DIR:-$_repo_root/kernel}"
export ANYKERNEL_DIR="${ANYKERNEL_DIR:-$_repo_root/AnyKernel3}"
export SUSFS_DIR="${SUSFS_DIR:-$_repo_root/susfs4ksu}"
export MAKE_ARGS="
        ARCH=arm64
        CROSS_COMPILE=aarch64-linux-gnu-
        CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
        LLVM=1 LLVM_IAS=1
        LD=ld.lld HOSTLD=ld.lld
        CC=clang CXX=clang++
        HOSTCC=clang HOSTCXX=clang++
        O=$KERNEL_DIR/out
"

export KERNEL_TYPE="${KERNEL_TYPE:-NothingOSS}"
export DEFCONFIG="${DEFCONFIG:-gki_defconfig}"
export DEFCONFIG_FRAGS="${DEFCONFIG_FRAGS:-}"
export KERNEL_REPO="${KERNEL_REPO:-https://github.com/NothingOSS/android_kernel_5.15_nothing_mt6886}"
export KERNEL_BRANCH="${KERNEL_BRANCH:-mt6886/Pacman/16b}"
# Vendor modules aren't needed for the GKI Image; set CLONE_KERNEL_MODULES=false to skip them.
export CLONE_KERNEL_MODULES="${CLONE_KERNEL_MODULES:-true}"
export KERNEL_MODULES_REPO="${KERNEL_MODULES_REPO:-https://github.com/NothingOSS/android_kernel_modules_nothing_mt6886/}"
export KERNEL_MODULES_BRANCH="${KERNEL_MODULES_BRANCH:-mt6886/Pacman/16b}"
export KERNEL_MODULES_PATH="${KERNEL_MODULES_PATH:-$KERNEL_DIR/vendor/mediatek/kernel_modules}"
# Repo-local directory of extra patches applied right after cloning the kernel.
export EXTRA_PATCHES_DIR="${EXTRA_PATCHES_DIR:-patches/nothing-2a}"
export KPM_SUPPORT="${KPM_SUPPORT:-true}"
export SUSFS_SUPPORT="${SUSFS_SUPPORT:-true}"
export SUSFS_BRANCH="${SUSFS_BRANCH:-gki-android13-5.15}" # this kernel is android13-5.15 GKI
export SUSFS_FORCE="${SUSFS_FORCE:-false}"
export BBG_SUPPORT="${BBG_SUPPORT:-true}"

# ThinLTO instead of full LTO: full LTO needs >16GB RAM to link vmlinux.
export EXTRA_USER_CFG="${EXTRA_USER_CFG:-CONFIG_LTO_CLANG_THIN=y CONFIG_LTO_CLANG_FULL=n}"

unset _repo_root
