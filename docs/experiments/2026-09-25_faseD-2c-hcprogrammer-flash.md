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
