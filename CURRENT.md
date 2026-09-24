# CURRENT.md — Operational Snapshot (CACHE — Git is the truth)

**Updated:** 2026-09-22 (PHASE 9: 9-1/9-2/9-3 DONE — kernel 5.12.4 BUILD PASS)
**Rule:** small snapshot, no history. No changelog.

## PROJECT

r36sx-hclinux — reproducible Linux/HClinux platform for HiChip consoles (HC16xx/MIPS) with TreeFrogUI. **Expanded goal: multi-console ArkOS/darkOS-like ecosystem** (not just R36SX — also SF3000, SF3500, GB350).

## CURRENT PHASE

**Fase 9-6e: USB NETWORKING + SHELL REMOTO FUNCIONANDO. La consola tiene:**
- **MTP**: PHYSICAL PASS (Windows detecta "TreeFrogUI MTP", transferencia de archivos) — sin `net.mode` en la SD
- **NCM Networking**: Windows detecta la consola como ADAPTADOR DE RED (CDC-NCM nativo, no COM7) — con `net.mode` en la SD
- **Shell remoto**: telnet 192.168.137.2 → root (sin contraseña) — FUNCIONA bajo la pantalla azul
- **Pantalla azul**: persiste con cualquier gadget de networking (NCM/RNDIS); el 9105 (interrupt EP PIO) NO la fixeo — la causa es el BULK EP DMA con trafico de red o la interaccion AVP/display con el modo peripheral. DISPLAY-ONLY: el kernel sigue vivo (telnet + red funcionan debajo del azul). Investigacion pendiente con shell remoto.

Kernel: d7bc2597 (5 ports versionados 9101-9105 + 4 genericos 9001-9004)
Stack: app net_mode (upstreamable, AGENTS.md §15) + usb_mtp.sh dispatcher + passwd/shadow en rootfs/etc + telnetd busybox en rootfs/sbin

## CURRENT OBJECTIVE

9-4: physical milestone-1 — swap ONLY cubegm/vmlinux.uImage on SD (keep SD dtb.bin 1258f1eb + treefrog/ + rootfs), serial/visual boot evidence. Requires explicit authorization (class F). Then 9-5 TreeFrogUI+ABI revalidation, 9-6 musb port + DTB reconciliation.

## CURRENT HEAD

(see git log -1 — cache)

## KNOWN-GOOD STATE

- NOR = FACTORY (stock bootloader, not replaceable)
- SD = kernel 5.12.4 69f247dc (gadget built-in + f_mtp order fix) + MTP PHYSICAL PASS (verificado 2x: deteccion Windows + transferencia + salida limpia)
- cubegm/ = 4-file NOR boot contract + diag.enabled (activo para diagnostico)
- Rollback fisico: USR-MTP: PHYSICAL PASS (Windows detecta + transferencia + salida limpia sin capa azul — confirmado 2026-09-23 en kernel 69f247dc)
- RNDIS (9-6e): rolled back — dos bugs documentados (Win Codigo 28: descriptores del gadget; pantalla azul: regresion kernel RNDIS built-in) — iteracion dedicada pendiente
- kmod real + telnetd busybox deployados en rootfs/ (inertes, reutilizables)
- Backup known-good: D:/R36SX/sd-full-backups/2026-09-23_mtp-knowngood/ (fresco, hash-verified)

## BUILD STATUS

KERNEL 5.12.4 (k512 variant): BUILD PASS + CLEAN PHYSICAL PASS (menu/audio/input/emulators; 26 patches = 21 vendor + 4 own-900X + 1 own-9101).
KERNEL 4.4.186: BUILD PASS (superseded on SD; buildable via base defconfig — deprecation decision pending).
ROOTFS: deterministic embed (v6 flow). Gates: TOOLCHAIN/PATCH PASS.
BOOTLOADER: NOT REPLACEABLE (2 attempts, 2 bricks — use factory bootloader).

## PHYSICAL STATUS

CONSOLE OPERATIONAL: factory NOR + kernel 8e + own rootfs + TreeFrogUI working.

## SOURCE SDK SHA256

e321b41f8d649c7d7838f7f19b8cca5cf30ba6cb1ff9545be6943845fbf8d5d — HiChip SDK

## ACTIVE BLOCKERS

None technical.

## NEXT EXACT ACTION

**Debug de la pantalla azul CON SHELL REMOTO (la herramienta ya funciona).**
1. SD a la consola → boot → USB Mode (con net.mode) → conectar cable → telnet 192.168.137.2 → root/Enter
2. Con el shell activo mientras la pantalla está azul:
   - `dmesg | tail -50` (buscar el momento exacto de la corrupción)
   - `cat /proc/iomem | head -30` (el mapa de memoria — el cmd que crasheo la conexión la última vez)
   - `dd if=/dev/fb0 bs=16 count=1 | od -A x -t x1` (el contenido del framebuffer — ¿corrupto?)
   - `cat /sys/class/graphics/fb0/state` + `cat /sys/class/graphics/fb0/mode`
   - Probar reset del display: `echo 4 > /sys/class/graphics/fb0/blank; echo 0 > /sys/class/graphics/fb0/blank`
   - `cat /proc/interrupts` (¿el IRQ del musb está en storm?)
3. Aislamiento adicional: crear el gadget SIN ifconfig (gadget conectado, red inerte) → si no hay azul, el trafico del netdev es el trigger
4. Si el reset del display funciona remotamente: un script watchdog que lo mantiene vivo = workaround inmediato

Otras prioridades 9-6:
- WiFi (9-6d): drivers built-in (rtlwifi/rtl8xxxu) — el module loader sigue ROTO (9-6c: resolve_symbol OOPS)
- ADB (9-6f): functionfs + adbd
- La pantalla azul = prioridad #1 con el shell remoto como herramienta de investigación
