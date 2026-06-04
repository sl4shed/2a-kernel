#!/bin/bash

export KERNEL_DIR="kernel"
export ANYKERNEL_DIR="AnyKernel13"
export MAKE_ARGS="
        ARCH=arm64
        CROSS_COMPILE=aarch64-linux-gnu-
        CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
        LLVM=1 LLVM_IAS=1
        LD=ld.lld HOSTLD=ld.lld
        CC=clang CXX=clang++
        HOSTCC=clang HOSTCXX=clang++
        O=out
"

export KERNEL_TYPE="NothingOSS"
export DEFCONFIG="gki_defconfig"
export DEFCONFIG_FRAGS=""
export KERNEL_REPO="https://github.com/NothingOSS/android_kernel_5.15_nothing_mt6886"
export KERNEL_BRANCH="mt6886/Pacman/t"
export KPM_SUPPORT="true"
export SUSFS_SUPPORT="true"
export SUSFS_BRANCH="gki-android13-5.15"
export BBG_SUPPORT="true"
