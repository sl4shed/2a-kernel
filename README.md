## NP2 kernel for the Nothing Phone 2a

![image](https://socialify.git.ci/sl4shed/2a-kernel/image?custom_description=A+custom+Nothing+Phone+2a+kernel+with+ReSukiSU+%2B+SuSFS&description=1&font=Inter&forks=1&issues=1&language=1&name=1&owner=1&pattern=Circuit+Board&pulls=1&stargazers=1&theme=Auto)

This repository is a fork of the [NP2 kernel](https://github.com/MiguVT/NP2_Kernel) repository. I added a bunch of features to be able to compile the  [Nothing Phone 2a kernel](https://github.com/NothingOSS/android_kernel_5.15_nothing_mt6886) instead.

## Features

- **[ReSukiSU](https://github.com/ReSukiSU/ReSukiSU)**: Kernel-level root (SukiSU-Ultra fork)
- **[SUSFS](https://gitlab.com/simonpunk/susfs4ksu)**: Hide root from banking apps, games, and safety checks
- **[BaseBandGuard](https://github.com/vc-teahouse/Baseband-guard)**: Prevent apps and modules from modifying critical files.
- **[KernelPatch](https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch)**: Kernels have KPM support now

## Install

1. Download the Kernel zip variant you want from [Releases](https://github.com/sl4shed/2a-kernel/releases)
2. Boot into recovery (TWRP / OrangeFox)
3. Flash the zip -> reboot
4. Install [ReSukiSU Manager](https://resukisu.github.io/guide/install.html#Get-manager) to manage root

> **Backup your stock boot image first.** Bootloader must be unlocked. Use at your own risk.

## Build it yourself

### Option 1: Github Workflows
1. Fork this repo
2. Go to **Actions** -> **Build Kernel** -> **Run workflow**
3. Download the zip from the completed run

### Option 2: [act](https://github.com/nektos/act)
1. Clone this repo
2. [Install act](https://nektosact.com/installation/index.html)
3. Run `act workflow_dispatch` in the repository's root folder. (select medium image)

### Option 3: Manual build
```bash
git clone https://github.com/sl4shed/2a-kernel
cd 2a-kernel

source ./scripts/manual/setup_vars.sh # If you want to build a different kernel, you can customize this script!
./scripts/manual/setup_repos.sh

# grab a cup of coffee or tea, this is gonna take >1h
./scripts/build_kernel.sh
```

## Credits

- [MiguVT](https://github.com/MiguVT) - NP2 Kernel
- [ReSukiSU maintainers & contributors](https://github.com/ReSukiSU/ReSukiSU) - ReSukiSU
- [simonpunk](https://gitlab.com/simonpunk/susfs4ksu) - SUSFS
- [osm0sis](https://github.com/osm0sis/AnyKernel3) - AnyKernel3
- [vc-teahouse & contributors](https://github.com/vc-teahouse/Baseband-guard) - BaseBandGuard

# claude schizophrenia zone (IGNORE)

### Notes on the 2a kernel source

Nothing's `android13-5.15` tree doesn't build a GKI `Image` out of the box. The fixes live in
`patches/nothing-2a/` and are applied automatically by both the workflow and `setup_repos.sh`:

- `0001-fix-host-build-tools.patch`: lets `extract-cert` build against OpenSSL 3/4 without the ENGINE API,
  and makes `gen_kheaders.sh` use the system `cpio` instead of a bundled prebuilt.
- `0002-hardware_info-do-not-build-into-gki.patch`: Nothing's `hardware_info` driver was `default y`, so
  `gki_defconfig` built it into the kernel, where it fails to link against MediaTek vendor-module symbols
  (`get_lcm_id`, `ufs_get_hardware_info`, ...). On the phone it ships as a vendor module, so it's left out of the GKI image.

The SUSFS patch is applied through `scripts/apply_susfs.sh`, which strips two vendor `#include <trace/hooks/...>`
context lines that the 2a tree doesn't have. Builds use ThinLTO, because full LTO needs more than 16GB of RAM to link.