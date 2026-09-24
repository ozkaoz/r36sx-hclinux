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

**9-6e: PANTALLA AZUL — TEORIA REVOCADA, NUEVA DIRECCION.**

HALLAZGO CRITICO DEL DIAGNOSTICO EN VIVO (BLUE_DIAG.log):
- El framebuffer contiene `06 f2` UNIFORME (todo el buffer, inicio/centro/final) = NO es corrupcion random de DMA. Es un PATRON DELIBERADO.
- En RGB565: 0xF206 = azul dominante — coincide con la pantalla azul visible.
- El AVP reporta `rgb: ff0000ff` — el AVP SABE que el display esta azul (su estado interno).
- CONFIG_MUSB_DMA_XFER_ALIGN NO ESTA ACTIVADO — el bloque con el URB access (9106) NUNCA COMPILA. Toda la teoria del URB/DMA era INCORRECTA — ese codigo no corre.
- El 9105 (interrupt EP PIO) SI esta activo (confirmado en dmesg: "ep2in: interrupt EP -> PIO mode").
- NO hay kernel OOPS. El kernel esta vivo. Telnet funciona.

REVISED UNDERSTANDING:
La pantalla azul NO es corrupcion de memoria — es algo que LLENA el framebuffer con un patron uniforme deliberadamente. Candidatos:
1. El AVP: cuando el musb entra en modo peripheral, el display handler del AVP podria llenar el fb con un color de "estado" (ff0000ff = azul).
2. El GE: el engine grafico podria estar limpiando el fb cuando algo en el display pipeline cambia.
3. El stack TreeFrogUI (picoarch/hwdisp): cuando el bloquea (USB mode), podria escribir un patrón al fb.

PROXIMA INVESTIGACION:
1. Con el shell remoto (telnet), mientras la pantalla esta azul, VERIFICAR quien escribe al fb:
   - `cat /proc/iomem | grep -i fb` — la direccion fisica del fb
   - Despues del blank/unblank, ver si el patron `06 f2` reaparece o si se restaura el menu
   - `echo 1 > /proc/sys/kernel/sysrq; echo t > /proc/sysrq-trigger` (dump de todos los stacks — ver si el GE/AVP tiene un thread escribiendo)
2. Buscar en el codigo del stack (picoarch/hwdisp/avp) que escribe `0xF206` o hace fill del fb
3. Revisar los fonts del SDK: el `rgb: ff0000ff` del virtuart es un comando/display del AVP

El 9105 queda como defense-in-depth. El 9106 esta en dead code (CONFIG no activado) — no hace dano pero tampoco ayuda.
