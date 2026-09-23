#!/usr/bin/env bash
# audit_kernel_patches.sh — PATCH PROVENANCE GATE (AGENTS.md §14, ADR-014)
# Verifica el patch set REALMENTE aplicado a un kernel build dir del proyecto,
# para CUALQUIER versión (4.4.186: 41 vendor + 4 own; 5.12.4: 20 vendor + 4 own):
# parches HiChip en orden + rsync de SOURCE/linux-drivers + yaffs2 (solo 4.4)
# + 4 patches PROPIOS (repo patches/buildroot/linux/ -> SDK 900X-*.patch):
#   9001 auddec.h ABI pad 24B (ADR-012)   9002 vidmp.h ABI pad 20B (ADR-012)
#   9003 amprpc debug logging             9004 avp-proxy snd-xfer debug budget
# La versión del kernel se deriva del output-dir (.config BR2_LINUX_KERNEL_VERSION).
# Read-only sobre el output y el SDK; idempotente; emite PATCH PROVENANCE: PASS/FAIL.
# Uso: ./scripts/audit_kernel_patches.sh [kernel-build-dir] [output-dir]
#   kernel-build-dir default: ~/work/r36sx-hclinux/build/r36sx-v26/build/linux-4.4.186
#   output-dir default:        ~/work/r36sx-hclinux/build/r36sx-v26
set -uo pipefail

KB="${1:-$HOME/work/r36sx-hclinux/build/r36sx-v26/build/linux-4.4.186}"
O="${2:-$HOME/work/r36sx-hclinux/build/r36sx-v26}"
SDK="$HOME/work/r36sx-hclinux/sdk/hclinux-2024.02.y.2/hclinux"
PROJ="$HOME/projects/r36sx-hclinux"
OWN="$PROJ/patches/buildroot/linux"
KEXT=/mnt/d/GitHub/KERNEL
FAIL=0
bad() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
ok()  { echo "  [PASS] $1"; }

# versión del kernel desde el output dir (fallback 4.4.186)
KVER=$(sed -n 's/^BR2_LINUX_KERNEL_VERSION="\([^"]*\)"/\1/p' "$O/.config" 2>/dev/null)
KVER="${KVER:-4.4.186}"
case "$KVER" in
  4.4.186) NVEND=41 ;;
  5.12.4) NVEND=21 ;;
  *) NVEND=0 ;;
esac
P4="$SDK/patches/linux-$KVER"
NAFTER=$((NVEND+4))

echo "=== PATCH PROVENANCE AUDIT — $KB (kernel $KVER) ==="

# 1. precondiciones
[ -d "$KB" ] || { echo "  [FAIL] no existe $KB"; echo "PATCH PROVENANCE: FAIL"; exit 1; }
[ -f "$KB/.stamp_patched" ] && ok ".stamp_patched presente" || bad "sin .stamp_patched"
[ -f "$O/.config" ] || { echo "  [FAIL] no existe $O/.config"; echo "PATCH PROVENANCE: FAIL"; exit 1; }

# 2. BR2_GLOBAL_PATCH_DIR = SDK/patches (single dir — el buildroot del SDK no soporta colon)
grep -q '^BR2_GLOBAL_PATCH_DIR="\$(BR2_EXTERNAL_HCLINUX_PATH)/patches"$' "$O/.config" \
  && ok "BR2_GLOBAL_PATCH_DIR = SDK/patches" || bad "BR2_GLOBAL_PATCH_DIR no apunta al SDK"

# 3. hunks distintivos en el árbol (presence != applied; aquí: árbol resultante)
echo "-- hunks/símbolos en árbol --"
if grep -q "platforms += hc16xx" "$KB/arch/mips/Kbuild.platforms" 2>/dev/null; then
  ok "0001: platforms += hc16xx (formato 4.4)"
elif grep -qE 'platform-\$\(CONFIG_HICHIP_HC16XX\)[[:space:]]*\+= hc16xx' "$KB/arch/mips/Kbuild.platforms" 2>/dev/null; then
  ok "0001: platform-\$(CONFIG_HICHIP_HC16XX) += hc16xx/ (formato 5.12)"
else
  bad "0001 no aplicado (Kbuild.platforms sin wiring hc16xx)"
fi
grep -q "config HICHIP_HC16XX" "$KB/arch/mips/Kconfig" 2>/dev/null && ok "0001: config HICHIP_HC16XX" || bad "0001 no aplicado (Kconfig)"
grep -qE "obj-.*hcdrivers" "$KB/drivers/Makefile" 2>/dev/null && ok "0007: obj hcdrivers en Makefile" || bad "0007 no aplicado"
[ -d "$KB/drivers/hcdrivers" ] && ok "BSP drivers/hcdrivers/ inyectado ($(ls "$KB/drivers/hcdrivers" | wc -l) componentes)" || bad "drivers/hcdrivers ausente"
[ -d "$KB/arch/mips/hc16xx" ] && ok "arch/mips/hc16xx/ inyectado ($(ls "$KB/arch/mips/hc16xx" | wc -l) archivos)" || bad "arch/mips/hc16xx ausente"
if [ "$KVER" = "4.4.186" ]; then
  [ -d "$KB/fs/yaffs2" ] && ok "yaffs2 integrado en fs/" || bad "yaffs2 ausente"
  grep -q "yaffs" "$KB/fs/Kconfig" 2>/dev/null && ok "fs/Kconfig referencia yaffs2" || bad "fs/Kconfig sin yaffs"
else
  [ -d "$KB/fs/yaffs2" ] && ok "yaffs2 integrado (INERTE en $KVER: CONFIG_YAFFS off en base config — hook del SDK lo exige)" || bad "yaffs2 ausente en $KVER (hook PRE_PATCH fallará: 'cd patches/linux/yaffs2: No such file')"
fi

# 4. patches PROPIOS en el árbol (estado resultante — vale para aplicación
#    manual histórica 8e y para la integrada buildroot 9-1)
echo "-- patches propios (ADR-012 + debug) en árbol --"
grep -q "_pad_abi_2025\[24\]" "$KB/include/uapi/hcuapi/auddec.h" 2>/dev/null \
  && ok "own-9001: auddec.h ABI pad 24B (ADR-012)" || bad "own-9001 auddec.h sin pad"
grep -q "_pad_abi_2025\[20\]" "$KB/include/uapi/hcuapi/vidmp.h" 2>/dev/null \
  && ok "own-9002: vidmp.h ABI pad 20B (ADR-012)" || bad "own-9002 vidmp.h sin pad"
[ "$(grep -c 'amprpc_dbg' "$KB/drivers/hcdrivers/amprpc/amprpc.c" 2>/dev/null)" -gt 0 ] \
  && ok "own-9003: amprpc debug logging" || bad "own-9003 amprpc sin debug"
[ "$(grep -c 'SND_XFER_DBG_MAX' "$KB/drivers/hcdrivers/avp-proxy/avp-proxy.c" 2>/dev/null)" -gt 0 ] \
  && ok "own-9004: avp-proxy snd-xfer budget" || bad "own-9004 avp-proxy sin budget"
# 9-4 versionado (solo 5.12.4): port timer API hc_gpio_key (9101)
if [ "$KVER" = "5.12.4" ]; then
  if grep -q 'timer_setup(&bdata->release_timer' "$KB/drivers/hcdrivers/input/gpio/hc_gpio_key.c" 2>/dev/null; then
    ok "own-9101: hc_gpio_key timer_setup port (5.12) aplicado"
  else
    bad "own-9101: hc_gpio_key sin port timer (setup_timer removida en 5.0 — no compila)"
  fi
  if grep -q 'ktime_ms_delta' "$KB/drivers/hcdrivers/musb/hcusb.c" 2>/dev/null; then
    ok "own-9102: hcusb.c timeval->ktime port (9-6a) aplicado"
  else
    bad "own-9102: hcusb.c sin port ktime (do_gettimeofday removida en 5.0)"
  fi
  if [ -f "$KB/drivers/usb/gadget/function/f_mtp.c" ] && grep -q 'mtp_alloc' "$KB/drivers/usb/gadget/function/f_mtp.c" 2>/dev/null; then
    ok "own-9103: f_mtp/f_ptp/AOA/audio_source porteados (vendor 0024 -> 5.12)"
  else
    bad "own-9103: f_mtp ausente (port vendor 0024 no aplicado)"
  fi
  if grep -q 'ida_is_empty' "$KB/drivers/hcdrivers/usb/gadget/function/f_iap.c" 2>/dev/null; then
    ok "own-9104: f_iap/f_ium API-5.12 port aplicado"
  else
    bad "own-9104: f_iap sin port API (access_ok/ida/alloc_ep_req era-4.4)"
  fi
else
  grep -q 'setup_timer' "$KB/drivers/hcdrivers/input/gpio/hc_gpio_key.c" 2>/dev/null \
    && ok "hc_gpio_key con setup_timer (API 4.4 — correcto para $KVER)" \
    || echo "  [INFO] hc_gpio_key: sin setup_timer en $KVER (verificar si el driver esta habilitado)"
fi

# 5. patch log del proyecto (evidencia primaria si existe) + sets
echo "-- patch log / sets --"
NP4=$(find "$P4" -maxdepth 1 -name '*.patch' ! -name '9*' 2>/dev/null | wc -l)
[ "$NP4" -eq "$NVEND" ] && ok "set SDK linux-$KVER = $NVEND patches vendor" || bad "set SDK vendor = $NP4 (esperado $NVEND)"
NS9=$(find "$P4" -maxdepth 1 -name '900*.patch' 2>/dev/null | wc -l)
NV9=$(find "$P4" -maxdepth 1 -name '910*.patch' 2>/dev/null | wc -l)
NPOWN=$(find "$OWN" -maxdepth 1 -name '*.patch' 2>/dev/null | wc -l)
[ "$NPOWN" -eq 4 ] && ok "set repo patches/buildroot/linux = 4 patches (genericos)" || bad "set repo genericos = $NPOWN (esperado 4)"
OWNVER="$PROJ/patches/buildroot/linux-$KVER"
NVOWN=$(find "$OWNVER" -maxdepth 1 -name '*.patch' 2>/dev/null | wc -l)
NVEXP=1
[ "$KVER" = "5.12.4" ] && NVEXP=4
[ "$NVOWN" -eq "$NVEXP" ] && ok "set repo patches/buildroot/linux-$KVER = $NVOWN patch (versionado, esperado $NVEXP)" || bad "set repo versionado linux-$KVER = $NVOWN (esperado $NVEXP)"
[ "$NS9" -eq 4 ] && ok "SDK sincronizado: 4 patches propios 900X-*.patch en linux-$KVER" \
  || { [ "$NS9" -eq 0 ] && echo "  [INFO] SDK linux-$KVER sin 900X aún (build_kernel.sh no corrido para esta versión; árbol verificado arriba)" \
       || bad "SDK linux-$KVER 900X = $NS9 (esperado 0 o 4)"; }
if [ "$NS9" -eq 4 ] && [ "$NPOWN" -eq 4 ]; then
  DH=$(diff <(cat "$OWN"/*.patch | sha256sum) <(cat "$P4"/900*.patch | sha256sum))
  [ -z "$DH" ] && ok "900X en SDK == copias repo (hash idéntico)" || bad "900X en SDK difieren del repo"
fi
if [ "$KVER" = "5.12.4" ]; then
  [ "$NV9" -eq "$NVEXP" ] && ok "SDK sincronizado: $NV9 patches versionados 910X en linux-5.12.4" \
    || { [ "$NV9" -eq 0 ] && echo "  [INFO] SDK linux-5.12.4 sin 910X aún (build_kernel.sh no corrido; árbol verificado abajo)" \
         || bad "SDK 910X = $NV9 (esperado 0 o $NVEXP)"; }
  if [ "$NV9" -eq "$NVEXP" ] && [ "$NVOWN" -eq "$NVEXP" ]; then
    DV=$(diff <(cat "$OWNVER"/*.patch | sha256sum) <(cat "$P4"/910*.patch | sha256sum))
    [ -z "$DV" ] && ok "910X en SDK == copias repo (hash idéntico)" || bad "910X en SDK difieren del repo"
  fi
fi
LOG="$HOME/work/r36sx-hclinux/logs/linux-patch-v1.log"
if [ "$KVER" = "4.4.186" ] && [ -f "$LOG" ]; then
  NA=$(grep -c "^Applying" "$LOG")
  [ "$NA" -eq 45 ] && ok "log: 45 'Applying' (41 vendor + 4 own — integrado 9-1)" \
    || { [ "$NA" -eq 41 ] && echo "  [INFO] log histórico 41 'Applying' (pre 9-1; árbol verificado arriba)" \
         || bad "log: $NA Applying (esperado 41 o 45)"; }
  grep -q "rsync.*SOURCE/linux-drivers" "$LOG" && ok "log: rsync linux-drivers (PRE_PATCH)" || bad "log sin rsync"
  grep -q "patch-ker.sh" "$LOG" && ok "log: yaffs2 patch-ker.sh" || bad "log sin yaffs2"
else
  echo "  [INFO] log v1 solo aplica a 4.4.186 (para $KVER: ver logs/<tag>-build_*.log del build)"
fi

# 6. relación con copias externas D: (VERIFIED IDENTICAL, sin doble aplicación) — solo 4.4.186
echo "-- copias externas /mnt/d/GitHub/KERNEL --"
if [ "$KVER" = "4.4.186" ]; then
  if [ -d "$KEXT/linux-4.4.186" ]; then
    D=$(diff <(cd "$P4" && find . -maxdepth 1 -name '*.patch' ! -name '9*' -exec sha256sum {} \; | sort -k2) \
             <(cd "$KEXT/linux-4.4.186" && find . -maxdepth 1 -name '*.patch' -exec sha256sum {} \; | sort -k2))
    [ -z "$D" ] && ok "41 vendor idénticos a D:\\GitHub\\KERNEL (VERIFIED IDENTICAL — no doble aplicación)" || bad "diff externo vs SDK (vendor)"
  else
    echo "  [INFO] $KEXT/linux-4.4.186 no accesible"
  fi
else
  echo "  [INFO] referencia externa disponible solo para 4.4.186 (para $KVER el canon es el tarball SDK + SHA)"
fi

echo "=== RESULT: FAIL=$FAIL ==="
if [ "$FAIL" -eq 0 ]; then echo "PATCH PROVENANCE: PASS"; else echo "PATCH PROVENANCE: FAIL"; exit 1; fi
