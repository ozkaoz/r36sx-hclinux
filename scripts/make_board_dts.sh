#!/usr/bin/env bash
# make_board_dts.sh (fix-forward D-2b) — Genera r36sx-v26.dts con /hcrtos/ de FÁBRICA.
# FLUJO: make_bl_dts.py genera el cuerpo → este script añade macros → valida.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="$REPO/boards/r36sx-v26/dts/r36sx-v26.dts"

echo "=== make_board_dts (fix-forward: /hcrtos/ de FÁBRICA) ==="

# 1. generar el cuerpo (factory /hcrtos/ + Linux nodes + path-prefix=boot + hcfota-upgrade)
python3 "$REPO/scripts/make_bl_dts.py" > /dev/null
echo "cuerpo generado: $(wc -l < "$OUT") líneas"

# 1b. Fase 9-6e FIX (2026-09-24): desactivar monitoreo USB del AVP para usb0.
# El AVP firmware monitorea el USB controller 0 (0x18844000) via su nodo /hcrtos/usb0.
# Cuando detecta un gadget CDC-NETWORK (NCM/RNDIS) en modo peripheral, aplica un
# overlay azul al display (patron uniforme 06f2 en el fb). Este es comportamiento
# del firmware AVP — no del kernel Linux. Al poner status="disabled" en el nodo usb0
# del /hcrtos/, el AVP no monitorea este controlador y no detecta el gadget networking.
# El gate de /hcrtos/ permite cambios en "status" (allowlist).
# EVIDENCIA: ACM (no networking) = sin azul; NCM/RNDIS (networking) = azul;
# amprpc sin display commands durante azul; GE reset sin efecto; fb keepalive sin efecto.
sed -i '/usb0 {/,/};/{s/status = "okay";/status = "disabled";/}' "$OUT"
echo "fase9-6e: AVP usb0 monitoring disabled (gadget NCM sin overlay azul)"

# 2. añadir macros del hook SDK (necesarias para el entry addr del bootloader)
TMP="$OUT.tmp"
cat > "$TMP" << 'HDR'
/* r36sx-v26.dts — /hcrtos/ del NOR-DTB de FÁBRICA (fix-forward D-2b) */
#define CONFIG_MEMORY_SIZE 0x10000000
#define CONFIG_LINUX_MEMORY_SIZE 0xAF91E50
#define CONFIG_LINUX_MEMORY_OFFSET 0x0
#define CONFIG_FRAMEBUFFER_STATIC_PHYS (CONFIG_LINUX_MEMORY_OFFSET + CONFIG_LINUX_MEMORY_SIZE)
#define HCRTOS_SYSMEM_SIZE 0xB53600
#define HCRTOS_SYSMEM_OFFSET 0xBDA2E50
#define HCRTOS_BOOTMEM_SIZE 0x2000000
#define HCRTOS_BOOTMEM_OFFSET (((HCRTOS_SYSMEM_OFFSET < 0xc000000 ? HCRTOS_SYSMEM_OFFSET : 0xc000000) - HCRTOS_BOOTMEM_SIZE) & 0xffff0000)

HDR
cat "$OUT" >> "$TMP"
mv "$TMP" "$OUT"
echo "macros añadidas: $(wc -l < "$OUT") líneas"

# 3. validar con el pipeline de Buildroot: cpp → dtc
TMPD=$(mktemp -d)
gcc -E -nostdinc -undef -D__DTS__ -x assembler-with-cpp -o "$TMPD/pp.dts" "$OUT" 2>/dev/null
dtc -I dts -O dtb -o "$TMPD/test.dtb" "$TMPD/pp.dts" 2>"$TMPD/dtc.err" \
  || { echo "DTC FAIL:"; head -5 "$TMPD/dtc.err"; exit 1; }
echo "gcc -E + dtc: OK ($(stat -c%s "$TMPD/test.dtb") bytes)"

# 4. GATE: /hcrtos/ compilado vs factory NOR-DTB
dtc -I dtb -O dts -s -o "$TMPD/test.dts" "$TMPD/test.dtb" 2>/dev/null
dtc -I dtb -O dts -s -o "$TMPD/factory.dts" /mnt/d/R36SX/nor-dump-20260919/factory-nordtb-0.dtb 2>/dev/null

python3 - "$TMPD/test.dts" "$TMPD/factory.dts" << 'PYEOF'
import re, sys

def hcrtos(path):
    with open(path) as f:
        c = f.read()
    m = re.search(r'(\thcrtos \{.*?\n\t\};)', c, re.DOTALL)
    return m.group(1) if m else ""

test = hcrtos(sys.argv[1])
factory = hcrtos(sys.argv[2])

test_set = set(l.strip() for l in test.split('\n') if l.strip())
fact_set = set(l.strip() for l in factory.split('\n') if l.strip())

unexpected = []
for l in test_set - fact_set:
    if any(k in l for k in ['path-prefix', 'hcfota-upgrade', 'key', 'status', 'boot']):
        continue
    unexpected.append(l)
for l in fact_set - test_set:
    if any(k in l for k in ['path-prefix', 'hcfota-upgrade', 'key']):
        continue
    unexpected.append(l)

if unexpected:
    print(f"GATE NOR-DTB: FAIL — {len(unexpected)} diferencias inesperadas:")
    for d in sorted(unexpected)[:10]:
        print(f"  {d}")
    sys.exit(1)
else:
    print("GATE NOR-DTB: PASS — /hcrtos/ == fábrica (excepto cambios deliberados)")
PYEOF

echo "=== make_board_dts DONE ==="
