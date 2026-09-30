#!/usr/bin/env bash
# kernel_to_stock.sh — Fase E2: volver al kernel ANTERIOR (en consola stock = SU stock).
# Regla de simetría Fase E: este camino se implementó y probó ANTES que kernel_to_own.sh.
#
# Fuente de restauración (prioridad):
#   1. kernel-switch/orig/  recovery point del PRIMER uso del switcher (en consola
#                           stock = SU kernel stock original)
#   2. --from-set TS        snapshot específico: kernel-switch/sets/TS/
#   3. base golden stock    kernels stock de fábrica verificados contra
#                           manifests/GOLDEN_STOCK.sha256 ANTES de escribir.
#                           AVISO: restaura el kernel DE FÁBRICA (53b3e0b3/1258f1eb),
#                           no "tu kernel anterior". Default: base canónica del usuario
#                           (Desktop "R36SX V2.6 (0712) Minimal Backup/cubegm"), fallback
#                           /mnt/d/R36SX/goldens-stock. Override: --golden-dir DIR.
#
# Uso:
#   ./scripts/kernel_to_stock.sh --sd /mnt/g [--from-set TS | --golden-dir DIR] [--avp] [--dry-run] [--yes]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/kernel_switch_lib.sh"

usage() {
  cat <<'EOF'
Uso: kernel_to_stock.sh --sd <ruta SD> [--from-set TS | --golden-dir DIR] [--avp] [--dry-run] [--yes]
Fuente (prioridad): kernel-switch/orig · --from-set TS · base golden stock (kernel de FÁBRICA)
EOF
}

SD=""; FROM_SET=""; GOLDEN_DIR=""; AVP_FLAG=0
KS_YES=0; KS_DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --sd) SD="${2:?falta ruta}"; shift 2 ;;
    --from-set) FROM_SET="${2:?falta ts}"; shift 2 ;;
    --golden-dir) GOLDEN_DIR="${2:?falta dir}"; shift 2 ;;
    --avp) AVP_FLAG=1; shift ;;
    --dry-run) KS_DRY_RUN=1; shift ;;
    --yes) KS_YES=1; shift ;;
    -h|--help) sed -n '2,19p' "$0"; echo; usage; exit 0 ;;
    *) echo "ERROR: argumento desconocido: $1" >&2; usage >&2; exit 1 ;;
  esac
done

SD="$(ks_require_sd "${SD:-}")"
KS_LAYOUT="$(ks_detect_layout "$SD")"

# --- resolver fuente ---
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
