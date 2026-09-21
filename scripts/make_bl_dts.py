#!/usr/bin/env python3
"""
make_bl_dts.py (Fase D-2b fix-forward) — Genera r36sx-v26.dts con el nodo
/hcrtos/ del NOR-DTB de FÁBRICA (no del DTS de la SD).

El DTS de la SD (stock-normalized) tiene un /hcrtos/ con panel-init-sequence
LARGA que el bootloader no soporta. El NOR-DTB de fábrica tiene la secuencia
CORTA correcta. Este script:
  1. Lee stock-normalized.dts (base con nodos Linux)
  2. Extrae el /hcrtos/ del NOR-DTB de fábrica
  3. Aplica los CAMBIOS DELIBERADOS: path-prefix "cubegm"→"boot" +
     hcfota-upgrade con SELECT como tecla
  4. Reemplaza el /hcrtos/ del stock con el de fábrica (corregido)
  5. Escribe r36sv26.dts
"""
import re
import sys
import os
import subprocess

REPO = os.path.expanduser("~/projects/r36sx-hclinux")
NOR_DTB = "/mnt/d/R36SX/nor-dump-20260919/factory-nordtb-0.dtb"
STOCK_DTS = os.path.join(REPO, "boards/r36sx-v26/reference/stock-normalized.dts")
OUT_DTS = os.path.join(REPO, "boards/r36sx-v26/dts/r36sx-v26.dts")

# SELECT key en Linux input event codes: BTN_SELECT = 0x161 = 353
SELECT_KEY = 0x161

def main():
    # decompile factory NOR-DTB
    result = subprocess.run(
        ["dtc", "-I", "dtb", "-O", "dts", "-s", NOR_DTB],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"ERROR dtc: {result.stderr}")
        sys.exit(1)
    factory_dts = result.stdout

    # extraer el nodo /hcrtos/ del factory
    m = re.search(r'(\thcrtos \{.*?\n\t\};)', factory_dts, re.DOTALL)
    if not m:
        print("ERROR: /hcrtos/ no encontrado en factory NOR-DTB")
        sys.exit(1)
    factory_hcrtos = m.group(1)

    # CAMBIO 1: path-prefix "cubegm" -> "boot"
    if 'path-prefix = "cubegm";' not in factory_hcrtos:
        print("ERROR: path-prefix no encontrado en factory /hcrtos/")
        sys.exit(1)
    factory_hcrtos = factory_hcrtos.replace(
        'path-prefix = "cubegm";',
        'path-prefix = "boot";'
    )

    # CAMBIO 2: añadir hcfota-upgrade con SELECT
    # INSERTAR antes del último "};\n\t};" del nodo hcrtos
    upgrade = f"""\t\thcfota-upgrade {{
\t\t\tstatus = "okay";
\t\t\tkey = <0x{SELECT_KEY:x}>;
\t\t}};
"""
    # buscar el cierre del nodo hcrtos (el último \t};)
    lines = factory_hcrtos.split('\n')
    for i in range(len(lines) - 1, -1, -1):
        if lines[i].strip() == '};':
            # insertar antes del cierre
            lines.insert(i, upgrade.rstrip())
            break
    factory_hcrtos = '\n'.join(lines)

    # leer el stock DTS
    with open(STOCK_DTS) as f:
        stock = f.read()

    # extraer el /hcrtos/ del stock
    m2 = re.search(r'(\thcrtos \{.*?\n\t\};)', stock, re.DOTALL)
    if not m2:
        print("ERROR: /hcrtos/ no encontrado en stock-normalized")
        sys.exit(1)

    # reemplazar el /hcrtos/ del stock con el de factory (corregido)
    result_dts = stock.replace(m2.group(1), factory_hcrtos)

    # escribir el DTS final
    with open(OUT_DTS, 'w') as f:
        f.write(result_dts)

    print(f"DTS generado: {OUT_DTS}")
    print(f"  Líneas: {result_dts.count(chr(10))}")
    print(f"  /hcrtos/ de FÁBRICA con: path-prefix=boot + hcfota-upgrade(key=0x{SELECT_KEY:x}=SELECT)")

    # verificación
    for kw in ['path-prefix = "boot"', 'hcfota-upgrade', 'key = <0x161>']:
        if kw in result_dts:
            print(f"  ✓ {kw}")
        else:
            print(f"  ✗ FALTA: {kw}")
            sys.exit(1)

    # verificar que panel-init-sequence es la de fábrica (CORTA, empieza con 0x15c80211)
    if '0x15c80211' in result_dts:
        print("  ✓ panel-init-sequence = FÁBRICA (CORTA)")
    else:
        print("  ✗ panel-init-sequence NO es de fábrica!")
        sys.exit(1)

    print("\nGATE SEMÁNTICO será verificado por compare_dtb_semantics.sh tras el build")

if __name__ == "__main__":
    main()
