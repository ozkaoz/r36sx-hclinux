#!/usr/bin/env bash
# build_kernel.sh <board> [variant] — Fase 4B+: build kernel con board propia del repo.
# Flujo reproducible: repo (fuente de verdad) -> workspace SDK -> Buildroot.
# Uso: ./scripts/build_kernel.sh r36sx-v26          (kernel del defconfig base: 4.4.186)
#      ./scripts/build_kernel.sh r36sx-v26 k512     (defconfig hichip_hc16xx_r36sx_v26_k512: kernel 5.12.4)
# Fase 9-1 (ADR-014): paso 3b — parches kernel PROPIOS (patches/buildroot/linux/) se
# sincronizan a SDK patches/linux-<version>/ con prefijo 900X (orden posterior al set
# vendor 00XX; archivos target: SOURCE/linux-drivers, agnósticos de versión).
set -euo pipefail
BOARD="${1:?uso: build_kernel.sh r36sx-v26 [variant]}"
VARIANT="${2:-}"
W="$HOME/work/r36sx-hclinux"
S="$W/sdk/hclinux-2024.02.y.2/hclinux"
R="$(cd "$(dirname "$BASH_SOURCE")/.." && pwd)"
TAG="$BOARD${VARIANT:+-$VARIANT}"
O="$W/build/$TAG"
LOG="$W/logs/${TAG}-build_$(date +%Y%m%d_%H%M%S).log"

# 1. validar insumos del repo
DTS_REPO="$R/boards/$BOARD/dts/$BOARD.dts"
DEF_REPO="$R/configs/buildroot/hichip_hc16xx_${BOARD//-/_}${VARIANT:+_$VARIANT}_defconfig"
[ -f "$DTS_REPO" ] || { echo "ERROR: falta $DTS_REPO"; exit 1; }
[ -f "$DEF_REPO" ] || { echo "ERROR: falta $DEF_REPO"; exit 1; }
[ -d "$S" ] || { echo "ERROR: SDK no extraído — scripts/prepare_sdk.sh"; exit 1; }

# 2. regenerar DTS desde la referencia auditada (no confiar en copias)
"$R/scripts/make_board_dts.sh"

# 3. sincronizar board files repo -> workspace SDK (board propia; vendor intacto)
BD="$S/board/hichip/hc16xx/${BOARD//-/_}"
mkdir -p "$BD/dts" "$BD/kernel"
cp "$DTS_REPO" "$BD/dts/$BOARD.dts"
cp "$DEF_REPO" "$S/configs/$(basename "$DEF_REPO")"
# fragmento de kernel config (board-specific deltas, p.ej. CONFIG_CHECK_ADC) -> workspace
KFRAG="$R/boards/$BOARD/kernel/$BOARD.config.fragment"
[ -f "$KFRAG" ] && cp "$KFRAG" "$BD/kernel/$BOARD.config.fragment"
# Fase 9-3: fragment de variante (deltas k512-only, p.ej. musb off) — el defconfig
# de la variante lista AMBOS fragments en BR2_LINUX_KERNEL_CONFIG_FRAGMENT_FILES.
KFRAG_V="$R/boards/$BOARD/kernel/$BOARD${VARIANT:+-$VARIANT}.config.fragment"
[ -f "$KFRAG_V" ] && cp "$KFRAG_V" "$BD/kernel/"
# rootfs-overlay de la board (p.ej. etc/init.d/S99app para lanzar la UI) -> workspace
OVERLAY_SRC="$R/boards/$BOARD/rootfs-overlay"
if [ -d "$OVERLAY_SRC" ]; then
  mkdir -p "$BD/rootfs-overlay"
  cp -r "$OVERLAY_SRC"/. "$BD/rootfs-overlay/"
fi
# Fase 8a: overlay propio minimo -> workspace (el defconfig lo referencia)
OVERLAY_OWN="$R/boards/$BOARD/rootfs-overlay-own"
if [ -d "$OVERLAY_OWN" ]; then
  mkdir -p "$BD/rootfs-overlay-own"
  cp -r "$OVERLAY_OWN"/. "$BD/rootfs-overlay-own/"
fi
# Fase D-2b: bootloader propio — bl defconfig de la board -> workspace SDK
BL_CFG="$R/boards/$BOARD/bootloader/${BOARD}_bl_defconfig"
if [ -f "$BL_CFG" ]; then
  mkdir -p "$BD/bootloader"
  cp "$BL_CFG" "$BD/${BOARD}_bl_defconfig"
  # DDR-init de fabrica (del dump NOR, D:\R36SX\nor-dump-20260919, sha verificado en reposicion)
  if [ -f "$BD/ddrinit/ddrinit-factory-12288.abs" ]; then
    H=$(sha256sum "$BD/ddrinit/ddrinit-factory-12288.abs" | cut -c1-16)
    [ "$H" = "d944d9afb427a404" ] || { echo "ERROR: DDR-init de fabrica hash invalido ($H)"; exit 1; }
    echo "DDR-init de fabrica verificado (d944d9af)"
  else
    echo "AVISO: falta ddrinit/ddrinit-factory-12288.abs en el board dir del SDK (D-2b lo requiere)"
  fi
fi

# 3b. Fase 9-1 (ADR-014): parches kernel PROPIOS repo -> SDK patches/linux-<version>/
# (prefijo 900X: aplican tras el set vendor 00XX; targets = SOURCE/linux-drivers,
#  agnósticos de versión de kernel — sirve para 4.4.186 y 5.12.4 por igual)
KVER=$(sed -n 's/^BR2_LINUX_KERNEL_VERSION="\([^"]*\)"/\1/p' "$DEF_REPO")
OWNPATCH="$R/patches/buildroot/linux"
if [ -n "$KVER" ] && [ -d "$OWNPATCH" ]; then
  NP=0
  for p in "$OWNPATCH"/*.patch; do
    [ -f "$p" ] || continue
    cp "$p" "$S/patches/linux-$KVER/900$(basename "$p" | sed 's/^000//')"
    NP=$((NP+1))
  done
  [ "$NP" -gt 0 ] && echo "own-patches: $NP -> SDK patches/linux-$KVER/ (kernel $KVER, prefijo 900X)"
  # yaffs2: el hook PRE_PATCH del SDK (LINUX_PATCH_HICHIP_DRIVERS) hace cd patches/linux/yaffs2
  # INCONDICIONALMENTE — el set 5.12.4 no lo trae. Integración INERTE (YAFFS off en ambos
  # base configs, verificado 2026-09-22): se copia al dir de versión para que el hook no falle.
  if [ "$KVER" != "4.4.186" ] && [ -d "$S/patches/linux-4.4.186/yaffs2" ] && [ ! -d "$S/patches/linux-$KVER/yaffs2" ]; then
    cp -r "$S/patches/linux-4.4.186/yaffs2" "$S/patches/linux-$KVER/"
    echo "yaffs2: integrado a patches/linux-$KVER/ (inerte: CONFIG_YAFFS off en base config)"
  fi
fi

# 4. entorno validado (docs/BUILD.md + TOOLCHAIN_PROVENANCE)
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export BR2_DL_DIR="$W/cache/dl"
export HOST_EXTRACFLAGS="-fcommon"

mkdir -p "$O" ; cd "$S/buildroot"
make O="$O" BR2_EXTERNAL="$S" "$(basename "$DEF_REPO")" > "$LOG" 2>&1

# Fase 8a: generar ROOTFS PROPIO (Buildroot cpio) si el fragmento lo referencia
if grep -q "rootfs-own.cpio" "$KFRAG" 2>/dev/null; then
  # limpiar target contaminado de overlays anteriores (una sola vez)
  if [ ! -f "$O/.fase8-target-cleaned" ]; then
    rm -rf "$O/target"; find "$O/build" -name .stamp_target_installed -delete 2>/dev/null
    touch "$O/.fase8-target-cleaned"; echo "fase8: target limpio (re-finalize forzado)"
  fi
  # bootstrap: el kernel puede rebuildarse durante rootfs-cpio y necesita que el
  # cpio EXISTA (primera corrida). Placeholder = overlay-own empaquetado; luego
  # se sobreescribe con el cpio real y linux-rebuild re-embebe.
  KOWN="$W/artifacts/$BOARD/rootfs-own.cpio"
  mkdir -p "$(dirname "$KOWN")"
  if [ ! -s "$KOWN" ]; then
    ( cd "$R/boards/$BOARD/rootfs-overlay-own" && find . | cpio -o -H newc -R 0:0 2>/dev/null > "$KOWN" )
    echo "fase8: bootstrap placeholder cpio ($(stat -c%s "$KOWN") B)"
  fi
  make O="$O" BR2_EXTERNAL="$S" rootfs-cpio >> "$LOG" 2>&1 || { echo "ROOTFS-CPIO FAIL — tail:"; tail -15 "$LOG"; exit 1; }
  cp "$O/images/rootfs.cpio" "$KOWN"
  echo "rootfs-own: $KOWN ($(stat -c%s "$KOWN") bytes)"
  export KOWN_FRESH=1
fi
# Fase 8a: forzar re-link del kernel para embeber el cpio recien generado
if [ -n "${KOWN_FRESH:-}" ]; then
  make O="$O" BR2_EXTERNAL="$S" linux-rebuild >> "$LOG" 2>&1 || { echo "LINUX-REBUILD FAIL — tail:"; tail -15 "$LOG"; exit 1; }
fi
make O="$O" -j16 >> "$LOG" 2>&1 || { echo "BUILD FAIL — tail:"; tail -25 "$LOG"; exit 1; }
# nota: 'bootloader.bin not found' en target-post-image = esperado (ADR-008)

echo "=== BUILD OK — artefactos $O/images/ ==="
ls -la "$O/images/" | head -12
echo "log: $LOG"
echo "=== gates: ejecutar audit_toolchain.sh + audit_kernel_patches.sh + compare_dtb_semantics.sh ==="
