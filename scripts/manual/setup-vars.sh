#!/bin/bash

export KERNEL_DIR="$(realpath kernel)"
export ANYKERNEL_DIR="$(realpath AnyKernel13)"
export MAKE_ARGS="
        ARCH=arm64
        CROSS_COMPILE=aarch64-linux-gnu-
        CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
        LLVM=1 LLVM_IAS=1
        LD=ld.lld HOSTLD=ld.lld
        CC=clang CXX=clang++
        HOSTCC=clang HOSTCXX=clang++
        O=\"$KERNEL_DIR/out\"
		LTO_NONE=y LTO_CLANG=n
		CONFIG_LTO_CLANG=n CONFIG_LTO_CLANG_THIN=n CONFIG_LTO_NONE=y CONFIG_LTO_CLANG_FULL=n LTO_CLANG_FULL=n LTO_CLANG_THIN=n
"

export KERNEL_TYPE="NothingOSS"
export DEFCONFIG="gki_defconfig"
export DEFCONFIG_FRAGS=""
export KERNEL_REPO="https://github.com/NothingOSS/android_kernel_5.15_nothing_mt6886"
export KERNEL_BRANCH="mt6886/Pacman/t"
export KERNEL_MODULES_REPO="https://github.com/NothingOSS/android_kernel_modules_nothing_mt6886/"
export KERNEL_MODULES_BRANCH="mt6886/Pacman/t"
export KERNEL_MODULES_PATH="$KERNEL_DIR/vendor/mediatek/kernel_modules"
export KPM_SUPPORT="true"
export SUSFS_SUPPORT="true"
export SUSFS_BRANCH="gki-android13-5.15"
export BBG_SUPPORT="true"

export DEFCONFIG_FRAGS="
# LTO_CLANG=n
# LTO_CLANG_THIN=n
# LTO=n
# LTO_NONE=y

# poopoo shit
# CONFIG_ARCH_MEDIATEK=y
# CONFIG_DRM_MEDIATEK_V2=y
# CONFIG_MTK_SECURITY_SW_SUPPORT=y
# CONFIG_SCSI_UFS_MEDIATEK=y
# CONFIG_NFC_CHIP_SUPPORT=y
# CONFIG_NFC_ST21NFC=y
"

export EXTRA_USER_CFG="
CONFIG_LTO=n
CONFIG_LTO_CLANG_THIN=n
CONFIG_LTO_CLANG=n
CONFIG_LTO_CLANG_FULL=n
CONFIG_HAS_LTO_CLANG=n
"