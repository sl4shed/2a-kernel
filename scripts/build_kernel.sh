#!/usr/bin/env bash
set -euo pipefail

defconfig_targets=()
defconfig_paths=()
if [ -n "${DEFCONFIG:-}" ]; then
  for def in ${DEFCONFIG}; do
    if echo "${def}" | grep -q '^/'; then
      def_path="${def#/}"
    else
      def_path="${KERNEL_DIR}/arch/arm64/configs/${def}"
    fi

    if [ ! -f "${def_path}" ]; then
      echo "Defconfig path not found: ${def_path}" >&2
      exit 1
    fi

    def_target="$(basename "${def_path}")"
    if [ "${def_path}" != "${KERNEL_DIR}/arch/arm64/configs/${def_target}" ]; then
      cp "${def_path}" "${KERNEL_DIR}/arch/arm64/configs/${def_target}"
    fi

    defconfig_targets+=("${def_target}")
    defconfig_paths+=("${KERNEL_DIR}/arch/arm64/configs/${def_target}")
  done
fi

if [ "${#defconfig_targets[@]}" -lt 1 ]; then
  echo "No defconfig provided" >&2
  exit 1
fi

frags=()
if [ -n "${DEFCONFIG_FRAGS:-}" ]; then
  for frag in ${DEFCONFIG_FRAGS}; do
    if [ -f "${frag}" ]; then
      frags+=("${frag}")
    elif [ -f "${KERNEL_DIR}/arch/arm64/configs/${frag}" ]; then
      frags+=("${KERNEL_DIR}/arch/arm64/configs/${frag}")
    else
      echo "Skipping missing defconfig fragment: ${frag}"
    fi
  done
fi

make -C "${KERNEL_DIR}" ${MAKE_ARGS} "${defconfig_targets[0]}"

merge_frags=()
if [ "${#defconfig_paths[@]}" -gt 1 ]; then
  merge_frags+=("${defconfig_paths[@]:1}")
fi
if [ "${#frags[@]}" -gt 0 ]; then
  merge_frags+=("${frags[@]}")
fi

if [ "${#merge_frags[@]}" -gt 0 ]; then
  if [ -x "${KERNEL_DIR}/scripts/kconfig/merge_config.sh" ]; then
    ${KERNEL_DIR}/scripts/kconfig/merge_config.sh -m -O "${KERNEL_DIR}/out" "${KERNEL_DIR}/out/.config" "${merge_frags[@]}"
  else
    echo "merge_config.sh not found; cannot apply defconfig fragments" >&2
    exit 1
  fi
fi

EXTRA_CFG="${KERNEL_DIR}/out/ci-extra.config"
: > "${EXTRA_CFG}"
echo "CONFIG_KSU=y" >> "${EXTRA_CFG}"

if [ "${SUSFS_SUPPORT}" = "true" ]; then
  echo "CONFIG_KSU_SUSFS=y" >> "${EXTRA_CFG}"
fi

if [ "${KPM_SUPPORT}" = "true" ]; then
  echo "CONFIG_KPM=y" >> "${EXTRA_CFG}"
  echo "CONFIG_KALLSYMS=y" >> "${EXTRA_CFG}"
  echo "CONFIG_KALLSYMS_ALL=y" >> "${EXTRA_CFG}"
  echo "CONFIG_KPROBES=y" >> "${EXTRA_CFG}"
fi

if [ "${BBG_SUPPORT}" = "true" ]; then
  echo "CONFIG_BBG=y" >> "${EXTRA_CFG}"
fi

for cfg in ${EXTRA_USER_CFG}; do
  key="${cfg%=*}"
  val="${cfg#*=}"
  case "$val" in
    n) "${KERNEL_DIR}/scripts/config" --file "${KERNEL_DIR}/out/.config" --disable "$key" ;;
    y) "${KERNEL_DIR}/scripts/config" --file "${KERNEL_DIR}/out/.config" --enable "$key" ;;
  esac
done

cat "${EXTRA_CFG}" >> "${KERNEL_DIR}/out/.config"

make -C "${KERNEL_DIR}" ${MAKE_ARGS} olddefconfig
[ -f "${KERNEL_DIR}/scripts/setlocalversion" ] && sed -i 's/-dirty//g' "${KERNEL_DIR}/scripts/setlocalversion" || true

JOBS=$(( $(nproc) / 2 ))
[ "${JOBS}" -lt 1 ] && JOBS=1
export srctree="$KERNEL_DIR"
make -C "${KERNEL_DIR}" -j"${JOBS}" ${MAKE_ARGS} srctree="${KERNEL_DIR}" Image KCFLAGS="-Wno-error"

if [ "${KPM_SUPPORT}" = "true" ]; then
  cd "${KERNEL_DIR}/out/arch/arm64/boot/"
  python3 - <<'PY'
import json
import sys
import urllib.request

url = "https://api.github.com/repos/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/latest"
with urllib.request.urlopen(url) as resp:
  data = json.load(resp)

assets = data.get("assets", [])
match = next((a["browser_download_url"] for a in assets if "patch_linux" in a.get("name", "")), None)
if not match:
  print("ERROR: patch_linux asset not found", file=sys.stderr)
  sys.exit(1)

urllib.request.urlretrieve(match, "patch_linux")
PY
  chmod +x ./patch_linux
  ./patch_linux
  rm -f ./Image
  mv ./oImage ./Image
fi
