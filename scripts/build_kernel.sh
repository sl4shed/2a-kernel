#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${KERNEL_DIR}/out"
mkdir -p "${OUT}"
frags=()

if [ -n "${BASE_CONFIG:-}" ]; then
  # Start from a complete .config (e.g. the one extracted from a stock boot.img).
  base="${BASE_CONFIG}"
  [ -f "${base}" ] || base="${REPO_ROOT}/${BASE_CONFIG}"
  [ -f "${base}" ] || { echo "Base config not found: ${BASE_CONFIG}" >&2; exit 1; }
  cp "${base}" "${OUT}/.config"
else
  defconfig_targets=()
  defconfig_paths=()
  for def in ${DEFCONFIG:-}; do
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

  if [ "${#defconfig_targets[@]}" -lt 1 ]; then
    echo "No defconfig provided" >&2
    exit 1
  fi

  make -C "${KERNEL_DIR}" ${MAKE_ARGS} "${defconfig_targets[0]}"

  # Further defconfigs are merged like fragments.
  frags+=("${defconfig_paths[@]:1}")
fi

for frag in ${DEFCONFIG_FRAGS:-}; do
  if [ -f "${frag}" ]; then
    frags+=("${frag}")
  elif [ -f "${KERNEL_DIR}/arch/arm64/configs/${frag}" ]; then
    frags+=("${KERNEL_DIR}/arch/arm64/configs/${frag}")
  else
    echo "Skipping missing defconfig fragment: ${frag}"
  fi
done
if [ "${#frags[@]}" -gt 0 ]; then
  "${KERNEL_DIR}/scripts/kconfig/merge_config.sh" -m -O "${OUT}" "${OUT}/.config" "${frags[@]}"
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

for cfg in ${EXTRA_USER_CFG:-}; do
  key="${cfg%=*}"
  val="${cfg#*=}"
  case "$val" in
    n) "${KERNEL_DIR}/scripts/config" --file "${KERNEL_DIR}/out/.config" --disable "$key" ;;
    y) "${KERNEL_DIR}/scripts/config" --file "${KERNEL_DIR}/out/.config" --enable "$key" ;;
  esac
done

cat "${EXTRA_CFG}" >> "${KERNEL_DIR}/out/.config"

# GKI configs trim exports to the KMI symbol lists (CONFIG_TRIM_UNUSED_KSYMS).
# Build the whitelist the way Google's build does: every list named in
# build.config.gki.aarch64, flattened into one sorted symbol list.
if grep -q '^CONFIG_TRIM_UNUSED_KSYMS=y' "${OUT}/.config" && [ -f "${KERNEL_DIR}/build.config.gki.aarch64" ]; then
  lists=()
  while IFS= read -r l; do lists+=("${KERNEL_DIR}/${l}"); done < <(
    sed -n 's/^KMI_SYMBOL_LIST=//p' "${KERNEL_DIR}/build.config.gki.aarch64"
    sed -n '/^ADDITIONAL_KMI_SYMBOL_LISTS="/,/^"/p' "${KERNEL_DIR}/build.config.gki.aarch64" | grep '^android/')
  cat "${lists[@]}" | sed -e 's/#.*//' -e '/^\[.*\]/d' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' \
    | sort -u > "${OUT}/abi_symbollist.raw"
  "${KERNEL_DIR}/scripts/config" --file "${OUT}/.config" --set-str UNUSED_KSYMS_WHITELIST "${OUT}/abi_symbollist.raw"
  echo "KMI whitelist: $(wc -l < "${OUT}/abi_symbollist.raw") symbols from ${#lists[@]} lists"
fi

make -C "${KERNEL_DIR}" ${MAKE_ARGS} olddefconfig

# Fixed version string (setlocalversion prefers .scmversion over git), so the
# local SUSFS/KSU changes don't show up as -dirty or a different hash.
if [ -n "${SCMVERSION:-}" ]; then
  printf '%s' "${SCMVERSION}" > "${KERNEL_DIR}/.scmversion"
else
  rm -f "${KERNEL_DIR}/.scmversion"
  sed -i 's/-dirty//g' "${KERNEL_DIR}/scripts/setlocalversion"
fi

JOBS="${JOBS:-$(( $(nproc) * 2 / 3 ))}"
[ "${JOBS}" -lt 1 ] && JOBS=1
targets="Image"
grep -q '^CONFIG_MODULES=y' "${OUT}/.config" && targets="Image modules"
make -C "${KERNEL_DIR}" -j"${JOBS}" ${MAKE_ARGS} ${targets} \
  KCFLAGS="-D__ANDROID_COMMON_KERNEL__ -Wno-error"
echo "Built: $(cat "${OUT}/include/config/kernel.release")"

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
