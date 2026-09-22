# CURRENT.md — Operational Snapshot (CACHE — Git is the truth)

**Updated:** 2026-09-22 (PHASE 9: 9-1/9-2/9-3 DONE — kernel 5.12.4 BUILD PASS)
**Rule:** small snapshot, no history. No changelog.

## PROJECT

r36sx-hclinux — reproducible Linux/HClinux platform for HiChip consoles (HC16xx/MIPS) with TreeFrogUI. **Expanded goal: multi-console ArkOS/darkOS-like ecosystem** (not just R36SX — also SF3000, SF3500, GB350).

## CURRENT PHASE

**PHASE 9 IN PROGRESS — kernel 5.12.4 (direct; no 5.4: SDK has no 5.4 patch set — evidence).**
- 9-1 DONE: own-kernel-patch reproducibility (ADR-014: canon patches/buildroot/linux/ -> 900X sync; E2E 45 Applying, bit-identical to 8e)
- 9-2 DONE: 5.12.4 audit — DTS standalone factory-derived (version-invariant: DTB byte-identical 4.4/5.12, SHA b9b800c8); CHECK_ADC/HC_* symbols shared via linux-drivers; NO conflicts own-patches vs SDK 5.12.4 set; no 5.4 in SDK (direct 5.12.4 only)
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
- SD = kernel 8e f8fb6768 + own rootfs + functional TreeFrogUI
- cubegm/ = 5 files (NOR contract)
- treefrog/ = 41 items (stack + multi-console drivers + apps)
- Boot ~8s
- Recovery kit verified twice
- Full backup: D:/R36SX/sd-full-backups/2026-09-21_phase8-known-good/ + D:/R36SX/nor-dump-20260919/

## BUILD STATUS

KERNEL+ROOTFS: BUILD PASS (TOOLCHAIN/PATCH/DTB gates PASS).
BOOTLOADER: NOT REPLACEABLE (2 attempts, 2 bricks — use factory bootloader).

## PHYSICAL STATUS

CONSOLE OPERATIONAL: factory NOR + kernel 8e + own rootfs + TreeFrogUI working.

## SOURCE SDK SHA256

e321b41f8d649c7d7838f7f19b8cca5cf30ba6cb1ff9545be6943845fbf8d5d — HiChip SDK

## ACTIVE BLOCKERS

None technical.

## NEXT EXACT ACTION

9-4 DEPLOYED (2026-09-22, user-authorized class F): cubegm/vmlinux.uImage = dd7566c4 (kernel 5.12.4); 8e backup = vmlinux.uImage.8e.bak (f8fb6768) on SD; dtb.bin/avp.uImage untouched (1258f1eb/a9788995); diag.enabled flag set. AWAITING PHYSICAL BOOT TEST: user boots console -> observe (menu TreeFrogUI / splash / black / hang) -> SD back to PC -> read boottrace evidence. Milestone-1 PASS = visual menu + clean boottrace. Rollback = cp vmlinux.uImage.8e.bak vmlinux.uImage.

## QUICK REFERENCE

| Subsystem | See |
|-----------|-----|
| TreeFrogUI contract | docs/TREEFROG_UI_CONTRACT.md |
| Bootloader post-mortem | docs/experiments/2026-09-20_postmortem-brickeo-bootloader.md |
| ADR-012 (ABI) / ADR-013 (diag opt-in) / ADR-014 (own patches 900X) | DECISIONS.md |
| NOR recovery kit | D:/R36SX/hcprogrammer-restore-kit/ |
| Build manual | docs/BUILD_MANUAL.md |
