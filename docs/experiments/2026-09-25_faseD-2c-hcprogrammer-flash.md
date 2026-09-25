# Fase D-2c (reinicio 2026-09-25): flash del bootloader propio vía HCProgrammer

**Estado:** PRE-FLASH COMPLETO. Pendiente: flash físico + boot-1 del usuario.

## Kit de flasheo (nuevo): `D:\R36SX\hcprogrammer-own-kit\`

- `hcprog.ini` (mismo formato del kit de restauración, VERSION 2609250000)
- `bootloader.bin` = **NUESTRO** staging `bootloader-r36sx-v26-faseD2b.bin`
  (sha `1734c340…`, 442.368 B) — verificado en esta sesión:
  - DDR-init de fábrica byte-exacto (`d944d9af…`) → **ventana BootROM-USB
    activa en cada encendido** (~300 ms, portA/B=1 del DDR-init de fábrica)
    → recovery sin abrir la consola.
  - Payload LZMA @0x5e48 descomprimido → **NOR-DTB embebido con
    `path-prefix="boot"`** (fdtget verificado en ambos staging; el
    `-fix.bin` 279d6db3 también lo lleva — el 1734c340 es el validado en
    la documentación 9a).
  - Strings `cubegm` presentes = dual-path fallback del patch 0001
    (`/media/%s/cubegm/%s`) ✓ correcto.
- `ddrinit.abs` (fábrica), `hc16xx_jtag_updater.bin`, `romfs.img`,
  `persistentmem.bin` (bytes del dump), `driver/`, HCProgrammer exes.

## SD (preparada): `/boot/` con los 4 archivos byte-exacto (MATCH sha):

`dtb.bin` (116ddf26) · `avp.uImage` (a9788995 golden) · `vmlinux.uImage`
(e45547a2 — kernel stable con loader-fix) · `xgame-logo.bmp`. `cubegm/`
INTACTO (fallback dual-path → primer boot inbrickeable por diseño).

## Protocolo de flasheo (usuario)

1. SD en la consola (con `/boot/` ya presente). Consola APAGADA, cable USB-C al PC.
2. PC: `HCProgrammer.exe` **como administrador** → cargar proyecto
   `hcprog.ini` del kit-own → dejar en escucha.
3. ENCENDER la consola → BootROM-USB (~300 ms; reintentar 3-5× si no pilla).
4. Flashear (boot=NUESTRO; eromfs/persistentmem re-escriben bytes idénticos).
5. Reboot → **bootloader propio** → `/boot/` → menú esperado (contenido
   idéntico → boot visualmente normal).

## Rollback (si el boot propio falla)

Repetir el flujo con el kit de restauración
(`D:\R36SX\hcprogrammer-restore-kit\hcprog.ini` = bootloader de FÁBRICA).
La ventana BootROM-USB sigue activa (DDR-init del NOR = fábrica, nuestro
staging lo incluye byte-exacto). SIN abrir la consola.

## Después del boot-1 PASS

- **boot-2**: swap de dtb/kernel propios en `/boot/` (validar cada uno).
- **boot-3**: eliminar `cubegm/` al 100% → objetivo original de Fase D cumplido.
- Prueba discriminante opcional de quién bootea: logo distinto SOLO en `/boot/`.

---

# ADDENDUM: HCFOTA-own.bin construido a mano (formato decodificado del SDK)

El HCProgrammer rechaza ini con archivos sueltos ("no updater/ddrinfo found
in firmware") — espera un FIRMWARE HCFOTA empaquetado. El generator.exe del
SDK es inoperable por CLI (cuelga), así que se decodificó el formato del
source (`SOURCE/hcfota/hcfota.{c,h}`) y se construyó el paquete propio:

- **Formato**: header 64B (crc, compress_type=0/SIN compresión, version,
  board, flags de flash) + payload-header 1024B (crc + 6 entries de 32B)
  + data (ddrinit 12.288 @0x440 · updater 450.488 · **boot 442.368
  @0x713f8** · eromfs 16.384 · persistent 65.536 · meta 496).
- **CRC header** = crc32(header con crc=0) + crc32(payload completo) —
  fórmula de `hcfota_check()`, **validada contra el factory** (reprodujo
  0x87182d2c exacto).
- **CRC payload-header** = crc32(payload[64:] con ph.crc=0) — reproducido
  0xddedec1f del factory.
- **Construcción**: byte-clon del factory-restore con SOLO la sección boot
  sustituida por el staging `1734c340` (442.368 B exactos) + version
  2609250001 + ambos CRC recalculados.
- **Resultado**: `D:\R36SX\hcprogrammer-own-kit\HCFOTA-own.bin`
  (988.648 B, sha `495ff9be…`, re-check CRC PASS, boot embebido verificado).
- Nota: el usuario flasheará "Firmware select" = HCFOTA-own.bin con el
  mismo flujo probado del 21-09 (HCProgram.exe + HCProgrammer.exe ambos
  abiertos como admin; BootROM-USB en el encendido; fallback corto 2/4).
