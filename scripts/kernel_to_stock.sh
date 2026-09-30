#!/usr/bin/env bash
# kernel_to_stock.sh — Fase E2: volver al kernel ANTERIOR (en consola stock = SU stock).
# Regla de simetría Fase E: este camino se implementó y probó ANTES que kernel_to_own.sh.
#
# Dos modos:
#   MODO ARCHIVO (default — consolas stock): restaurar vmlinux.uImage + dtb.bin dentro
#     del layout detectado. Fuente (prioridad):
#       1. kernel-switch/orig/  recovery point del PRIMER uso (en consola stock = SU kernel stock)
#       2. --from-set TS        snapshot: kernel-switch/sets/TS/
#       3. base golden stock    kernels stock de fábrica verificados contra
#                               manifests/GOLDEN_STOCK.sha256 (AVISO: kernel DE FÁBRICA).
#                               Default: base canónica del usuario (Desktop "R36SX V2.6
#                               (0712) Minimal Backup/cubegm"), fallback /mnt/d/R36SX/goldens-stock.
#   MODO CARPETA (--folder — consola con NOR propio, Fase D): boot/ → backup verificado;
#     cubegm/ (SISTEMA stock COMPLETO, 500MB+) instalado desde la base canónica con
#     verificación total + par contra goldens. REQUIERE flash NOR a fábrica (kit
#     factory-restore) — el script imprime los pasos exactos. Evidencia Fase D boot-2:
#     el NOR propio lee boot/ EXCLUSIVAMENTE → sin el flash, la consola no arranca.
#
# Uso:
#   ./scripts/kernel_to_stock.sh --sd /mnt/g [--from-set TS | --golden-dir DIR | --folder] [--avp] [--dry-run] [--yes]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/kernel_switch_lib.sh"

usage() {
  cat <<'EOF'
Uso: kernel_to_stock.sh --sd <ruta SD> [--from-set TS | --golden-dir DIR | --folder] [--avp] [--dry-run] [--yes]
Modo ARCHIVO: fuente = kernel-switch/orig · --from-set TS · base golden (kernel de FÁBRICA)
Modo CARPETA (--folder): boot/ -> backup; cubegm/ stock completa + PASO NOR factory-restore (impreso)
EOF
}

SD=""; FROM_SET=""; GOLDEN_DIR=""; AVP_FLAG=0; FOLDER=0
KS_YES=0; KS_DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --sd) SD="${2:?falta ruta}"; shift 2 ;;
    --from-set) FROM_SET="${2:?falta ts}"; shift 2 ;;
    --golden-dir) GOLDEN_DIR="${2:?falta dir}"; shift 2 ;;
    --avp) AVP_FLAG=1; shift ;;
    --folder) FOLDER=1; shift ;;
    --dry-run) KS_DRY_RUN=1; shift ;;
    --yes) KS_YES=1; shift ;;
    -h|--help) sed -n '2,26p' "$0"; echo; usage; exit 0 ;;
    *) echo "ERROR: argumento desconocido: $1" >&2; usage >&2; exit 1 ;;
  esac
done

SD="$(ks_require_sd "${SD:-}")"
KS_LAYOUT="$(ks_detect_layout "$SD")"

# ============ MODO CARPETA (E4): boot/ ↔ cubegm/ + flash NOR coordinado ============
if [ "$FOLDER" = "1" ]; then
  if [ "$KS_LAYOUT" != "boot" ]; then
    ks_die "to_stock --folder requiere layout boot/ (consola con NOR propio). Detectado: $KS_LAYOUT/. Para consolas stock usa el modo archivo (sin --folder)."
  fi
  ks_state_read "$SD"
  if [ "$KS_STATE" = "stock" ] && [ -d "$SD/cubegm" ]; then
    echo "La SD ya está en modo carpeta STOCK (cubegm/ presente, estado: $KS_STATE) — nada que hacer."
    exit 0
  fi
  if [ -n "$GOLDEN_DIR" ]; then FSRC="$GOLDEN_DIR"; else FSRC="$(ks_stock_base_dir)"; fi
  if [ -z "$FSRC" ]; then ks_die "sin base cubegm stock disponible — usa --golden-dir <carpeta cubegm stock>"; fi
  ks_check_golden_dir "$FSRC" 0   # par verificado contra el manifiesto del repo ANTES de tocar nada
  ks_show_info "$SD" "$KS_LAYOUT"
  FTS="$(date -u +%Y%m%dT%H%M%SZ)"
  FBDIR="$(ks_folders_dir "$SD")/boot-own-$FTS"
  echo "Plan (modo carpeta → STOCK):"
  echo "  1. $SD/boot/  →  kernel-switch/folders/boot-own-$FTS/ (backup move+manifest)"
  echo "  2. $FSRC/     →  $SD/cubegm/ (sistema stock COMPLETO — verificación total + par vs goldens)"
  echo "  3. PASO NOR (manual, impreso al final): kit factory-restore → bootloader de FÁBRICA (lee cubegm/)"
  echo
  echo "  *** AVISO: entre el swap y el flash NOR la consola NO arranca (gap inevitable, recovery BootROM-USB activo)."
  if [ "$KS_DRY_RUN" = "1" ]; then
    echo "DRY-RUN: no se escribe nada."
    exit 0
  fi
  ks_confirm "¿Ejecutar el swap de carpeta a STOCK en $SD?"
  ks_folder_backup "$SD/boot" "$FBDIR"
  ks_folder_install "$FSRC" "$SD/cubegm"
  ks_check_golden_dir "$SD/cubegm" 0
  ks_state_write "$SD" stock folder
  echo
  echo "OK — SD en modo carpeta STOCK: cubegm/ = sistema de fábrica (par == goldens, verificación total PASS)."
  echo "Nuestra boot/ respaldada en: kernel-switch/folders/boot-own-$FTS/"
  ks_print_nor_steps stock
  exit 0
fi

# --- resolver fuente (modo archivo) ---
SRCTYPE=""; SRC=""; KIND=""; NEWSTATE="stock"
ORIG="$(ks_state_dir "$SD")/orig"
if [ -n "$FROM_SET" ]; then
  SRCTYPE="set"; SRC="$(ks_state_dir "$SD")/sets/$FROM_SET"
  KIND="snapshot sets/$FROM_SET"; NEWSTATE="restored"
elif [ -d "$ORIG" ]; then
  SRCTYPE="orig"; SRC="$ORIG"
  KIND="backup original (primer uso del switcher)"
else
  if [ -n "$GOLDEN_DIR" ]; then
    SRC="$GOLDEN_DIR"
  else
    SRC="$(ks_stock_base_dir)"
  fi
  if [ -z "$SRC" ]; then
    ks_die "no hay backup (kernel-switch/orig) ni base golden disponible — nada que restaurar"
  fi
  SRCTYPE="golden"
  KIND="GOLDEN STOCK DE FÁBRICA ($SRC)"
fi

# --- verificar la fuente ANTES de tocar nada ---
if [ "$SRCTYPE" = "orig" ] || [ "$SRCTYPE" = "set" ]; then
  ks_verify_backup "$SRC"
fi
if [ "$SRCTYPE" = "golden" ]; then
  ks_check_golden_dir "$SRC" "$AVP_FLAG"
fi

ks_show_info "$SD" "$KS_LAYOUT"
echo "fuente de restauración: $KIND"

# hashes objetivo (validados hex-64: un manifest corrupto muere ANTES de escribir)
if [ "$SRCTYPE" = "golden" ]; then
  TK="$(ks_golden_hash vmlinux.uImage)"; TD="$(ks_golden_hash dtb.bin)"
else
  TK="$(ks_manifest_hashes "$SRC" vmlinux.uImage)" || true
  TD="$(ks_manifest_hashes "$SRC" dtb.bin)" || true
fi
if [ -z "$TK" ] || [ -z "$TD" ]; then ks_die "manifest de $SRC no aporta hashes válidos para el par — restore RECHAZADO"; fi

if [ "$(ks_sha256 "$SD/$KS_LAYOUT/vmlinux.uImage")" = "$TK" ] \
   && [ "$(ks_sha256 "$SD/$KS_LAYOUT/dtb.bin")" = "$TD" ]; then
  echo "El kernel de la fuente ya está instalado (hashes idénticos) — nada que hacer."
  exit 0
fi

echo "Plan: restaurar vmlinux.uImage + dtb.bin en $SD/$KS_LAYOUT/ desde: $KIND"
if [ "$SRCTYPE" = "golden" ]; then
  echo
  echo "  *** AVISO: base GOLDEN STOCK — se restaura el kernel DE FÁBRICA, no tu kernel anterior."
  echo
fi
if [ "$KS_DRY_RUN" = "1" ]; then
  echo "DRY-RUN: no se escribe nada."
  exit 0
fi
ks_confirm "¿Restaurar en $SD ($KS_LAYOUT/)? (se crea snapshot del estado actual)"

# snapshot del estado ACTUAL para poder volver (simetría en ambos sentidos)
ks_snapshot_current "$SD" "$KS_LAYOUT" "$AVP_FLAG"

if [ "$SRCTYPE" = "golden" ]; then
  ks_restore_golden "$SD" "$KS_LAYOUT" "$SRC" "$AVP_FLAG"
else
  ks_restore_from "$SD" "$KS_LAYOUT" "$SRC" "$AVP_FLAG"
fi

# post-verificación
if [ "$(ks_sha256 "$SD/$KS_LAYOUT/vmlinux.uImage")" != "$TK" ]; then ks_die "post-verify kernel FAIL"; fi
if [ "$(ks_sha256 "$SD/$KS_LAYOUT/dtb.bin")" != "$TD" ]; then ks_die "post-verify DTB FAIL"; fi
ks_state_write "$SD" "$NEWSTATE"
echo
echo "OK — kernel restaurado en $SD/$KS_LAYOUT/ (post-verify SHA256 PASS). Estado: $NEWSTATE"
echo "Kernel actual: $(ks_sha256 "$SD/$KS_LAYOUT/vmlinux.uImage" | cut -c1-8) · $(ks_describe_file "$SD/$KS_LAYOUT/vmlinux.uImage")"
echo "Vuelta al kernel propio: ./scripts/kernel_to_own.sh --sd $SD (o --from-set para un snapshot)"
