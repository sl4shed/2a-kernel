# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
properties() { '
kernel.string=Nothing Phone (2a) Kernel - BakaSU
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=Pacman
device.name2=pacman
supported.versions=13-16
supported.patchlevels=
'; }

# Shell variables
block=boot;
is_slot_device=1;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

## AnyKernel methods
. tools/ak3-core.sh;

## AnyKernel boot install
split_boot;
flash_boot;
## end boot install