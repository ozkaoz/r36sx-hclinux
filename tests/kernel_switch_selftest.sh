#!/usr/bin/env bash
# tests/kernel_switch_selftest.sh — Fase E: gate HOST PASS del kernel switcher (E1+E2+E3).
# Construye SDs FICTICIAS en tmp (jamás toca SDs reales: /mnt/g, /mnt/d, /mnt/c están
# fuera de alcance vía env KS_* overrides) y ejercita: instalación, restauración,
# rotación de snapshots, corrupción de backup (rechazo), golden adulterado (rechazo),
# layout boot/ y cubegm/, flujo --avp, idempotencia, --from-set y base default.
#
# Uso: ./tests/kernel_switch_selftest.sh   →  "HOST PASS" o lista de FAILs (rc 1)
set -uo pipefail

R="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d /tmp/ks-selftest.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0

ok()  { PASS=$((PASS+1)); echo "  PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }
check_eq() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 — esperado [$3], obtenido [$2]"; fi; }
check_rc() { if [ "$2" -eq "$3" ]; then ok "$1"; else bad "$1 — rc esperado $3, obtenido $2"; fi; }

h()      { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }
mkfile() { mkdir -p "$(dirname "$1")"; head -c "$2" /dev/urandom > "$1"; }

# --- entorno aislado: ninguna base/golden real alcanzable ---
export KS_OWN_BASE_DEFAULT="$TMP/no-own-base"
export KS_STOCK_BASE_DEFAULT="$TMP/no-stock-base"
export KS_STOCK_BASE_FALLBACK="$TMP/no-stock-base2"
export KS_GOLDEN_MANIFEST="$TMP/goldens/manifest.sha256"

# --- fixtures ---
mkdir -p "$TMP/goldens" "$TMP/sd-stock/cubegm" "$TMP/own-bundle" "$TMP/own-bundle2"
mkfile "$TMP/goldens/vmlinux.uImage" 65536
mkfile "$TMP/goldens/dtb.bin" 8192
mkfile "$TMP/goldens/avp.uImage" 32768
( cd "$TMP/goldens" && sha256sum vmlinux.uImage dtb.bin avp.uImage > manifest.sha256 )
cp "$TMP/goldens/vmlinux.uImage" "$TMP/sd-stock/cubegm/vmlinux.uImage"
cp "$TMP/goldens/dtb.bin"        "$TMP/sd-stock/cubegm/dtb.bin"
cp "$TMP/goldens/avp.uImage"     "$TMP/sd-stock/cubegm/avp.uImage"
mkfile "$TMP/sd-stock/cubegm/xgame-logo.bmp" 4096
mkfile "$TMP/own-bundle/vmlinux.uImage" 49152
mkfile "$TMP/own-bundle/dtb.bin" 7168
mkfile "$TMP/own-bundle2/vmlinux.uImage" 50176
mkfile "$TMP/own-bundle2/dtb.bin" 7424
mkfile "$TMP/own-avp.uImage" 33792

GS_K="$(h "$TMP/goldens/vmlinux.uImage")"; GS_D="$(h "$TMP/goldens/dtb.bin")"; GS_A="$(h "$TMP/goldens/avp.uImage")"
OB_K="$(h "$TMP/own-bundle/vmlinux.uImage")"; OB_D="$(h "$TMP/own-bundle/dtb.bin")"
OB2_K="$(h "$TMP/own-bundle2/vmlinux.uImage")"; OB2_D="$(h "$TMP/own-bundle2/dtb.bin")"
OAV="$(h "$TMP/own-avp.uImage")"

SD="$TMP/sd-stock"
TO_OWN="bash $R/scripts/kernel_to_own.sh"
TO_STOCK="bash $R/scripts/kernel_to_stock.sh"
STATUS="bash $R/scripts/kernel_switch_status.sh"

sets_count() { find "$1/kernel-switch/sets" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l; }
state_get()  { sed -n 's/^STATE=//p' "$1/kernel-switch/state" 2>/dev/null | tail -n1; }

echo "== T1: sintaxis (bash -n) =="
for f in kernel_switch_lib.sh kernel_to_own.sh kernel_to_stock.sh kernel_switch_status.sh; do
  if bash -n "$R/scripts/$f" 2>/dev/null; then ok "bash -n $f"; else bad "bash -n $f"; fi
done

echo "== T2: status inicial (layout cubegm, estado unknown) =="
OUT="$($STATUS --sd "$SD" 2>&1)"; RC=$?
check_rc "status rc" "$RC" 0
case "$OUT" in *"cubegm"*) ok "layout cubegm detectado" ;; *) bad "layout cubegm detectado" ;; esac
case "$OUT" in *"unknown"*) ok "estado inicial unknown" ;; *) bad "estado inicial unknown" ;; esac

echo "== T3: sin --sd muere =="
if $TO_OWN >/dev/null 2>&1; then bad "sin --sd debe morir"; else ok "sin --sd muere"; fi

echo "== T4: SD sin layout muere =="
mkdir -p "$TMP/sd-empty"
if $STATUS --sd "$TMP/sd-empty" >/dev/null 2>&1; then bad "SD sin layout debe morir"; else ok "SD sin layout muere"; fi

echo "== T5: to_own DRY-RUN no escribe =="
OUT="$($TO_OWN --sd "$SD" --bundle-dir "$TMP/own-bundle" --dry-run 2>&1)"; RC=$?
check_rc "dry-run rc" "$RC" 0
check_eq "kernel intacto tras dry-run" "$(h "$SD/cubegm/vmlinux.uImage")" "$GS_K"
if [ -d "$SD/kernel-switch" ]; then bad "dry-run no debe crear kernel-switch/"; else ok "dry-run no crea kernel-switch/"; fi

echo "== T6: to_own instala + orig backup + snapshot =="
OUT="$($TO_OWN --sd "$SD" --bundle-dir "$TMP/own-bundle" --yes 2>&1)"; RC=$?
check_rc "to_own rc" "$RC" 0
check_eq "kernel instalado" "$(h "$SD/cubegm/vmlinux.uImage")" "$OB_K"
check_eq "dtb instalado" "$(h "$SD/cubegm/dtb.bin")" "$OB_D"
check_eq "orig guarda kernel stock" "$(h "$SD/kernel-switch/orig/vmlinux.uImage")" "$GS_K"
check_eq "orig guarda dtb stock" "$(h "$SD/kernel-switch/orig/dtb.bin")" "$GS_D"
check_eq "estado own" "$(state_get "$SD")" "own"
check_eq "sets tras 1er switch" "$(sets_count "$SD")" "1"

echo "== T7: to_own idempotente =="
OUT="$($TO_OWN --sd "$SD" --bundle-dir "$TMP/own-bundle" --yes 2>&1)"; RC=$?
check_rc "idempotente rc" "$RC" 0
case "$OUT" in *"ya está instalado"*) ok "mensaje idempotente" ;; *) bad "mensaje idempotente" ;; esac
check_eq "sets sin crecimiento" "$(sets_count "$SD")" "1"

echo "== T8: manifest corrupto → to_stock RECHAZA y no toca la SD =="
cp "$SD/kernel-switch/orig/manifest.sha256" "$TMP/manifest.bak"
sed -i '1s/^./X/' "$SD/kernel-switch/orig/manifest.sha256"
if $TO_STOCK --sd "$SD" --yes >/dev/null 2>&1; then bad "manifest corrupto debe morir"; else ok "manifest corrupto muere"; fi
check_eq "kernel sigue propio tras rechazo" "$(h "$SD/cubegm/vmlinux.uImage")" "$OB_K"
cp "$TMP/manifest.bak" "$SD/kernel-switch/orig/manifest.sha256"

echo "== T8b: hash hex válido pero incorrecto → también RECHAZA =="
C1="$(head -c1 "$TMP/manifest.bak")"
if [ "$C1" = "1" ]; then R2="0"; else R2="1"; fi
sed -i "1s/^./$R2/" "$SD/kernel-switch/orig/manifest.sha256"
if $TO_STOCK --sd "$SD" --yes >/dev/null 2>&1; then bad "hash incorrecto debe morir"; else ok "hash incorrecto muere"; fi
check_eq "kernel sigue propio tras rechazo (hex válido)" "$(h "$SD/cubegm/vmlinux.uImage")" "$OB_K"
cp "$TMP/manifest.bak" "$SD/kernel-switch/orig/manifest.sha256"

echo "== T9: to_stock restaura el stock original =="
OUT="$($TO_STOCK --sd "$SD" --yes 2>&1)"; RC=$?
check_rc "to_stock rc" "$RC" 0
check_eq "kernel restaurado stock" "$(h "$SD/cubegm/vmlinux.uImage")" "$GS_K"
check_eq "dtb restaurado stock" "$(h "$SD/cubegm/dtb.bin")" "$GS_D"
check_eq "estado stock" "$(state_get "$SD")" "stock"

echo "== T10: rotación de sets (máx 3) y orig intacto =="
sleep 1.1
for i in 1 2 3; do
  if [ $((i % 2)) -eq 1 ]; then B="$TMP/own-bundle"; else B="$TMP/own-bundle2"; fi
  $TO_OWN --sd "$SD" --bundle-dir "$B" --yes >/dev/null 2>&1
  sleep 1.1
  $TO_STOCK --sd "$SD" --yes >/dev/null 2>&1
  sleep 1.1
done
CNT="$(sets_count "$SD")"
if [ "$CNT" -le 3 ]; then ok "rotación sets <= 3 ($CNT)"; else bad "rotación sets > 3 ($CNT)"; fi
check_eq "orig nunca rotado" "$(h "$SD/kernel-switch/orig/vmlinux.uImage")" "$GS_K"
check_eq "sd en stock tras ciclos" "$(h "$SD/cubegm/vmlinux.uImage")" "$GS_K"

echo "== T11: layout boot/ (SD con NOR propio) round-trip =="
SD2="$TMP/sd-own-nor"; mkdir -p "$SD2/boot"
mkfile "$SD2/boot/vmlinux.uImage" 40000
mkfile "$SD2/boot/dtb.bin" 6000
mkfile "$SD2/boot/avp.uImage" 30000
S2_K="$(h "$SD2/boot/vmlinux.uImage")"; S2_D="$(h "$SD2/boot/dtb.bin")"; S2_A="$(h "$SD2/boot/avp.uImage")"
OUT="$($TO_OWN --sd "$SD2" --bundle-dir "$TMP/own-bundle2" --yes 2>&1)"; RC=$?
check_rc "to_own boot/ rc" "$RC" 0
check_eq "kernel instalado boot/" "$(h "$SD2/boot/vmlinux.uImage")" "$OB2_K"
check_eq "avp intacto sin --avp" "$(h "$SD2/boot/avp.uImage")" "$S2_A"
OUT="$($TO_STOCK --sd "$SD2" --yes 2>&1)"; RC=$?
check_rc "to_stock boot/ rc" "$RC" 0
check_eq "kernel restaurado boot/" "$(h "$SD2/boot/vmlinux.uImage")" "$S2_K"
check_eq "dtb restaurado boot/" "$(h "$SD2/boot/dtb.bin")" "$S2_D"

echo "== T12: sin backup y sin golden disponible → muere =="
SD3="$TMP/sd-nobackup"; mkdir -p "$SD3/boot"
mkfile "$SD3/boot/vmlinux.uImage" 21000
mkfile "$SD3/boot/dtb.bin" 5100
mkfile "$SD3/boot/avp.uImage" 31000
if $TO_STOCK --sd "$SD3" --yes >/dev/null 2>&1; then bad "sin fuentes debe morir"; else ok "sin fuentes muere"; fi

echo "== T13: golden restore con --golden-dir (AVISO de fábrica + avp intacto) =="
S3_A="$(h "$SD3/boot/avp.uImage")"
OUT="$($TO_STOCK --sd "$SD3" --golden-dir "$TMP/goldens" --yes 2>&1)"; RC=$?
check_rc "golden restore rc" "$RC" 0
check_eq "kernel golden instalado" "$(h "$SD3/boot/vmlinux.uImage")" "$GS_K"
check_eq "dtb golden instalado" "$(h "$SD3/boot/dtb.bin")" "$GS_D"
check_eq "avp intacto sin --avp" "$(h "$SD3/boot/avp.uImage")" "$S3_A"
check_eq "estado stock" "$(state_get "$SD3")" "stock"
case "$OUT" in *"FÁBRICA"*) ok "aviso golden presente" ;; *) bad "aviso golden presente" ;; esac

echo "== T14: golden adulterado → RECHAZADO =="
mkdir -p "$TMP/bad-goldens"
mkfile "$TMP/bad-goldens/vmlinux.uImage" 21000
cp "$TMP/goldens/dtb.bin" "$TMP/bad-goldens/dtb.bin"
if $TO_STOCK --sd "$SD3" --golden-dir "$TMP/bad-goldens" --yes >/dev/null 2>&1; then
  bad "golden adulterado debe morir"
else
  ok "golden adulterado muere"
fi
check_eq "kernel no tocado tras rechazo" "$(h "$SD3/boot/vmlinux.uImage")" "$GS_K"

echo "== T15: flujo --avp (backup y restore del AVP) =="
SD4="$TMP/sd-avp"; mkdir -p "$SD4/cubegm"
cp "$TMP/goldens/vmlinux.uImage" "$SD4/cubegm/vmlinux.uImage"
cp "$TMP/goldens/dtb.bin" "$SD4/cubegm/dtb.bin"
cp "$TMP/goldens/avp.uImage" "$SD4/cubegm/avp.uImage"
$TO_OWN --sd "$SD4" --bundle-dir "$TMP/own-bundle" --avp "$TMP/own-avp.uImage" --yes >/dev/null 2>&1
check_eq "avp propio instalado" "$(h "$SD4/cubegm/avp.uImage")" "$OAV"
sleep 1.1
$TO_STOCK --sd "$SD4" --avp --yes >/dev/null 2>&1
check_eq "avp stock restaurado" "$(h "$SD4/cubegm/avp.uImage")" "$GS_A"
check_eq "kernel stock restaurado" "$(h "$SD4/cubegm/vmlinux.uImage")" "$GS_K"

echo "== T16: restore --from-set =="
sleep 1.1
$TO_OWN --sd "$SD4" --bundle-dir "$TMP/own-bundle2" --yes >/dev/null 2>&1
sleep 1.1
LASTSET="$(ls -1 "$SD4/kernel-switch/sets" | sort | tail -n1)"
$TO_STOCK --sd "$SD4" --from-set "$LASTSET" --yes >/dev/null 2>&1
check_eq "from-set restaura snapshot" "$(h "$SD4/cubegm/vmlinux.uImage")" "$GS_K"
check_eq "estado restored" "$(state_get "$SD4")" "restored"

echo "== T17: sin residuos .tmp =="
check_eq "archivos tmp residuales" "$(find "$TMP"/sd-* -name '*.tmp.*' 2>/dev/null | wc -l)" "0"

echo "== T18: fuente default KS_OWN_BASE_DEFAULT =="
SD5="$TMP/sd-defaultsrc"; mkdir -p "$SD5/cubegm"
cp "$TMP/goldens/vmlinux.uImage" "$SD5/cubegm/vmlinux.uImage"
cp "$TMP/goldens/dtb.bin" "$SD5/cubegm/dtb.bin"
mkdir -p "$TMP/own-base"
cp "$TMP/own-bundle/vmlinux.uImage" "$TMP/own-base/vmlinux.uImage"
cp "$TMP/own-bundle/dtb.bin" "$TMP/own-base/dtb.bin"
OUT="$(KS_OWN_BASE_DEFAULT="$TMP/own-base" $TO_OWN --sd "$SD5" --yes 2>&1)"; RC=$?
check_rc "to_own fuente default rc" "$RC" 0
check_eq "kernel instalado desde default" "$(h "$SD5/cubegm/vmlinux.uImage")" "$OB_K"

# ============ MODO CARPETA v2 (--folder — SO COMPLETO, SIN flash NOR) ============
# v2: boot/ SIEMPRE presente. to_stock --folder: par stock en boot/ + cubegm/ CREADA.
# to_own --folder: par propio en boot/ + cubegm/ ELIMINADA (backup). Nada de HCFOTA.
mkdir -p "$TMP/stockbase/cubegm/cores/bios" "$TMP/sdf/boot"
cp "$TMP/goldens/vmlinux.uImage" "$TMP/stockbase/cubegm/vmlinux.uImage"
cp "$TMP/goldens/dtb.bin" "$TMP/stockbase/cubegm/dtb.bin"
cp "$TMP/goldens/avp.uImage" "$TMP/stockbase/cubegm/avp.uImage"
mkfile "$TMP/stockbase/cubegm/xgame-logo.bmp" 4096
mkfile "$TMP/stockbase/cubegm/cores/bios/neogeo.zip" 2048
mkfile "$TMP/sdf/boot/vmlinux.uImage" 45000
mkfile "$TMP/sdf/boot/dtb.bin" 5500
mkfile "$TMP/sdf/boot/avp.uImage" 30500
mkfile "$TMP/sdf/boot/vmlinux.uImage.prev.bak" 44444
F_K="$(h "$TMP/sdf/boot/vmlinux.uImage")"; F_D="$(h "$TMP/sdf/boot/dtb.bin")"; F_B="$(h "$TMP/sdf/boot/vmlinux.uImage.prev.bak")"

echo "== TF1: to_stock --folder DRY-RUN no escribe =="
OUT="$($TO_STOCK --sd "$TMP/sdf" --folder --golden-dir "$TMP/stockbase/cubegm" --dry-run 2>&1)"; RC=$?
check_rc "dry-run folder rc" "$RC" 0
if [ -d "$TMP/sdf/cubegm" ]; then bad "dry-run folder no debe crear cubegm/"; else ok "dry-run folder no crea cubegm/"; fi
check_eq "boot/ intacta tras dry-run" "$(h "$TMP/sdf/boot/vmlinux.uImage")" "$F_K"

echo "== TF2: to_stock --folder — SO stock completo (boot/ presente + cubegm/ creada) =="
sleep 1.1
OUT="$($TO_STOCK --sd "$TMP/sdf" --folder --golden-dir "$TMP/stockbase/cubegm" --yes 2>&1)"; RC=$?
check_rc "to_stock --folder rc" "$RC" 0
if [ -d "$TMP/sdf/boot" ]; then ok "boot/ SIGUE presente (sin gap)"; else bad "boot/ SIGUE presente (sin gap)"; fi
check_eq "boot/ kernel == golden" "$(h "$TMP/sdf/boot/vmlinux.uImage")" "$GS_K"
check_eq "boot/ dtb == golden" "$(h "$TMP/sdf/boot/dtb.bin")" "$GS_D"
check_eq "boot/ .bak intacto" "$(h "$TMP/sdf/boot/vmlinux.uImage.prev.bak")" "$F_B"
if [ -d "$TMP/sdf/cubegm" ]; then ok "cubegm/ CREADA"; else bad "cubegm/ CREADA"; fi
check_eq "cubegm kernel == golden" "$(h "$TMP/sdf/cubegm/vmlinux.uImage")" "$GS_K"
if [ -f "$TMP/sdf/cubegm/cores/bios/neogeo.zip" ]; then ok "extras del sistema stock copiados"; else bad "extras del sistema stock copiados"; fi
check_eq "snapshot guarda nuestro par saliente" "$(h "$(find "$TMP/sdf/kernel-switch/sets" -mindepth 1 -maxdepth 1 -type d | sort | tail -n1)/vmlinux.uImage")" "$F_K"
if [ -d "$TMP/sdf/kernel-switch/orig" ]; then bad "to_stock no debe crear orig (es de to_own)"; else ok "orig solo lo crea to_own"; fi
check_eq "estado stock" "$(state_get "$TMP/sdf")" "stock"
check_eq "modo folder" "$(sed -n 's/^MODE=//p' "$TMP/sdf/kernel-switch/state")" "folder"
case "$OUT" in
  *"HCFOTA"*) bad "NO debe imprimir pasos HCFOTA (v2 sin NOR)" ;;
  *) ok "sin pasos HCFOTA (v2 sin NOR)" ;;
esac

echo "== TF2b: to_stock --folder idempotente =="
OUT="$($TO_STOCK --sd "$TMP/sdf" --folder --golden-dir "$TMP/stockbase/cubegm" --yes 2>&1)"; RC=$?
check_rc "idempotente folder rc" "$RC" 0
case "$OUT" in *"nada que hacer"*) ok "mensaje idempotente folder" ;; *) bad "mensaje idempotente folder" ;; esac

echo "== TF3: base cubegm adulterada → RECHAZA sin tocar boot/ =="
mkdir -p "$TMP/sdf2/boot" "$TMP/badbase/cubegm"
mkfile "$TMP/sdf2/boot/vmlinux.uImage" 41000
mkfile "$TMP/sdf2/boot/dtb.bin" 5100
mkfile "$TMP/badbase/cubegm/vmlinux.uImage" 41000
cp "$TMP/goldens/dtb.bin" "$TMP/badbase/cubegm/dtb.bin"
S2K="$(h "$TMP/sdf2/boot/vmlinux.uImage")"
if $TO_STOCK --sd "$TMP/sdf2" --folder --golden-dir "$TMP/badbase/cubegm" --yes >/dev/null 2>&1; then
  bad "base cubegm adulterada debe morir"
else
  ok "base cubegm adulterada muere"
fi
check_eq "boot/ intacta tras rechazo" "$(h "$TMP/sdf2/boot/vmlinux.uImage")" "$S2K"
if [ -d "$TMP/sdf2/cubegm" ]; then bad "no debe crear cubegm/ tras rechazo"; else ok "cubegm/ no creada tras rechazo"; fi

echo "== TF4: to_own --folder — par propio + cubegm/ ELIMINADA =="
sleep 1.1
OUT="$($TO_OWN --sd "$TMP/sdf" --folder --bundle-dir "$TMP/own-bundle" --yes 2>&1)"; RC=$?
check_rc "to_own --folder rc" "$RC" 0
if [ -d "$TMP/sdf/boot" ]; then ok "boot/ SIGUE presente"; else bad "boot/ SIGUE presente"; fi
check_eq "kernel propio restaurado" "$(h "$TMP/sdf/boot/vmlinux.uImage")" "$OB_K"
check_eq "dtb propio restaurado" "$(h "$TMP/sdf/boot/dtb.bin")" "$OB_D"
check_eq ".bak intacto" "$(h "$TMP/sdf/boot/vmlinux.uImage.prev.bak")" "$F_B"
if [ -d "$TMP/sdf/cubegm" ]; then bad "cubegm/ debe ELIMINARSE (backup)"; else ok "cubegm/ ELIMINADA"; fi
CBD="$(find "$TMP/sdf/kernel-switch/folders" -mindepth 1 -maxdepth 1 -type d -name 'cubegm-stock-*' | tail -n1)"
if [ -f "$CBD.manifest.sha256" ] && ( cd "$CBD" && sha256sum -c "$CBD.manifest.sha256" ) >/dev/null 2>&1; then
  ok "backup cubegm verifica"
else
  bad "backup cubegm verifica"
fi
check_eq "estado own" "$(state_get "$TMP/sdf")" "own"
check_eq "modo folder (own)" "$(sed -n 's/^MODE=//p' "$TMP/sdf/kernel-switch/state")" "folder"
case "$OUT" in
  *"HCFOTA"*) bad "NO debe imprimir pasos HCFOTA (v2 sin NOR)" ;;
  *) ok "sin pasos HCFOTA (to_own v2)" ;;
esac

echo "== TF5: to_own --folder sin cubegm/ presente → solo par =="
mkdir -p "$TMP/sdf5/boot"
mkfile "$TMP/sdf5/boot/vmlinux.uImage" 43000
mkfile "$TMP/sdf5/boot/dtb.bin" 5300
mkfile "$TMP/sdf5/boot/avp.uImage" 30300
OUT="$($TO_OWN --sd "$TMP/sdf5" --folder --bundle-dir "$TMP/own-bundle2" --yes 2>&1)"; RC=$?
check_rc "to_own --folder sin cubegm rc" "$RC" 0
check_eq "par propio instalado" "$(h "$TMP/sdf5/boot/vmlinux.uImage")" "$OB2_K"
check_eq "modo folder (sdf5)" "$(sed -n 's/^MODE=//p' "$TMP/sdf5/kernel-switch/state")" "folder"

echo
echo "=== RESULTADO: PASS=$PASS FAIL=$FAIL ==="
if [ "$FAIL" -eq 0 ]; then
  echo "HOST PASS — Fase E kernel switcher (E1+E2+E3) funcional completo en SDs de prueba"
  exit 0
fi
exit 1
