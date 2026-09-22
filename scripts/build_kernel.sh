#!/usr/bin/env bash
# build_kernel.sh <board> [variant] — Fase 4B+: build kernel con board propia del repo.
# Flujo reproducible: repo (fuente de verdad) -> workspace SDK -> Buildroot.
# Uso: ./scripts/build_kernel.sh r36sx-v26          (kernel del defconfig base: 4.4.186)
#      ./scripts/build_kernel.sh r36sx-v26 k512     (defconfig k512: kernel 5.12.4)
#
# Fase 9-1 (ADR-014): paso 3b — parches kernel PROPIOS (patches/buildroot/linux/) ->
# SDK patches/linux-<version>/ prefijo 900X (targets: SOURCE/linux-drivers, agnósticos).
#
# Fase 9-3.1: embed DETERMINISTA. En el buildroot del SDK:
#   - `world` == `target-post-image` (Makefile:600) — SOLO la cadena de imágenes.
#   - `rootfs-cpio` también es solo imagen+finalize: NO construye packages.
#   - Los packages (hcfota, libhudi, liblvgl, kmod, busybox-configs...) se
#     construyen e instalan SOLO bajo el GOAL DEFAULT (`make` sin target).
#   Flujo correcto: make default (todo) -> cp rootfs.cpio (FULL) -> linux-rebuild
#   (re-embebe). El flujo pre-9-3.1 empaquetaba mid-build: el cpio embebido perdía
#   los packages tardíos (evidencia: diff cpio embebido 8e vs k512, 2026-09-22).
#
# Fase 9-3.2: overlays con re-finalize forzado — el marker .fase8-target-cleaned se
# borra manualmente (o por git checkout) cuando el overlay cambia; el próximo build
# re-copia overlays desde cero (mecanismo original fase-8 intacto).
set -euo pipefail
BOARD="${1:?uso: build_kernel.sh r36sx-v26 [variant]}"
VARIANT="${2:-}"
W="$HOME/work/r36sx-hclinux"
S="$W/sdk/hclinux-2024.02.y.2/hclinux"
R="$(cd "$(dirname "$BASH_SOURCE")/.." && pwd)"
TAG="$BOARD${VARIANT:+-$VARIANT}"
O="$W/build/$TAG"
LOG="$W/logs/${TAG}-build_$(date +%Y%m%d_%H%M%S).log"

benign_postimage() {
  tail -8 "$LOG" | grep -qE 'bootloader.bin not found|bigger than partition|target-post-image'
}

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
KFRAG="$R/boards/$BOARD/kernel/$BOARD.config.fragment"
[ -f "$KFRAG" ] && cp "$KFRAG" "$BD/kernel/$BOARD.config.fragment"
KFRAG_V="$R/boards/$BOARD/kernel/$BOARD${VARIANT:+-$VARIANT}.config.fragment"
[ -f "$KFRAG_V" ] && cp "$KFRAG_V" "$BD/kernel/"
OVERLAY_SRC="$R/boards/$BOARD/rootfs-overlay"
if [ -d "$OVERLAY_SRC" ]; then
  mkdir -p "$BD/rootfs-overlay"
  cp -r "$OVERLAY_SRC"/. "$BD/rootfs-overlay/"
fi
OVERLAY_OWN="$R/boards/$BOARD/rootfs-overlay-own"
if [ -d "$OVERLAY_OWN" ]; then
  mkdir -p "$BD/rootfs-overlay-own"
  cp -r "$OVERLAY_OWN"/. "$BD/rootfs-overlay-own/"
fi
BL_CFG="$R/boards/$BOARD/bootloader/${BOARD}_bl_defconfig"
if [ -f "$BL_CFG" ]; then
  mkdir -p "$BD/bootloader"
  cp "$BL_CFG" "$BD/${BOARD}_bl_defconfig"
  if [ -f "$BD/ddrinit/ddrinit-factory-12288.abs" ]; then
    H=$(sha256sum "$BD/ddrinit/ddrinit-factory-12288.abs" | cut -c1-16)
    [ "$H" = "d944d9afb427a404" ] || { echo "ERROR: DDR-init de fabrica hash invalido ($H)"; exit 1; }
    echo "DDR-init de fabrica verificado (d944d9af)"
  else
    echo "AVISO: falta ddrinit/ddrinit-factory-12288.abs en el board dir del SDK (D-2b lo requiere)"
  fi
fi

# 3b. Fase 9-1 (ADR-014): parches kernel PROPIOS repo -> SDK patches/linux-<version>/
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
  # 9-4: parches PROPIOS version-specific (patches/buildroot/linux-$KVER/) —
  # prefijo 910X (ordenan tras los 900X genericos). Para ports que SOLO aplican
  # a esta version de kernel (p.ej. timer API 5.x) y que romperian otras versiones
  # (el mismo archivo fuente es compartido via SOURCE/linux-drivers rsync).
  OWNVER="$R/patches/buildroot/linux-$KVER"
  if [ -d "$OWNVER" ]; then
    NV=0
    for pv in "$OWNVER"/*.patch; do
      [ -f "$pv" ] || continue
      cp "$pv" "$S/patches/linux-$KVER/910$(basename "$pv" | sed 's/^000//')"
      NV=$((NV+1))
    done
    [ "$NV" -gt 0 ] && echo "own-patches-versioned: $NV -> SDK patches/linux-$KVER/ (prefijo 910X)"
  fi
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

if grep -q "rootfs-own.cpio" "$KFRAG" 2>/dev/null; then
  # limpiar target contaminado de overlays anteriores (una sola vez; para forzar
  # re-finalize tras un cambio de overlay: rm del marker a mano y rebuild)
  if [ ! -f "$O/.fase8-target-cleaned" ]; then
    rm -rf "$O/target"; find "$O/build" -name .stamp_target_installed -delete 2>/dev/null
    touch "$O/.fase8-target-cleaned"; echo "fase8: target limpio (re-finalize forzado)"
  fi
  # bootstrap: el kernel del make default necesita INITRAMFS_SOURCE existente;
  # placeholder = overlay-own empaquetado; luego el cpio real re-embebe.
  KOWN="$W/artifacts/$BOARD/rootfs-own.cpio"
  mkdir -p "$(dirname "$KOWN")"
  if [ ! -s "$KOWN" ]; then
    ( cd "$R/boards/$BOARD/rootfs-overlay-own" && find . | cpio -o -H newc -R 0:0 2>/dev/null > "$KOWN" )
    echo "fase8: bootstrap placeholder cpio ($(stat -c%s "$KOWN") B)"
  fi
  # 9-3.1: GOAL DEFAULT — construye TODOS los packages + finalize + imágenes.
  # 'world'/'rootfs-cpio' NO construyen packages (Makefile:600 world==post-image).
  # post-image falla benignamente (ADR-008) DESPUÉS de que rootfs.cpio ya está.
  if ! make O="$O" BR2_EXTERNAL="$S" -j16 >> "$LOG" 2>&1; then
    if benign_postimage; then
      echo "make default: post-image benign failure (ADR-008) — packages+images completos, continuando"
    else
      echo "BUILD FAIL — tail:"; tail -25 "$LOG"; exit 1
    fi
  fi
  # 9-3.1: el cpio del goal default contiene TODO el target (packages completos)
  cp "$O/images/rootfs.cpio" "$KOWN"
  echo "rootfs-own: $KOWN ($(stat -c%s "$KOWN") bytes)"
  # re-embeber el cpio full en el kernel (re-links vmlinux)
  make O="$O" BR2_EXTERNAL="$S" linux-rebuild >> "$LOG" 2>&1 || { echo "LINUX-REBUILD FAIL — tail:"; tail -15 "$LOG"; exit 1; }
  # el uImage lo genera la CADENA DE IMAGENES (post-image "Generating vmlinux.uImage"),
  # NO el linux package — hace falta un make final para regenerarlo desde el
  # vmlinux re-linkeado (evidencia run-9: uImage stale post-rebuild, 2026-09-22).
  if ! make O="$O" BR2_EXTERNAL="$S" -j16 >> "$LOG" 2>&1; then
    if benign_postimage; then
      echo "make final: post-image benign failure (ADR-008) — uImage+imagenes regenerados, continuando"
    else
      echo "BUILD FAIL — tail:"; tail -25 "$LOG"; exit 1
    fi
  fi
else
  make O="$O" -j16 >> "$LOG" 2>&1 || { echo "BUILD FAIL — tail:"; tail -25 "$LOG"; exit 1; }
fi

echo "=== BUILD OK — artefactos $O/images/ ==="
ls -la "$O/images/" | head -12
echo "log: $LOG"
echo "=== gates: ejecutar audit_toolchain.sh + audit_kernel_patches.sh + compare_dtb_semantics.sh ==="
