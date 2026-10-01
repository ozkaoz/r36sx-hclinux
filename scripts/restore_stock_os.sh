#!/usr/bin/env bash
# restore_stock_os.sh — Fase E (USUARIO FINAL): SO NUESTRO → SU SO STOCK original.
# Requiere: que el SO propio fue instalado con install_own_os.sh (usa su backup).
#   1. Restaura SU par de boot de cubegm/ desde kernel-switch/orig/ (verificado)
#   2. ELIMINA nuestras carpetas (treefrog/ frogui/ picoarch/) → backup en
#      kernel-switch/folders/own-os-<ts>/ (nada se pierde; borrable a mano)
# Su sistema cubegm/ (stack stock) nunca fue tocado → la SD vuelve al estado
# stock ORIGINAL (mismos archivos de boot de fábrica).
#
# Uso:
#   ./scripts/restore_stock_os.sh --sd /mnt/<letra> [--dry-run] [--yes]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/kernel_switch_lib.sh"

usage() {
  cat <<'EOF'
Uso: restore_stock_os.sh --sd <ruta SD> [--dry-run] [--yes]
Vuelve a TU SO stock original (par de boot restaurado desde el backup + nuestras carpetas a backup)
EOF
}

SD=""
KS_YES=0; KS_DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --sd) SD="${2:?falta ruta}"; shift 2 ;;
    --dry-run) KS_DRY_RUN=1; shift ;;
    --yes) KS_YES=1; shift ;;
    -h|--help) sed -n '2,13p' "$0"; echo; usage; exit 0 ;;
    *) echo "ERROR: argumento desconocido: $1" >&2; usage >&2; exit 1 ;;
  esac
done

SD="$(ks_require_sd "${SD:-}")"
KS_LAYOUT="$(ks_detect_layout "$SD")"

if [ "$KS_LAYOUT" != "cubegm" ]; then
  ks_die "restore_stock_os es para SDs de usuario final (layout cubegm/). Detectado: $KS_LAYOUT/ — para una consola con nuestro bootloader usa kernel_to_stock.sh --folder"
fi

ORIG="$(ks_state_dir "$SD")/orig"
if [ ! -d "$ORIG" ]; then
  ks_die "no hay backup del stock del usuario (kernel-switch/orig/) — esta SD nunca recibió nuestro SO con install_own_os.sh"
fi
ks_verify_backup "$ORIG"
TK="$(ks_manifest_hashes "$ORIG" vmlinux.uImage)" || true
TD="$(ks_manifest_hashes "$ORIG" dtb.bin)" || true
if [ -z "$TK" ] || [ -z "$TD" ]; then ks_die "el backup orig no aporta hashes válidos — restore RECHAZADO"; fi

# Carpetas a eliminar: SOLO las que NOSOTROS creamos (registro del install).
# Las pre-existentes del usuario (p.ej. frogui/ del installer de TreeFrogUI) se CONSERVAN.
# Legado (sin registro): todas las del stack (comportamiento original).
CF_FILE="$(ks_state_dir "$SD")/created-folders"
FOLDERS_PRESENT=""
if [ -s "$CF_FILE" ]; then
  while IFS= read -r fname; do
    [ -n "$fname" ] || continue
    if [ -d "$SD/$fname" ]; then FOLDERS_PRESENT="$FOLDERS_PRESENT $SD/$fname"; fi
  done < "$CF_FILE"
else
  for f in "${KS_OWN_OS_FOLDERS[@]}"; do
    if [ -d "$SD/$f" ]; then FOLDERS_PRESENT="$FOLDERS_PRESENT $SD/$f"; fi
  done
fi

ks_show_info "$SD" "$KS_LAYOUT"
PAIR_ALREADY="no"
if [ "$(ks_sha256 "$SD/$KS_LAYOUT/vmlinux.uImage")" = "$TK" ] \
   && [ "$(ks_sha256 "$SD/$KS_LAYOUT/dtb.bin")" = "$TD" ]; then
  PAIR_ALREADY="yes"
fi
if [ "$PAIR_ALREADY" = "yes" ] && [ -z "$FOLDERS_PRESENT" ]; then
  echo "La SD ya está en su estado stock original — nada que hacer."
  exit 0
fi

echo "Plan (usuario final — SO propio → SU stock original):"
echo "  1. cubegm/vmlinux.uImage + dtb.bin ← SU par original (kernel-switch/orig/, verificado)"
if [ -n "$FOLDERS_PRESENT" ]; then
  echo "  2. ELIMINAR nuestras carpetas:$FOLDERS_PRESENT → kernel-switch/folders/own-os-<ts>/ (backup)"
else
  echo "  2. sin carpetas nuestras que eliminar"
fi
if [ "$KS_DRY_RUN" = "1" ]; then
  echo "DRY-RUN: no se escribe nada."
  exit 0
fi
ks_confirm "¿Restaurar TU stock original en $SD?"

# snapshot del par nuestro actual (para poder re-instalar el par sin la base)
if [ "$PAIR_ALREADY" != "yes" ]; then
  ks_snapshot_current "$SD" "$KS_LAYOUT" 0
  ks_restore_from "$SD" "$KS_LAYOUT" "$ORIG" 0
  if [ "$(ks_sha256 "$SD/$KS_LAYOUT/vmlinux.uImage")" != "$TK" ]; then ks_die "post-verify kernel FAIL"; fi
  if [ "$(ks_sha256 "$SD/$KS_LAYOUT/dtb.bin")" != "$TD" ]; then ks_die "post-verify DTB FAIL"; fi
fi

if [ -n "$FOLDERS_PRESENT" ]; then
  TS="$(date -u +%Y%m%dT%H%M%SZ)"
  DEST="$(ks_folders_dir "$SD")/own-os-$TS"
  ks_folder_backup_multi "$DEST" $FOLDERS_PRESENT
fi

ks_state_write "$SD" stock enduser
echo
echo "OK — SD restaurada a TU stock original (par de fábrica verificado; sistema cubegm/ intacto)."
echo "Nuestras carpetas están en: kernel-switch/folders/own-os-*/ (borrables a mano si no las necesitas)."
echo "Para volver a nuestro SO: ./scripts/install_own_os.sh --sd $SD"
