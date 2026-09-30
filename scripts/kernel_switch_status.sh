#!/usr/bin/env bash
# kernel_switch_status.sh — Fase E3: estado del switcher en la SD (READ-ONLY, seguro).
# Uso: ./scripts/kernel_switch_status.sh --sd /mnt/g
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/kernel_switch_lib.sh"

SD=""
while [ $# -gt 0 ]; do
  case "$1" in
    --sd) SD="${2:?falta ruta}"; shift 2 ;;
    -h|--help) sed -n '2,3p' "$0"; exit 0 ;;
    *) echo "ERROR: argumento desconocido: $1" >&2; exit 1 ;;
  esac
done

SD="$(ks_require_sd "${SD:-}")"
KS_LAYOUT="$(ks_detect_layout "$SD")"
ks_show_info "$SD" "$KS_LAYOUT"

KD="$(ks_state_dir "$SD")"
echo "kernel-switch: $KD"
if [ -d "$KD/orig" ]; then
  if ks_backup_ok "$KD/orig"; then
    echo "  orig/  OK (recovery point del primer uso)"
  else
    echo "  orig/  *** CORRUPTO o sin manifest ***"
  fi
else
  echo "  orig/  (ninguno — primer uso del switcher pendiente)"
fi
if [ -d "$KD/sets" ]; then
  for s in "$KD/sets"/*/; do
    [ -d "$s" ] || continue
    name="$(basename "$s")"
    if ks_backup_ok "$s"; then
      echo "  sets/$name  OK"
    else
      echo "  sets/$name  *** CORRUPTO o sin manifest ***"
    fi
  done
else
  echo "  sets/  (ninguno)"
fi
if [ -d "$(ks_folders_dir "$SD")" ]; then
  for fb in "$(ks_folders_dir "$SD")"/*/; do
    [ -d "$fb" ] || continue
    name="$(basename "$fb")"
    nf="$(find "$fb" -type f 2>/dev/null | wc -l)"
    if [ -f "$fb.manifest.sha256" ]; then
      echo "  folders/$name  ($nf archivos, manifest presente)"
    else
      echo "  folders/$name  ($nf archivos, *** SIN manifest ***)"
    fi
  done
fi
GB="$(ks_stock_base_dir)"
if [ -n "$GB" ]; then
  echo "base golden stock: $GB (disponible)"
else
  echo "base golden stock: NO disponible en las rutas canónicas"
fi
echo
echo "Comandos: kernel_to_own.sh --sd $SD   |   kernel_to_stock.sh --sd $SD"
