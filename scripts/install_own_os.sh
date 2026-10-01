#!/usr/bin/env bash
# install_own_os.sh — Fase E (USUARIO FINAL): SD STOCK → SO NUESTRO completo (TreeFrogUI).
#
# Punto de partida del usuario final: SD stock en una consola con bootloader de
# FÁBRICA (lee cubegm/). Su SD NO tiene backups, NI estado del switcher, NI
# nuestras carpetas. Este script lo crea TODO desde cero:
#   1. Backup de SUS archivos de boot de cubegm/ → kernel-switch/orig/ (recovery point)
#   2. Nuestro kernel + DTB DENTRO de cubegm/ (lo que su bootloader lee — SIN flash)
#   3. CREA treefrog/ + frogui/ + picoarch/ desde la base de nuestro SO
#      (su rootfs/ y roms/ ya valen — no se tocan; su sistema cubegm/ queda intacto
#       para la vuelta; avp.uImage de fábrica no se toca)
# La vuelta a SU stock: restore_stock_os.sh
#
# Uso:
#   ./scripts/install_own_os.sh --sd /mnt/<letra> [--os-base DIR] [--dry-run] [--yes]
#   --os-base (default): Desktop "SO PROPIO" — copia completa de nuestro SO
#                        (boot/ + treefrog/ + frogui/ + picoarch/)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/kernel_switch_lib.sh"

usage() {
  cat <<'EOF'
Uso: install_own_os.sh --sd <ruta SD> [--os-base DIR] [--dry-run] [--yes]
Usuario FINAL (SD stock, layout cubegm/): instala nuestro SO completo (kernel en cubegm/ + carpetas treefrog/, frogui/, picoarch/)
La vuelta: restore_stock_os.sh --sd <ruta SD>
EOF
}

SD=""; OS_BASE=""; KS_YES=0; KS_DRY_RUN=0; CREATED_FOLDERS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --sd) SD="${2:?falta ruta}"; shift 2 ;;
    --os-base) OS_BASE="${2:?falta dir}"; shift 2 ;;
    --dry-run) KS_DRY_RUN=1; shift ;;
    --yes) KS_YES=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; echo; usage; exit 0 ;;
    *) echo "ERROR: argumento desconocido: $1" >&2; usage >&2; exit 1 ;;
  esac
done

SD="$(ks_require_sd "${SD:-}")"
KS_LAYOUT="$(ks_detect_layout "$SD")"

if [ "$KS_LAYOUT" != "cubegm" ]; then
  ks_die "install_own_os es para SDs STOCK (layout cubegm/, bootloader de fábrica). Detectado: $KS_LAYOUT/ — para una consola con nuestro bootloader usa kernel_to_own.sh --folder"
fi

if [ -z "$OS_BASE" ]; then OS_BASE="$KS_OWN_OS_BASE_DEFAULT"; fi
if [ ! -f "$OS_BASE/boot/vmlinux.uImage" ] || [ ! -f "$OS_BASE/boot/dtb.bin" ]; then
  ks_die "base de nuestro SO incompleta: $OS_BASE (se espera boot/vmlinux.uImage + boot/dtb.bin)"
fi
for f in "${KS_OWN_OS_FOLDERS[@]}"; do
  if [ ! -d "$OS_BASE/$f" ]; then ks_die "falta $f/ en la base de nuestro SO: $OS_BASE"; fi
done

HK="$(ks_sha256 "$OS_BASE/boot/vmlinux.uImage")"
HD="$(ks_sha256 "$OS_BASE/boot/dtb.bin")"

ks_show_info "$SD" "$KS_LAYOUT"
echo "SO propio a instalar desde: $OS_BASE"
echo "  kernel ${HK:0:8} · DTB ${HD:0:8} · carpetas: ${KS_OWN_OS_FOLDERS[*]}"

# --- idempotencia: ya instalado (par nuestro + carpetas + estado enduser) ---
PAIR_OK="no"
if [ "$(ks_sha256 "$SD/$KS_LAYOUT/vmlinux.uImage")" = "$HK" ] \
   && [ "$(ks_sha256 "$SD/$KS_LAYOUT/dtb.bin")" = "$HD" ]; then
  PAIR_OK="yes"
fi
FOLDERS_OK="yes"
for f in "${KS_OWN_OS_FOLDERS[@]}"; do
  if [ ! -d "$SD/$f" ]; then FOLDERS_OK="no"; fi
done
ks_state_read "$SD"
if [ "$PAIR_OK" = "yes" ] && [ "$FOLDERS_OK" = "yes" ] && [ "$KS_STATE" = "own" ]; then
  echo "Nuestro SO ya está instalado en esta SD (par + carpetas + estado) — nada que hacer."
  exit 0
fi

echo "Plan (usuario final — SD stock → SO propio):"
echo "  1. Backup de SUS archivos de boot ($KS_LAYOUT/) → kernel-switch/orig/  [recovery point]"
echo "  2. cubegm/vmlinux.uImage + dtb.bin ← nuestro par (verificación SHA256 en cada copia)"
for f in "${KS_OWN_OS_FOLDERS[@]}"; do
  if [ -d "$SD/$f" ]; then
    echo "  3. $f/ ya presente en la SD — se CONSERVA (no se sobreescribe)"
  else
    echo "  3. CREAR $f/ ← $OS_BASE/$f/ (copia verificada)"
  fi
done
echo "  (avp.uImage no se toca — fábrica en ambos; su sistema cubegm/ queda intacto para la vuelta)"
if [ "$KS_DRY_RUN" = "1" ]; then
  echo "DRY-RUN: no se escribe nada."
  exit 0
fi
ks_confirm "¿Instalar nuestro SO en $SD?"

ORIG="$(ks_state_dir "$SD")/orig"
if [ ! -d "$ORIG" ]; then
  ks_backup_pair "$SD" "$KS_LAYOUT" "$ORIG" 0
  ks_log "backup ORIGINAL del stock del usuario: kernel-switch/orig/"
fi

ks_install_file "$OS_BASE/boot/vmlinux.uImage" "$SD/$KS_LAYOUT/vmlinux.uImage"
ks_install_file "$OS_BASE/boot/dtb.bin" "$SD/$KS_LAYOUT/dtb.bin"

for f in "${KS_OWN_OS_FOLDERS[@]}"; do
  if [ -d "$SD/$f" ]; then
    ks_log "$f/ ya presente en la SD — se CONSERVA (pre-existente del usuario, no se sobreescribe)"
  else
    ks_folder_install "$OS_BASE/$f" "$SD/$f"
    CREATED_FOLDERS="$CREATED_FOLDERS $f"
  fi
done
# Registro de las carpetas que NOSOTROS creamos (restore elimina SOLO estas;
# las pre-existentes del usuario — p.ej. frogui/ del installer de TreeFrogUI — se conservan)
if [ -n "$CREATED_FOLDERS" ]; then
  printf '%s\n' $CREATED_FOLDERS > "$(ks_state_dir "$SD")/created-folders"
  ks_log "carpetas creadas por nosotros (registro para el restore): $CREATED_FOLDERS"
else
  rm -f "$(ks_state_dir "$SD")/created-folders"
fi

if [ "$(ks_sha256 "$SD/$KS_LAYOUT/vmlinux.uImage")" != "$HK" ]; then ks_die "post-verify kernel FAIL"; fi
if [ "$(ks_sha256 "$SD/$KS_LAYOUT/dtb.bin")" != "$HD" ]; then ks_die "post-verify DTB FAIL"; fi
ks_state_write "$SD" own enduser
echo
echo "OK — NUESTRO SO instalado (kernel ${HK:0:8} en $KS_LAYOUT/ + ${KS_OWN_OS_FOLDERS[*]})."
echo "Expulsa la SD con seguridad, ponla en la consola y enciende: menú TreeFrogUI."
echo "Vuelta a TU stock original: ./scripts/restore_stock_os.sh --sd $SD"
