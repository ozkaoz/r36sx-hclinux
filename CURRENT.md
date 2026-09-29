# CURRENT.md — Operational Snapshot (CACHE — Git is the truth)

**Updated:** 2026-09-26 (9-6f ADB/FunctionFS implementado — kernel `0b549b84` BUILD PASS, deploy/test físico pendientes)
**Rule:** small snapshot, no history. No changelog.

## PROJECT

r36sx-hclinux — reproducible Linux/HClinux platform for HiChip consoles (HC16xx/MIPS) with TreeFrogUI. **Expanded goal: multi-console ArkOS/darkOS-like ecosystem** (not just R36SX — also SF3000, SF3500, GB350).

## CURRENT PHASE

**FASE D COMPLETE + 9-6f ADB/FunctionFS: OVERLAY PASS · transporte `adb devices` OK · shell ADB = defecto abierto (ver NEXT EXACT ACTION).**

Trabajo FUERA del árbol git (scripts del stack, binarios recompilados) vive en el fork TreeFrogUI (`D:\GitHub\TreeFrogUI`, branch **`net-mode-app`**, commit `8f42063`) — ver AGENTS §15.

### FASE D — ELIMINACIÓN COMPLETA DE cubegm/ ✅ (2026-09-25)

- **cubegm/ NO EXISTE en la SD.** Eliminado al 100% (directorio + contenido + refs en binarios).
- **Boot 100% desde `/boot/`**: bootloader propio en NOR (fábrica + path-prefix "boot" — patch de 7 bytes in-place, flasheado vía HCProgrammer con recovery BootROM-USB).
- **S99app limpio desde cero**: 0 refs cubegm, sin bind mount, treefrog/ paths directo. Sintaxis sh -n OK.
- **Todos los binarios recompilados o binary-patcheados**: picoarch, frogui, zhijack, picoarch_hi (recompilados, 0 refs) + driver*.so, pcsx4all, frogshell, pico286, lgpt, ebook, rockbox, video_player, image_viewer, libemu_md (binary-patch: cubegm→tf, null-padded).
- **Shutdown FIXEADO**: regular call (no exec) — powergpio rc=0 confirmado.
- **Causa raíz de todos los fallos previos**: S99app syntax errors (sed/replace roto echo quoting + else/fi huérfanos) — el S99app limpio funciona a la primera.
- **SD limpia**: logs de diagnóstico, backups .bak y archivos residuales eliminados.

### Resto de 9-6

| Sub | Ítem | Estado |
|---|---|---|
| 9-6a | Port MUSB/USB (host) | ✅ host PHYSICAL PASS |
| 9-6b | USB Mode MTP gadget | ✅ PHYSICAL PASS |
| 9-6c | Module loader | ✅ DONE — PHYSICAL PASS (kernel e45547a2: gf128mul Live) |
| 9-6b' | Reconciliación DTB | ⏳ PENDIENTE |
| 9-6c' | Latencia de display (~10s vs 8s) | ⏳ PENDIENTE |
| 9-6d | Internet por USB | ✅ F1 PHYSICAL PASS vía PC (ICS); F2 celular PENDIENTE |
| 9-6e | Red USB / overlay AVP | ✅ DONE (NCM producción, ADR-015) |
| 9-6f | ADB (FunctionFS) | 🔶 MAYORÍA: **overlay PASS** (cero azul en todas las sesiones ADB) + **transporte completo** (device cada boot) + **shell EJECUTA builtins** (`adb shell "echo hello"` => hello, verificado multi-sesión). Pendiente: applets externos (fork bajo ffs live = kernel vendor; asimetría NCM-forkea-bien apunta al 9102) + servicio sync como alternativa sin kernel |

## CURRENT HEAD

`0bc6e1a` — 9-6f ADB/FunctionFS implementado (kernel BUILD PASS, deploy pendiente). Caché; validar con `git log -1`.

## KNOWN-GOOD STATE

- **NOR** = bootloader propio (fábrica + 7 bytes path-prefix "boot") + DDR-init fábrica + eromfs/persistentmem fábrica. Recovery BootROM-USB SIEMPRE disponible.
- **SD** = kernel 5.12.4 (rebuild, S99app limpio, c2434705→c6e3cc70 lineage) + `dtb.bin` 116ddf26 + AVP fábrica `a9788995` + rootfs propio + TreeFrogUI.
- **SD estructura**: `boot/` (4 archivos boot) + `treefrog/` (stack completo) + `rootfs/` + `roms/` + `frogui/` + `picoarch/`. **NO cubegm/**.
- Backup known-good: `D:/R36SX/sd-full-backups/2026-09-23_mtp-knowngood/` (hash-verified).
- Recovery factory: flashear `HCFOTA-factory-restore.bin` vía HCProgrammer (probado 2026-09-21).
- Rollback kernel: goldens stock preservados (uImage 53b3e0b3, dtb 1258f1eb, avp a9788995).

## BUILD STATUS

- **KERNEL 5.12.4 k512 (S99app limpio + 0005/9005 + vendor-8B strip)**: BUILD PASS → kernel rebuild con pipeline pristine → **DESPLEGADO — PHYSICAL PASS** (boot, menú, input, videos, juegos, shutdown).
- **KERNEL 5.12.4 k512 + 9-6f (FunctionFS+ADB)**: BUILD PASS 2026-09-26 13:21 → `vmlinux.uImage` `0b549b84` (8.425.980 B; f_fs.o+g_ffs.o; incluye 9-6d-F2 usbnet .ko inertes). TOOLCHAIN+PATCH PROVENANCE PASS. dtb SIN cambios (`116ddf26`). **NO desplegado** — deploy Clase F + test 3 fases pendientes.
- **SDK**: 100% pristine (git checkout de hcboot.mk/Config.in, sin patches residuales).
- **ROOTFS**: embed determinista (v6 flow). Gates TOOLCHAIN+PATCH PASS.
- **KERNEL 4.4.186**: superseado; buildable (deprecación pendiente).
- **BOOTLOADER**: fábrica + 7 bytes (path-prefix "boot") en NOR.

## PHYSICAL STATUS

CONSOLA 100% FUNCIONAL: NOR bootloader propio (fábrica+7B) + kernel 5.12.4 rebuild + rootfs propio + TreeFrogUI. **cubegm/ NO EXISTE.** Boot desde /boot/. Menú + input + videos + juegos + shutdown — todo PASS. Module loader funcional. Internet vía PC (ICS). MTP PASS. NCM networking PASS (overlay azul = limitación aceptada, ADR-015).

## SOURCE SDK SHA256

e3211b41f8d649c7d7838f7f19b8cca5cf30ba6cb1ff9545be6943845fbf8d5d — HiChip SDK

## ACTIVE BLOCKERS

- **NINGUNO** — Fase D completa, consola 100% operativa sin cubegm/.

## NEXT EXACT ACTION

1. **9-6f shell (defecto abierto) — diagnóstico definitivo vía NCM**: quitar `adb.mode` de la SD → NETWORK (NCM) → `telnet 192.168.137.2` → **con la consola en sesión adb (gadget live + server conectado)** verificar el estado del worker: `cat /proc/<pid>/stat /proc/<pid>/wchan /proc/<pid>/status` → R/S/D decide: D = bloqueo kernel (musb 9102 audit), S = wakeup roto, R = starvation. Capturar también los logs v16/v17 de la SD.
2. **9-6d vía celular**: drivers `USB_USBNET/CDCETHER/RNDIS_HOST` como .ko YA en el kernel `0b549b84`: insmod + udhcpc contra el teléfono.
3. **Shell de producción YA disponible**: NCM/telnet (ADR-015) — para trabajo real usar NCM mientras el shell ADB se debuggea.
4. PARA DESPUÉS (clase D, GO explícito): firmware AVP propio (elimina el overlay en el transporte NCM).
5. Post 9-6: decisión de migración 5.15 LTS (feasibility audit read-only primero).

Detalle Fase D: `docs/experiments/2026-09-25_faseD-2c-hcprogrammer-flash.md` + `2026-09-25_faseD-2b2-bl-nordtb-factory.md` + `2026-09-25_faseD-F1-avp-own-research.md`.
