#!/usr/bin/env bash
# Build a flashable boot.img by swapping our kernel into a stock GKI boot.img.
#
# Usage: make_boot_img.sh <stock boot.img> <kernel Image> <output boot.img>
#
# Keeps the stock header layout (v4, no ramdisk, same cmdline), compresses the
# kernel with lz4 legacy like the stock image, and re-adds an AVB hash footer
# carrying the stock props (os_version, fingerprint, security_patch) so the
# bootloader/KeyMint still see the same boot patch level. The footer is signed
# with a throwaway key: an unlocked bootloader doesn't verify it, but keeps the
# same structure as the stock image.
#
# Needs: unpack_bootimg, mkbootimg, avbtool, lz4, openssl.
set -euo pipefail

if [ "$#" -ne 3 ]; then
  sed -n '2,4p' "$0" >&2
  exit 2
fi

stock="$(realpath "$1")"
kernel="$(realpath "$2")"
out="$(realpath -m "$3")"

for tool in unpack_bootimg mkbootimg avbtool lz4 openssl; do
  command -v "$tool" >/dev/null || { echo "missing tool: $tool" >&2; exit 1; }
done

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

unpack_bootimg --boot_img "$stock" --out "$work/stock" >/dev/null
header_version="$(unpack_bootimg --boot_img "$stock" --out "$work/stock" | awk -F': ' '/^boot image header version/ {print $2}')"
cmdline="$(unpack_bootimg --boot_img "$stock" --out "$work/stock" | awk -F': ' '/^command line args/ {print $2}')"
if [ -s "$work/stock/ramdisk" ]; then
  echo "stock boot.img has a ramdisk; this script only handles GKI images without one" >&2
  exit 1
fi

# Match the stock kernel compression.
if lz4 -t "$work/stock/kernel" >/dev/null 2>&1; then
  lz4 -l -12 --favor-decSpeed -q -f "$kernel" "$work/kernel"
else
  cp "$kernel" "$work/kernel"
fi

mkbootimg --header_version "$header_version" --kernel "$work/kernel" \
  --ramdisk "$work/stock/ramdisk" --cmdline "$cmdline" -o "$work/boot.img"

# Re-create the AVB footer with the stock props.
partition_size="$(stat -c %s "$stock")"
avb_info="$(avbtool info_image --image "$stock")"
partition_name="$(awk -F': *' '/Partition Name:/ {print $2; exit}' <<<"$avb_info")"
prop_args=()
while IFS= read -r line; do
  key="${line%% -> *}"
  val="${line#* -> }"
  val="${val#\'}"
  val="${val%\'}"
  prop_args+=(--prop "${key}:${val}")
done < <(sed -n "s/^ *Prop: //p" <<<"$avb_info")

openssl genrsa -out "$work/key.pem" 2048 2>/dev/null
avbtool add_hash_footer --image "$work/boot.img" \
  --partition_size "$partition_size" --partition_name "$partition_name" \
  --algorithm SHA256_RSA2048 --key "$work/key.pem" "${prop_args[@]}"

mv "$work/boot.img" "$out"
echo "Wrote $out"
