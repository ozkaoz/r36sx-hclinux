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
#   MODO CARPETA (--folder — SO COMPLETO stock, SIN flash NOR): boot/ = par de FÁBRICA
#     + cubegm/ (SISTEMA stock COMPLETO) CREADA desde la base canónica (verificación
#     total + par vs goldens). Requisito de producto: el usuario final NUNCA toca
#     HCProgrammer — el bootloader propio (one-time, Fase D) carga el kernel stock
#     desde boot/ y su sistema usa cubegm/. boot/ SIEMPRE presente → sin gap de arranque.
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

# ============ MODO CARPETA v2 (--folder): SO COMPLETO stock — SIN NOR ============
# Requisito de producto (usuario, 2026-09-30): el usuario final NO tiene HCProgrammer
# → el switch NUNCA toca NOR. Prerrequisito ONE-TIME (Fase D): bootloader propio
# (lee boot/). SO STOCK = boot/ con par de FÁBRICA + cubegm/ (sistema) CREADA.
# El kernel stock arranca su userspace vendor que lanza el sistema desde cubegm/.
# boot/ SIEMPRE presente → la consola nunca queda sin arrancar (sin gap).
FSRC=""
if [ "$FOLDER" = "1" ]; then
  if [ "$KS_LAYOUT" != "boot" ]; then
    ks_die "--folder requiere layout boot/ (bootloader propio Fase D). Detectado: $KS_LAYOUT/ — para consolas stock usa el modo archivo."
  fi
  ks_state_read "$SD"
  if [ "$KS_STATE" = "stock" ] && [ "$KS_STATE_MODE" = "folder" ] && [ -d "$SD/cubegm" ]; then
    echo "La SD ya está en SO STOCK completo (par stock en boot/ + cubegm/ presente) — nada que hacer."
    exit 0
  fi
  if [ -d "$SD/cubegm" ]; then
    ks_log "cubegm/ ya presente — se reutiliza"
  else
    if [ -n "$GOLDEN_DIR" ]; then FSRC="$GOLDEN_DIR"; else FSRC="$(ks_stock_base_dir)"; fi
    if [ -z "$FSRC" ]; then ks_die "sin base cubegm stock disponible — usa --golden-dir <carpeta cubegm stock>"; fi
    ks_check_golden_dir "$FSRC" 0   # par verificado ANTES de tocar nada
  fi
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

PAIR_ALREADY="no"
if [ "$(ks_sha256 "$SD/$KS_LAYOUT/vmlinux.uImage")" = "$TK" ] \
   && [ "$(ks_sha256 "$SD/$KS_LAYOUT/dtb.bin")" = "$TD" ]; then
  PAIR_ALREADY="yes"
fi
if [ "$PAIR_ALREADY" = "yes" ]; then
  if [ "$FOLDER" != "1" ] || [ -d "$SD/cubegm" ]; then
    echo "El kernel de la fuente ya está instalado (hashes idénticos) — nada que hacer."
    exit 0
  fi
fi

echo "Plan: restaurar vmlinux.uImage + dtb.bin en $SD/$KS_LAYOUT/ desde: $KIND"
if [ "$FOLDER" = "1" ]; then
  if [ -n "$FSRC" ]; then
    echo "  + CREAR $SD/cubegm/ (sistema stock COMPLETO desde $FSRC — verificación total + par vs goldens)"
  fi
  echo "  + boot/ SIEMPRE presente — el bootloader propio carga el kernel stock; SIN flash NOR, SIN gap"
fi
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

# modo carpeta v2: CREAR cubegm/ (sistema stock) ANTES de tocar el par —
# si la copia/verificación falla, el par queda intacto (la consola sigue arrancando)
if [ "$FOLDER" = "1" ] && [ -n "$FSRC" ]; then
  ks_folder_install "$FSRC" "$SD/cubegm"
  ks_check_golden_dir "$SD/cubegm" 0
fi

if [ "$SRCTYPE" = "golden" ]; then
  ks_restore_golden "$SD" "$KS_LAYOUT" "$SRC" "$AVP_FLAG"
else
  ks_restore_from "$SD" "$KS_LAYOUT" "$SRC" "$AVP_FLAG"
fi

# post-verificación
if [ "$(ks_sha256 "$SD/$KS_LAYOUT/vmlinux.uImage")" != "$TK" ]; then ks_die "post-verify kernel FAIL"; fi
if [ "$(ks_sha256 "$SD/$KS_LAYOUT/dtb.bin")" != "$TD" ]; then ks_die "post-verify DTB FAIL"; fi
if [ "$FOLDER" = "1" ]; then
  ks_state_write "$SD" "$NEWSTATE" folder
else
  ks_state_write "$SD" "$NEWSTATE"
fi
echo
echo "OK — kernel restaurado en $SD/$KS_LAYOUT/ (post-verify SHA256 PASS). Estado: $NEWSTATE"
if [ "$FOLDER" = "1" ]; then
  echo "SO STOCK COMPLETO: boot/ = kernel de fábrica + cubegm/ (sistema stock) presente."
  echo "SIN flash NOR: el bootloader propio carga el kernel stock desde boot/ y su sistema corre desde cubegm/."
  echo "Vuelta al SO propio: ./scripts/kernel_to_own.sh --sd $SD --folder [fuente]"
else
  echo "Kernel actual: $(ks_sha256 "$SD/$KS_LAYOUT/vmlinux.uImage" | cut -c1-8) · $(ks_describe_file "$SD/$KS_LAYOUT/vmlinux.uImage")"
  echo "Vuelta al kernel propio: ./scripts/kernel_to_own.sh --sd $SD (o --from-set para un snapshot)"
fi
