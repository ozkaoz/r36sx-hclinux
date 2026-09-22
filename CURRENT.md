# CURRENT.md — Operational Snapshot (CACHE — Git is the truth)

**Updated:** 2026-09-22 (PHASE 9: 9-1/9-2/9-3 DONE — kernel 5.12.4 BUILD PASS)
**Rule:** small snapshot, no history. No changelog.

## PROJECT

r36sx-hclinux — reproducible Linux/HClinux platform for HiChip consoles (HC16xx/MIPS) with TreeFrogUI. **Expanded goal: multi-console ArkOS/darkOS-like ecosystem** (not just R36SX — also SF3000, SF3500, GB350).

## CURRENT PHASE

**PHASE 9-4 COMPLETE: CLEAN PHYSICAL PASS (2026-09-22). Kernel 5.12.4 = NEW KNOWN-GOOD.**
Full criteria met on kernel-5-only SD (kernel-4 purged): TreeFrogUI menu + AUDIO OK (ADR-012 ABI pads validated on 5.12.4 — AUDDEC path physical pass) + input/navigation OK (9101 timer port + HC_INPUT family) + emulator entry/exit OK. Boot ~10s.
- User-verified visual: menu reached + BUTTON NAVIGATION OK (input drivers + 9101 timer port work), boot ~10s (≈ 4.4 known-good 8s)
- Test history: t1 (first deploy, no MMC in vendor base): logo-frozen (S99app wait_for_media_ready infinite loop, zero SD writes). t2 (MMC+HC families+port 9101): black screen — display takes LONGER to init on 5.12; user powered off early; boottrace proved FULL boot (SD mounted, amprpc flowing, UI blit#1). t3 (same kernel, waited): MENU OK.
- Persistentmem/hdmi/panel virtuart lines = cosmetic constants (identical in 4.4-working 9m trace evidence-9m-recovery-boottrace.log)
- S09trace capture truncation at ~6.4s on successful boots = instrumentation artifact (zhijack mount-storm shadows the loop's binaries) — system unaffected
- 9-1 DONE: own-kernel-patch reproducibility (ADR-014: canon patches/buildroot/linux/ -> 900X sync)
- 9-2 DONE: 5.12.4 audit — DTS standalone factory-derived (DTB byte-identical 4.4/5.12, SHA b9b800c8); no 5.4 in SDK (direct 5.12.4 only)
- 9-3 DONE (FINAL, build dd7566c4 12:08): kernel 5.12.4 BUILD PASS — uImage dd7566c4 (6.37MiB gzip, entry 0x804a0d74), embed DETERMINISTA (build_kernel.sh v6: goal default != world — SDK Makefile:600 world==target-post-image, packages solo bajo goal default; uImage lo regenera la CADENA DE IMAGENES no el linux package; flujo: default make -> cp full cpio -> linux-rebuild -> final make). Cpio embebido: 460 entries, per-config, SIN S07norflash (REMOVIDO del overlay — D-2c muerto, riesgo brick). Delta vs 8e-embed: solo lib/modules (versión) + remoción de LEGACY (hcfota/libhudi/liblvgl/S23kmod/sysctl/udhcpd = acumulados era initramfs-fábrica, NO config-driven; BR2_PACKAGE_HCFOTA=no en AMBAS configs). Milestone-1 serial boot no depende de ninguno de los removidos. libhudi para TreeFrogUI = question 9-5 (SD stack la provee). musb OFF k512-fragment (port=9-6). Gates TOOLCHAIN+PATCH PASS
- DTB lineage finding: build DTB (b9b800c8) != SD-proven DTB (1258f1eb) since D-2b factory-derived DTS — pre-existing, NOT a 5.12 regression; milestone-1 keeps SD dtb.bin (ONE variable per boot); reconciliation = 9-6
- Phases 0-8 complete and stable:
- Kernel 100% own (4.4.186, ABI fix ADR-012)
- Rootfs 100% own (Buildroot, 10.8 MiB)
- TreeFrogUI functional (audio+video+exit — PHYSICAL PASS)
- Boot chain mapped + recovery proven (pin 2/4 + HCProgrammer)
- cubegm/ = 5 files (NOR contract) + treefrog/ = TreeFrogUI stack (shim)
- SD clean (166 MiB factory garbage removed)
- Full repo on GitHub, nothing outstanding.

## CURRENT OBJECTIVE

9-4: physical milestone-1 — swap ONLY cubegm/vmlinux.uImage on SD (keep SD dtb.bin 1258f1eb + treefrog/ + rootfs), serial/visual boot evidence. Requires explicit authorization (class F). Then 9-5 TreeFrogUI+ABI revalidation, 9-6 musb port + DTB reconciliation.

## CURRENT HEAD

(see git log -1 — cache)

## KNOWN-GOOD STATE

- NOR = FACTORY (stock bootloader, not replaceable)
- SD = kernel 5.12.4 9731d6a5 + own rootfs (embedded cpio 460 entries) + functional TreeFrogUI menu (PHYSICAL)
- cubegm/ = 4-file NOR boot contract (avp.uImage, dtb.bin 1258f1eb, vmlinux.uImage 5.12.4, xgame-logo.bmp) + diag.enabled (remove after confirmation)
- Kernel-4 PURGED from SD (user-authorized, all preserved hash-verified in D: backup): .8e.bak, .stock.bak, treefrog/modules/4.4.186-release, rootfs lib+lib32 modules/4.4.186-release. rootfs/ userspace kept (ADR-012 forensic value, not kernel-loadable)
- Rollback (if needed): restore from D:/R36SX/sd-full-backups/2026-09-21_phase8-known-good/sd-full.tar (contains 8e f8fb6768 + factory 53b3e0b3 hash-verified)
- Boot ~10s
- Recovery kit verified twice; full backup: D:/R36SX/sd-full-backups/2026-09-21_phase8-known-good/ + D:/R36SX/nor-dump-20260919/

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

9-6 (next, optional priority order): (a) musb/USB port for 5.12 (hcusb.c timeval/do_gettimeofday -> ktime API; USB storage + gadgets currently OFF) + (b) DTB lineage reconciliation (build DTB b9b800c8 with uart@1/pinmux nodes vs SD-proven 1258f1eb) + (c) display-init latency polish (t2 evidence: display slower than 4.4 — investigate AVP-side timeouts) + (d) 4.4.186 kernel deprecation decision (keep buildable or remove defconfig).

## QUICK REFERENCE

| Subsystem | See |
|-----------|-----|
| TreeFrogUI contract | docs/TREEFROG_UI_CONTRACT.md |
| Bootloader post-mortem | docs/experiments/2026-09-20_postmortem-brickeo-bootloader.md |
| ADR-012 (ABI) / ADR-013 (diag opt-in) / ADR-014 (own patches 900X) | DECISIONS.md |
| NOR recovery kit | D:/R36SX/hcprogrammer-restore-kit/ |
| Build manual | docs/BUILD_MANUAL.md |
