## Features

- **[ReSukiSU](https://github.com/ReSukiSU/ReSukiSU)**: Kernel-level root (SukiSU-Ultra fork)
- **[SUSFS](https://gitlab.com/simonpunk/susfs4ksu)**: Hide root from banking apps, games, and safety checks
- **[BaseBandGuard](https://github.com/vc-teahouse/Baseband-guard)**: Prevent apps and modules from modifying critical files.
- **KPM Support**: Kernels have KPM support, this is possible thanks to [KernelPatch by SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch)

## Install

1. Download the Kernel zip variant you want from [Releases](https://github.com/MiguVT/NP2_Kernel/releases)
2. Boot into recovery (TWRP / OrangeFox)
3. Flash the zip → reboot
4. Install [ReSukiSU Manager](https://resukisu.github.io/guide/install.html#Get-manager) to manage root (Under development but recommended), you could use other KSU-based manager but no guarantee

> **Backup your stock boot image first.** Bootloader must be unlocked. Use at your own risk.

## Build it yourself

1. Fork this repo
2. Go to **Actions** → **Build 2a Kernel** → **Run workflow**
3. Download the zip from the completed run

## Credits

- [MiguVT](https://github.com/MiguVT) - NP2 Kernel
- [ReSukiSU maintainers & contributors](https://github.com/ReSukiSU/ReSukiSU) - ReSukiSU
- [simonpunk](https://gitlab.com/simonpunk/susfs4ksu) - SUSFS
- [osm0sis](https://github.com/osm0sis/AnyKernel3) - AnyKernel3
- [vc-teahouse & contributors](https://github.com/vc-teahouse/Baseband-guard) - BaseBandGuard
