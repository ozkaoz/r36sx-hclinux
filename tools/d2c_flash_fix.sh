#!/bin/sh
# d2c_flash_fix.sh (Fase D-2b fix-forward) — flash del bootloader CORREGIDO.
# GATE PASADO: /hcrtos/ == FÁBRICA (excepto path-prefix=boot + hcfota-upgrade/SELECT).
# DUAL-PATH: si /boot/ no existe, cae automáticamente a cubegm/ → boot seguro.
IMG=/mnt/sdcard/bootloader-faseD2b-fix.bin
EXPECTED=279d6db36c35e87cd417a2d21a12b01e107838db1023da6f048bae5755f36c9f
echo "1) sha256 de la imagen:"
echo "$EXPECTED  $IMG" | sha256sum -c - || { echo "IMAGEN NO COINCIDE — ABORT"; exit 1; }
echo "2) mtdnor accesible?:"
[ -x /mnt/sdcard/mtdnor ] && echo "   OK" || { echo "   FALTA — ABORT"; exit 1; }
echo "3) FLASH erase+write+verify (~2 min — NO apagar):"
/mnt/sdcard/mtdnor /dev/mtd1 "$IMG" || { echo "FALLO — NO reboot"; exit 1; }
echo
echo "FLASH COMPLETO. Reboot:"
echo "  - El bootloader nuevo prefiere /boot/ (no existe aun)"
echo "  - DUAL-PATH: cae a cubegm/ → arranca NORMAL desde cubegm/"
echo "  → La consola debe botear IDÉNTICA (mismo layout cubegm/)"
