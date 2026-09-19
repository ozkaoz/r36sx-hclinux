# Experimento 2026-09-19 — cubegm/ al mínimo: investigación de la cadena pre-Linux y el contrato NOR de boot

# Objective

Determinar si `cubegm/` puede eliminarse por completo de la SD (decisión del usuario) y ejecutar el mínimo alcanzable.

# Evidence (investigación completa — SDK, código del bootloader, DTS stock, binario AVP)

**1. El path `cubegm/` NO está hardcodeado en el bootloader** — es una propiedad del DTB:
- `SOURCE/avp/components/applications/apps-bootloader/source/main.c`: `get_block_devpath()` → `fdt_get_node_offset_by_path("/hcrtos/external_files")` → lee `path-prefix` + `part%d-filename`/`part%d-label` del DTB ACTIVO del HCRTOS (`fdt_api.c:261` — puntero global `fdtp`).
- DTS stock (`reference/stock-normalized.dts:178-189`): `external_files { part-num=<4>; part1=dtb.bin/dtb; part2=avp.uImage/avp; part3=vmlinux.uImage/linux; part4=xgame-logo.bmp/logo; path-prefix="cubegm"; }` — **única referencia a cubegm en todo el DTS**.

**2. Secuencia de boot (`bootup_hclinux_dualcore`, main.c:600-655):** registro 0xb8800004 → buffer DTB; carga `cubegm/dtb.bin` (mtdloadraw) → `sysdata_update_dt()`; carga `avp.uImage` → bootm AVP; carga `vmlinux.uImage` → `bootm(loadaddr, "-", dtbaddr)` Linux.

**3. El pinning:** el `fdtp` que usa el bootloader para buscar los archivos es el DTB de SU HCRTOS — **embebido en NOR** (hornero de fábrica con `path-prefix="cubegm"`). El `dtb.bin` de la SD se pasa al AVP y al kernel, pero NO re-polariza las búsquedas del bootloader. → **Los 4 archivos {dtb.bin, avp.uImage, vmlinux.uImage, xgame-logo.bmp} están anclados a `cubegm/` por NOR** — inamovibles desde la SD.

**4. El AVP de fábrica NO hardcodea cubegm** (strings del binario: 0 matches setting.xml/cubegm/xgame/allfiles/root.dat). `setting.xml`/`allfiles.lst`/`root.dat` eran configs del MENÚ DE FÁBRICA (rkgame/MyExecutable — fuera de nuestro boot desde 8d). El culpable del fail de la primera instalación limpia era casi con certeza **`xgame-logo.bmp` (part4 del bootloader)** — el único de los 4 sospechosos que el bootloader carga.

# Result (análisis)

| Objetivo | Veredicto |
|---|---|
| **cubegm 100% eliminado** | Solo posible reemplazando el bootloader de NOR (fuente + toolchain disponibles desde 9a — ADR-008 cayó), horneando un NOR-DTB con otro `path-prefix`. **Zona prohibida (§5): flashear NOR = riesgo de brick sin dump de NOR para rollback.** No recomendado; requiere autorización explícita + plan de recuperación BootROM/HCPROGRAMMER validado. |
| **cubegm mínimo sin tocar NOR** | **4 archivos (3,9 MB): dtb.bin, avp.uImage, vmlinux.uImage, xgame-logo.bmp** — el "contrato NOR de boot" (análogo al DDR-init: hardware, no software eliminable). Todo lo demás fuera. |

# Files changed (iteración)

- SD: eliminados `cubegm/{setting.xml, allfiles.lst, root.dat}` (solo-fábrica-menú). cubegm = 4 boot + 2 goldens + flag diag (+ logs regenerables).
- Sin cambios de kernel/build — test puro de layout.

# Tests

- **PHYSICAL: PENDIENTE (usuario)** — boot con cubegm = contrato de 4. PASS → confirma: el culpable del fail original era `xgame-logo.bmp` (bootloader part4) y cubegm llegó a su mínimo NOR. FAIL → restaurar (desde backup tar) el archivo necesario — cubegm sería de 5.

# Decision (pendiente del test)

- Con PASS: cubegm/ queda definido como **contrato de boot de NOR** — documentado en TREEFROG_UI_CONTRACT + BOOT_CHAIN como pieza de hardware (junto a DDR-init/bootloader). La eliminación 100% queda archivada como opción Class D (bootloader propio + reflash NOR) — no activa.
- Tras el cierre: Fase 7 (directiva del usuario).

# Next action

Usuario: boot de la consola. PASS → cerrar caso cubegm + Fase 7. FAIL → traer SD, restaurar el archivo culpable del tar, cerrar en 5.

---

## Addendum 1 — PHYSICAL PASS + decisión del usuario: intentar la eliminación 100% (2026-09-19)

**TEST PASS (usuario):** boot con cubegm = contrato de 4 → todo OK. **Confirma**: el culpable del fail de la instalación limpia era `xgame-logo.bmp` (part4 del bootloader, `external_files`); `setting.xml`/`allfiles.lst`/`root.dat` eran solo-fábrica-menú y fueron eliminados sin efecto. **cubegm/ queda en su mínimo NOR: 4 archivos de boot (dtb.bin, avp.uImage, vmlinux.uImage, xgame-logo.bmp) + goldens + flag.**

**Decisión del usuario: intentar la eliminación 100%** ("Intentémoslo"). Eso exige reemplazar el bootloader de NOR. Plan de Clase D con red de seguridad completa:

### Fase D-1 — dump del NOR (SIN RIESGO, lee solo mtd*ro)
Evidencia que lo habilita: kernel propio con `CONFIG_MTD=y`+`MTD_M25P80` (SPI-NOR), DTS `spi@1882e000` ("hichip,hc16xx-spi-sf"), y `/dev/mtd0..3(+ro)` VIVOS en la consola (evidence-diag6x). NOR total 16 MB (manual §3525). **`scripts/nor_dump.sh` desplegado a `G:\nor-dump.sh`** (`77678eb0`) — ejecutar desde FrogShell: `sh /mnt/sdcard/nor-dump.sh` → dump bit-a-bit de las 4 particiones + /proc/mtd + hashes → rollback EXACTO de fábrica + extracción del DDR-init de fábrica (12.288 B) y del NOR-DTB (confirmar external_files/path-prefix en el binario real).

### Fase D-2 — build de nuestro hcboot (SIN RIESGO)
Manual OPENCODE §12/§14: `mkboot`/`make hcboot-menuconfig` (defconfig `hichip_hc16xx_linux_bl_defconfig`); bootloader.bin = DDR-init + u-boot.bin (post-build genera). Nuestro build: DDR-init **byte-exacto de fábrica (del dump)** + hcboot con NOR-DTB `path-prefix="boot"`. Gate: comparar strings/símbolos contra el bootloader de fábrica del dump (mismo método que validó avp-own en 9a).

---

## Addendum 3 — D-2a investigación completa + PIVOTE DE PLAN (2026-09-19/20)

**Formato HCFOTA descifrado** (generator + hcfota.h + upgrade.c): `hcfota_header` (crc/compress/version/board/product/flags de storage) + payload (DTB embebido + entries por partición con offset/length/erase_length) + CRC32; `-u`=sin-boot, `-r`=DDR-init, `-c`=versioncheck; el hcboot busca **`HCFOTA.bin` en la RAÍZ del medio**; trigger = `sysdata.ota_detect_modes` en persistentmem (modo SD=3); one-shot (limpia el flag tras intentar).

**Bootloader de fábrica DESCOMPRIMIDO del dump** (LZMA @0x5e48, tamaño exacto 0x10cebc): build **"hcboot-custom" del proyecto factory `e3100_cube`** (¡el origen del nombre cubegm/!) — misma estructura de código que apps-bootloader del SDK (strings de build-paths lo prueban). **NOR-DTB de fábrica EXTRAÍDO** del payload (embebido @0xd3ec0, 0x80b0 B): decompilado = `external_files { path-prefix="cubegm"; dtb.bin/avp.uImage/vmlinux.uImage/xgame-logo.bmp }` — **el modelo mental queda verificado contra el binario REAL**.

**HALLAZGO DECISIVO: el bootloader de fábrica NO tiene módulo de upgrade** — 0 strings de hcfota/upgrade ("Do not support upgrade…", "sd/emmc upgrade timeout", etc. ausentes). El factory hcboot se compiló SIN CONFIG_BOOT_UPGRADE_*. → **La vía HCFOTA es IMPOSIBLE como primera escritura. La vía real: escritura MTD directa desde nuestro Linux** (/dev/mtd0-3 vivos, driver M25P80, NOR despejado en runtime porque el kernel corre desde RAM).

**Escalera 9a redirigida (vía MTD):**
1. **D-2a'** (prueba de mecanismo, contenido idéntico): escribir los bytes EXACTOS del dump (`mtd1ro.bin`) sobre `/dev/mtd1` vía un mini-tool propio (`mtdnor`: MEMERASE por sectores + write O_SYNC + **readback byte-a-byte + sha256**) → reboot → consola idéntica = NOR escribible desde Linux + ciclo erase/write/verify PROBADO sin riesgo de contenido.
2. **D-2b**: build de NUESTRO hcboot (habilitar BR2_TARGET_HCBOOT + bl defconfig dualcore; DDR-init de fábrica; DTB path-prefix="boot" **+ PATCH DUAL-PATH FALLBACK: si /boot falla → busca en cubegm/** — bootloader inbrickeable por diseño) → validación 9a (strings/símbolos vs fábrica) + DDR-init byte-exacto + estructura stub+LZMA equivalente.
3. **D-2c** (flash propio, GO explícito): crear `/boot/` en la SD con los 4 archivos (cubegm intacto como fallback) → flash vía MTD + readback → reboot → el bootloader nuevo prefiere /boot/, cae a cubegm si algo falta.
4. **D-3**: verificado el boot desde /boot/ → borrar cubegm/ al 100% → boot final.

Riesgo residual acotado por: bytes de fábrica probados primero (D-2a'), bootloader dual-path (nunca queda sin camino de boot), dump NOR exacto para rollback, DDR-init byte-exacto. Único escenario de brick: escritura corrupta SIN readback (mitigado) o bootloader dual-path defectuoso (mitigado por D-2a' + validación strings).

---

## Addendum 4 — D-2c FALLO FÍSICO + recuperación total (2026-09-19, noche)

**D-2c ejecutado con GO del usuario: flash verificado byte a byte — PERO la consola quedó en PANTALLA NEGRA sin boot de Linux** (probado con 2 SDs distintas: la nuestra + una stock — confirma fallo a nivel bootloader, no de SD). Análisis inicial ("Linux bootea headless") resultó ERRONEO: el boottrace de 42 KB era de un boot PRE-flash; Linux nunca arrancó tras el flash. **Causa raíz confirmada por diff completo NOR-DTB fábrica vs nuestro**: el NOR-DTB de fábrica ≠ dtb.bin de SD — son DTBs con propósitos DISTINTOS: el de fábrica tiene `panel-init-sequence` CORTA (la que el bootloader necesita para el LCD), bootargs de fábrica (console=ttyHC0 + earlycon uart), uart@1 con pinmux, y pinmux-active distintos. Nuestro build embebió el DTB del SD (secuencia LARGA) → el LCD mal inicializado → el bootloader muere antes de cargar el kernel. **LECCIÓN (ADR-015): el gate semántico del DTB comparaba contra la referencia equivocada para el BOOTLOADER — el NOR-DTB de fábrica es la única referencia válida para el bl; extraído de ahora en adelante del dump (factory-nordtb-0.dtb).**

**Recuperación — canales probados:**
1. ~~S07norflash (auto-flash en boot)~~: DEAD — Linux no bootea, el hook nunca corre.
2. ~~HCFOTA.bin en raíz de SD (apuesta upgrade_force)~~: FALLIDO — el bootloader muere antes de llegar a un bootm (no dispara upgrade_force).
3. **MODO CHIP-EN-BLANCO DEL BootROM (EL CANAL)** — descubierto en el documento oficial del driver USB (`Windows7&8_install_HiChip16xxUSB_Driver-v2.1.docx`): *"cortocircuitar los pines 2 y 4 del NOR flash mientras se enciende → la placa entra al modo USB de actualización directamente como chip en blanco (空片)"*. Nivel BootROM puro: no depende del contenido del NOR. Requiere: abrir la consola, cortocircuitar pin 2 (MISO/DO) con pin 4 (GND) del NOR SOP-8 (pin 1 = punto, lado izquierdo contando hacia abajo), encender con USB-C al PC → el BootROM enumera como dispositivo USB → driver HiChip16xxUSB → HCProgrammer flashea.

**KIT v2 en `D:\R36SX\hcprogrammer-restore-kit\`**: HCProgrammer.exe + HCProgram.exe + HCProgram_bridge.exe + driver Windows (HiChip16xxUSB.inf/sys/cat + VC_redist) + `factory/spinorflash.bin` (512 KB = el NOR COMPLETO de fábrica: DDR-init + bootloader + eromfs + persistentmem, bytes exactos del dump, ensamblado con gen_flashbin oficial, sha a55fad63) + hc16xx_jtag_updater.bin (el "updater" que el tool reclamaba) + ddrinit.abs + hcprog.ini + LEEME-RESTAURACION.txt con el procedimiento completo.

**Decisión del usuario para el fix-forward**: SELECT = tecla upgrade (nodo hcfota-upgrade con key de SELECT en el bl DTS corregido — para poder recuperar por botón si el bl propio vuelve a fallar). El fix-forward quedará: bl DTS = decompilado del NOR-DTB de FÁBRICA + path-prefix="boot" + nodo hcfota-upgrade(key=SELECT) + dual-path — solo tras restaurar la consola con el kit.

### Fase D-3 — flash vía HCFOTA (EL paso de riesgo — requiere red completa + GO explícito)
Manual §16.17: `hcfota` = upgrade oficial, "nor flash only, ya soportado": escribe flag en persistentmem → reboot → **hcboot lee hcfota.bin de un USB y re-flashea NOR**; también `hcfota <file-path>` desde Linux. PRE-REQUISITO ANTES DE FLASHEAR: entender y VERIFICAR la recuperación BootROM-level (HCPROGRAMMER USB — BR2_EXTERNAL_HCPROGRAMMER_USB_IRQ_DETECT_TIMEOUT=300 sugiere detección USB al boot) — si nuestro hcboot no arranca, la única vía es BootROM/JTAG. **PROHIBIDO flashear sin: (1) dump verificado, (2) hcfota.bin construido y validado, (3) mecanismo de recuperación probado con la consola sana, (4) GO explícito del usuario.**

---

## Addendum 2 — D-1 EJECUTADO Y ANALIZADO (2026-09-19, noche) — layout NOR mapeado + mecánica de upgrade completa

**Dump NOR ejecutado por el usuario** (`sh /mnt/sdcard/nor-dump.sh` desde FrogShell) — hashes verificados (SHA256SUMS.txt OK). Copia persistente: `D:\R36SX\nor-dump-20260919\` (mtd0-3 + tabla + DDR-init extraído).

**Layout NOR (mapeado desde el propio dump, evidencia cruce con mtd0):**

| Partición | NOR offset | Tamaño | Contenido |
|---|---|---|---|
| mtd0 "nor" | 0x000000 | 512 KiB (ventana) | vista completa del NOR |
| mtd1 "boot" | 0x000000 | 442.368 B (0x6C000) | DDR-init (12.288 B) + bootloader COMPRIMIDO (boot-compressed; sin strings ni FDT en crudo — el DTB va dentro del payload); contenido real hasta 0x6A000 |
| mtd2 "eromfs" | 0x06C000 | 16 KiB | romfs de rescate (`-rom1fs-`) |
| mtd3 "persistentmem" | 0x070000 | 64 KiB | sysdata/factory + flags OTA |

**DDR-init de fábrica EXTRAÍDO BYTE-EXACTO:** `ddrinit-factory-12288.abs` sha256 `d944d9afb427a404a8f2a57347291e356386c8c107c76b3e8c7baabd420a9145` — **NO coincide con NINGÚN ddrinit del SDK Jul-2024** (15+ variantes comparadas) → el de fábrica es de la línea Dic-2025 o custom → **D-2 usará el extraído, jamás uno del SDK** (el DDR erróneo = brick garantizado).

**Mecánica de upgrade (SOURCE/hcfota/main.c + apps-bootloader/cmd/upgrade.c):**
- `hcfota reboot <mode>` con modos **[none | usbdevice | usbhost | sd | network]** — **`sd` soportado**: el hcboot lee HCFOTA.bin DESDE LA SD (ideal: nuestro medio).
- `hcfota <file-path>` = upgrade desde archivo local; `hcfota info <file>` = inspección.
- upgrade.c: `upgrade_all_modes()` = USB_HOST|SD|NETWORK|USB_DEVICE; `upgrade_force()` como fallback de bootm.
- Empaquetado: `HCFota_Generator --dtb ${DTB} --ini hcprog.ini -o for-upgrade[-withboot]/HCFOTA.bin` (post-build:300-305) — la variante **for-upgrade-withboot incluye el bootloader** = la nuestra. `BR2_EXTERNAL_HCFOTA_FILENAME="HCFOTA.bin"`.
- El DTB del flujo completo (bootloader + hcfota + kernel) sale del MISMO dtb.bin del build → **nuestro DTS gobierna todo**.

**Estrategia de validación en escalera (método 9a — mecanismo primero con datos conocidos-good):**
1. **D-2a**: re-empaquetar y re-flashear el BOOTLOADER DE FÁBRICA EXACTO (bytes del dump) vía HCFOTA → si la consola re-arranca normal = mecanismo de upgrade PROBADO sin riesgo funcional.
2. **D-2b**: build de NUESTRO hcboot (path-prefix="boot" + DDR-init de fábrica) → validación strings/símbolos vs fábrica (método 9a) → flash → boot → mover archivos a /boot/ → **eliminar cubegm/ 100%**.

**Pendiente D-2**: (a) cambiar DTS path-prefix→"boot" + rebuild completo (mkboot/mkall + HCFota_Generator), (b) construir la herramienta hcfota userspace para MIPS (SOURCE/hcfota, meson) para el rootfs propio, (c) leer HCFota_Generator/HCFOTA.bin para el empaquetado del binario de fábrica (D-2a).
