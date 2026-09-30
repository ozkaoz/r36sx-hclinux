#!/usr/bin/env bash
# kernel_to_own.sh — Fase E1: instalar NUESTRO kernel+DTB en la SD (consola stock o propia).
#
# El bootloader de la consola determina de dónde lee el kernel:
#   - bootloader stock (fábrica):              <sd>/cubegm/   → SIN flash
#   - bootloader propio (NOR fábrica+7B, Fase D): <sd>/boot/
# Este script detecta el layout y escribe ahí. NUNCA toca NOR/bootloader (para eso: E4,
# kits HCProgrammer probados). Backup automático + SHA256 + camino de vuelta garantizado
# (kernel_to_stock.sh restaura desde kernel-switch/orig — regla de simetría Fase E).
#
# Uso:
#   ./scripts/kernel_to_own.sh --sd /mnt/g [fuente] [--avp FILE] [--dry-run] [--yes]
# Fuente del kernel propio (prioridad):
#   --kernel FILE --dtb FILE   explícitos
#   --bundle-dir DIR           dir con vmlinux.uImage + dtb.bin (artefacto distribuido)
#   --from-build TAG           ~/work/r36sx-hclinux/build/TAG/images/
#   (default)                  base propia canónica (KS_OWN_BASE_DEFAULT = SD viva /mnt/g/boot)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/kernel_switch_lib.sh"

usage() {
  cat <<'EOF'
Uso: kernel_to_own.sh --sd <ruta SD> [fuente] [--avp FILE] [--dry-run] [--yes]
Fuente (prioridad): --kernel/--dtb · --bundle-dir DIR · --from-build TAG · base propia canónica (default)
EOF
}

SD=""; KERNEL=""; DTB=""; BUNDLE=""; BUILD=""; AVP=""; AVP_FLAG=0
KS_YES=0; KS_DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --sd) SD="${2:?falta ruta}"; shift 2 ;;
    --kernel) KERNEL="${2:?falta ruta}"; shift 2 ;;
    --dtb) DTB="${2:?falta ruta}"; shift 2 ;;
    --bundle-dir) BUNDLE="${2:?falta dir}"; shift 2 ;;
    --from-build) BUILD="${2:?falta tag}"; shift 2 ;;
    --avp) AVP="${2:?falta ruta}"; AVP_FLAG=1; shift 2 ;;
    --dry-run) KS_DRY_RUN=1; shift ;;
    --yes) KS_YES=1; shift ;;
    -h|--help) sed -n '2,18p' "$0"; echo; usage; exit 0 ;;
    *) echo "ERROR: argumento desconocido: $1" >&2; usage >&2; exit 1 ;;
  esac
done

SD="$(ks_require_sd "${SD:-}")"
KS_LAYOUT="$(ks_detect_layout "$SD")"
WORK="$HOME/work/r36sx-hclinux"

# --- resolver fuente ---
if [ -n "$KERNEL" ] || [ -n "$DTB" ]; then
  if [ -z "$KERNEL" ] || [ -z "$DTB" ]; then ks_die "--kernel y --dtb van juntos"; fi
elif [ -n "$BUNDLE" ]; then
  KERNEL="$BUNDLE/vmlinux.uImage"; DTB="$BUNDLE/dtb.bin"
elif [ -n "$BUILD" ]; then
  KERNEL="$WORK/build/$BUILD/images/vmlinux.uImage"; DTB="$WORK/build/$BUILD/images/dtb.bin"
elif [ -f "$KS_OWN_BASE_DEFAULT/vmlinux.uImage" ] && [ -f "$KS_OWN_BASE_DEFAULT/dtb.bin" ]; then
  KERNEL="$KS_OWN_BASE_DEFAULT/vmlinux.uImage"; DTB="$KS_OWN_BASE_DEFAULT/dtb.bin"
  ks_log "fuente: base propia canónica ($KS_OWN_BASE_DEFAULT)"
else
  ks_die "sin fuente: usa --bundle-dir, --from-build o --kernel/--dtb (base default $KS_OWN_BASE_DEFAULT no disponible)"
fi
if [ ! -f "$KERNEL" ]; then ks_die "kernel fuente inexistente: $KERNEL"; fi
if [ ! -f "$DTB" ]; then ks_die "DTB fuente inexistente: $DTB"; fi
if [ "$AVP_FLAG" = "1" ] && [ ! -f "$AVP" ]; then ks_die "--avp: inexistente: $AVP"; fi

HK="$(ks_sha256 "$KERNEL")"; HD="$(ks_sha256 "$DTB")"

ks_show_info "$SD" "$KS_LAYOUT"
echo "kernel propio a instalar: ${HK:0:8}  ($KERNEL)"
echo "DTB propio a instalar:    ${HD:0:8}  ($DTB)"
if [ "$AVP_FLAG" = "1" ]; then
  HAV="$(ks_sha256 "$AVP")"
  echo "AVP a instalar:           ${HAV:0:8}  ($AVP)"
fi

if [ "$(ks_sha256 "$SD/$KS_LAYOUT/vmlinux.uImage")" = "$HK" ] \
   && [ "$(ks_sha256 "$SD/$KS_LAYOUT/dtb.bin")" = "$HD" ]; then
  echo "El kernel propio ya está instalado (hashes idénticos) — nada que hacer."
  exit 0
fi

echo "Plan: reemplazar vmlinux.uImage + dtb.bin en $SD/$KS_LAYOUT/ (backup automático previo)"
if [ "$KS_DRY_RUN" = "1" ]; then
  echo "DRY-RUN: no se escribe nada."
  exit 0
fi
ks_confirm "¿Instalar el kernel propio en $SD ($KS_LAYOUT/)?"

ORIG="$(ks_state_dir "$SD")/orig"
if [ ! -d "$ORIG" ]; then
  ks_backup_pair "$SD" "$KS_LAYOUT" "$ORIG" "$AVP_FLAG"
  ks_log "backup ORIGINAL (recovery point del primer uso): kernel-switch/orig/"
fi
ks_snapshot_current "$SD" "$KS_LAYOUT" "$AVP_FLAG"
ks_install_file "$KERNEL" "$SD/$KS_LAYOUT/vmlinux.uImage"
ks_install_file "$DTB" "$SD/$KS_LAYOUT/dtb.bin"
if [ "$AVP_FLAG" = "1" ]; then
  ks_install_file "$AVP" "$SD/$KS_LAYOUT/avp.uImage"
fi

# post-verificación
if [ "$(ks_sha256 "$SD/$KS_LAYOUT/vmlinux.uImage")" != "$HK" ]; then ks_die "post-verify kernel FAIL"; fi
if [ "$(ks_sha256 "$SD/$KS_LAYOUT/dtb.bin")" != "$HD" ]; then ks_die "post-verify DTB FAIL"; fi
ks_state_write "$SD" own
echo
echo "OK — kernel propio instalado en $SD/$KS_LAYOUT/ (post-verify SHA256 PASS)."
echo "Vuelta al estado anterior: ./scripts/kernel_to_stock.sh --sd $SD"
