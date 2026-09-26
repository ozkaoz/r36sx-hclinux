# CURRENT.md — Operational Snapshot (CACHE — Git is the truth)

**Updated:** 2026-09-25 (FASE D COMPLETE: cubegm/ 100% eliminado, boot propio desde /boot/, shutdown fixeado)
**Rule:** small snapshot, no history. No changelog.

## PROJECT

r36sx-hclinux — reproducible Linux/HClinux platform for HiChip consoles (HC16xx/MIPS) with TreeFrogUI. **Expanded goal: multi-console ArkOS/darkOS-like ecosystem** (not just R36SX — also SF3000, SF3500, GB350).

## CURRENT PHASE

**FASE D COMPLETE + Fase 9-6 (kernel 5.12.4 max development).**

Trabajo FUERA del árbol git (scripts del stack, binarios recompilados) vive en el fork TreeFrogUI (`D:\GitHub\TreeFrogUI`, branch **`net-mode-app`**, commit `e9680c3`) — ver AGENTS §15.

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
| 9-6f | ADB (FunctionFS) | ⏳ PENDIENTE |

## CURRENT HEAD

`44faa96` — FASE D COMPLETE. Caché; validar con `git log -1`.

## KNOWN-GOOD STATE

- **NOR** = bootloader propio (fábrica + 7 bytes path-prefix "boot") + DDR-init fábrica + eromfs/persistentmem fábrica. Recovery BootROM-USB SIEMPRE disponible.
- **SD** = kernel 5.12.4 (rebuild, S99app limpio, c2434705→c6e3cc70 lineage) + `dtb.bin` 116ddf26 + AVP fábrica `a9788995` + rootfs propio + TreeFrogUI.
- **SD estructura**: `boot/` (4 archivos boot) + `treefrog/` (stack completo) + `rootfs/` + `roms/` + `frogui/` + `picoarch/`. **NO cubegm/**.
- Backup known-good: `D:/R36SX/sd-full-backups/2026-09-23_mtp-knowngood/` (hash-verified).
- Recovery factory: flashear `HCFOTA-factory-restore.bin` vía HCProgrammer (probado 2026-09-21).
- Rollback kernel: goldens stock preservados (uImage 53b3e0b3, dtb 1258f1eb, avp a9788995).

## BUILD STATUS

- **KERNEL 5.12.4 k512 (S99app limpio + 0005/9005 + vendor-8B strip)**: BUILD PASS → kernel rebuild con pipeline pristine → **DESPLEGADO — PHYSICAL PASS** (boot, menú, input, videos, juegos, shutdown).
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

1. Elegir siguiente punto: 9-6d vía celular (drivers USB_USBNET+CDCETHER+RNDIS_HOST como .ko) · 9-6f ADB (posible sin overlay azul) · 9-6b' reconciliación DTB · 9-6c' latencia display.
2. PARA DESPUÉS (clase D, GO explícito): firmware AVP propio (única vía para eliminar el overlay azul).
3. Post 9-6: decisión de migración 5.15 LTS (feasibility audit read-only primero).

Detalle Fase D: `docs/experiments/2026-09-25_faseD-2c-hcprogrammer-flash.md` + `2026-09-25_faseD-2b2-bl-nordtb-factory.md` + `2026-09-25_faseD-F1-avp-own-research.md`.
