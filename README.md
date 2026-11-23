## NP2 kernel for the Nothing Phone 2a

![image](https://socialify.git.ci/sl4shed/2a-kernel/image?custom_description=A+custom+Nothing+Phone+2a+kernel+with+BakaSU+%2B+SuSFS&description=1&font=Inter&forks=1&issues=1&language=1&name=1&owner=1&pattern=Circuit+Board&pulls=1&stargazers=1&theme=Auto)

This repository is a fork of the [NP2 kernel](https://github.com/MiguVT/NP2_Kernel) repository. I added a bunch of features to be able to compile the  [Nothing Phone 2a kernel](https://github.com/NothingOSS/android_kernel_5.15_nothing_mt6886) instead.

## Features

- **[BakaSU](https://github.com/Baka-SU/BakaSU)** (formerly ReSukiSU): Kernel-level root (SukiSU-Ultra fork)
- **[SUSFS](https://gitlab.com/simonpunk/susfs4ksu)**: Hide root from banking apps, games, and safety checks
- **[BaseBandGuard](https://github.com/vc-teahouse/Baseband-guard)**: Prevent apps and modules from modifying critical files.
- **[KernelPatch](https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch)**: Kernels have KPM support now

## Install

1. Download the Kernel zip variant you want from [Releases](https://github.com/sl4shed/2a-kernel/releases)
2. Boot into recovery (TWRP / OrangeFox)
3. Flash the zip -> reboot
4. Install [BakaSU Manager](https://bakasu.org/guide/install.html#Get-manager) to manage root

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
- [BakaSU maintainers & contributors](https://github.com/Baka-SU/BakaSU) - BakaSU (formerly ReSukiSU)
- [simonpunk](https://gitlab.com/simonpunk/susfs4ksu) - SUSFS
- [osm0sis](https://github.com/osm0sis/AnyKernel3) - AnyKernel3
- [vc-teahouse & contributors](https://github.com/vc-teahouse/Baseband-guard) - BaseBandGuard

# claude schizophrenia zone (IGNORE)

### Making a fastboot-flashable boot.img

If you'd rather `fastboot boot`/`fastboot flash` than flash the AnyKernel3 zip from recovery, swap the built kernel into the stock
`boot.img` for **your exact firmware build** (from the [Nothing Archive](https://github.com/spike0en/nothing_archive) `-image-boot.7z`):

```bash
./scripts/make_boot_img.sh stock_boot.img kernel/out/arch/arm64/boot/Image boot_custom.img
```

It keeps the stock header and AVB footer props (OS version, security patch), so only the kernel changes.

### What gets built

The phone doesn't run a kernel built from Nothing's tree: the `boot` partition holds **Google's generic GKI kernel**
(ACK `android13-5.15`), and all MediaTek/Nothing drivers are vendor modules in `vendor_boot`/`vendor_dlkm`.
So by default the scripts rebuild exactly what stock firmware **B4.1-260928-1157** ships, plus BakaSU and SUSFS:

- Source: `kernel/common` at `2d8ad9139b89` (branch `android13-5.15-2026-03`), the commit in the stock version string.
- Config: `configs/pacman_B4.1-260928-1157_stock.config`, extracted from the stock `boot.img` (full LTO, CFI, SCS,
  KMI symbol trimming). `build_kernel.sh` regenerates the KMI whitelist from `android/abi_gki_aarch64*` like Google's build.
- Toolchain: Google's clang `r450784e` (14.0.7) and kernel build tools (pahole 1.23), downloaded to `toolchain/`.
- Version string identical to stock: `5.15.197-android13-8-00005-g2d8ad9139b89-ab15063902 (build-user@build-host)`.
- `CONFIG_MODULE_SIG_PROTECT` is off: `vendor_boot` contains Google-signed `zram.ko`/`zsmalloc.ko`, and our kernel's
  signing key differs, so GKI module protection would block them.
- `patches/ack-android13-5.15/` lets `extract-cert`/`sign-file` build against OpenSSL without the ENGINE API.
- KPM and BaseBandGuard are off by default (`KPM_SUPPORT`/`BBG_SUPPORT` in `setup_vars.sh`).

`scripts/check_module_abi.py <kernel/out/Module.symvers> <dir of stock .ko files>` checks that stock vendor modules
(e.g. from an unpacked `vendor_boot` ramdisk) would load: every symbol CRC they were built against must match.

The full LTO link needs a lot of RAM (16GB + swap is fine) and the build takes ~30 min on 8 jobs.
