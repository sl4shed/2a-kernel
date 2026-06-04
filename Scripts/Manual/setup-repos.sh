#!/bin/bash

echo "Cloning kernel sources..."
git clone --depth=1 -b "$KERNEL_BRANCH" "$KERNEL_REPO" "$KERNEL_DIR" 

echo "Cloning AnyKernel3..."
git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git "$ANYKERNEL_DIR"
rm -rf "$ANYKERNEL_DIR/.git"

echo "Cloning SUSFS..."
git clone --depth=1 -b "$SUSFS_BRANCH" https://gitlab.com/simonpunk/susfs4ksu.git

echo "Setting up ReSukiSU..."
cd "$KERNEL_DIR"
curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash
cd ..

echo "Applying SUSFS patches..."
cd "$KERNEL_DIR"
cp ../susfs4ksu/kernel_patches/fs/* ./fs/
cp ../susfs4ksu/kernel_patches/include/linux/* ./include/linux/
susfs_patch="../susfs4ksu/kernel_patches/50_add_susfs_in_${SUSFS_BRANCH}.patch"
patch -p1 < "$susfs_patch"
cd ..

echo "Applying BBG patches..."
cd "$KERNEL_DIR"
wget -O- https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh | bash
sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/selinux/selinux,baseband_guard/ } }' security/Kconfig
cd ..

echo "Done!"
