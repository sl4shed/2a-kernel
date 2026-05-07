#!/usr/bin/env bash
set -euo pipefail

cd "${KERNEL_DIR}"
defconfig_target="${DEFCONFIG}"
defconfig_path="${DEFCONFIG}"
if [ -n "${DEFCONFIG}" ] && echo "${DEFCONFIG}" | grep -q '^/'; then
  defconfig_path="${DEFCONFIG#/}"
fi

if [ -n "${defconfig_path}" ] && echo "${defconfig_path}" | grep -q '/'; then
  if [ -f "${defconfig_path}" ]; then
    defconfig_target="$(basename "${defconfig_path}")"
    if [ "${defconfig_path}" != "arch/arm64/configs/${defconfig_target}" ]; then
      cp "${defconfig_path}" "arch/arm64/configs/${defconfig_target}"
    fi
  else
    echo "Defconfig path not found: ${defconfig_path}" >&2
    exit 1
  fi
elif [ -n "${defconfig_path}" ]; then
  if [ -f "${defconfig_path}" ] && [ ! -f "arch/arm64/configs/${defconfig_path}" ]; then
    cp "${defconfig_path}" "arch/arm64/configs/${defconfig_path}"
  fi
  if [ ! -f "arch/arm64/configs/${defconfig_path}" ]; then
    echo "Defconfig not found in arch/arm64/configs: ${defconfig_path}" >&2
    exit 1
  fi
fi

frags=()
if [ -n "${DEFCONFIG_FRAGS:-}" ]; then
  for frag in ${DEFCONFIG_FRAGS}; do
    if [ -f "${frag}" ]; then
      frags+=("${frag}")
    else
      echo "Skipping missing defconfig fragment: ${frag}"
    fi
  done
fi

make ${MAKE_ARGS} "${defconfig_target}" "${frags[@]}"

EXTRA_CFG="out/ci-extra.config"
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

cat "${EXTRA_CFG}" >> out/.config
make ${MAKE_ARGS} olddefconfig
[ -f scripts/setlocalversion ] && sed -i 's/-dirty//g' scripts/setlocalversion || true

JOBS=$(( $(nproc) / 2 ))
[ "${JOBS}" -lt 1 ] && JOBS=1
make -j"${JOBS}" ${MAKE_ARGS} Image KCFLAGS="-Wno-error"

if [ "${KPM_SUPPORT}" = "true" ]; then
  cd out/arch/arm64/boot/
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
