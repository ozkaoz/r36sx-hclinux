# CURRENT.md — Operational Snapshot (CACHE — Git is the truth)

**Updated:** 2026-09-21 (PROJECT PHASES 0-8 COMPLETE AND PHYSICALLY VERIFIED)
**Rule:** small snapshot, no history. No changelog.

## PROJECT

r36sx-hclinux — reproducible Linux/HClinux platform for HiChip consoles (HC16xx/MIPS) with TreeFrogUI. **Expanded goal: multi-console ArkOS/darkOS-like ecosystem** (not just R36SX — also SF3000, SF3500, GB350).

## CURRENT PHASE

**PHASE 9 IN PROGRESS — kernel 5.12.4 (direct; no 5.4: SDK has no 5.4 patch set — evidence).**
- 9-1 DONE: own-kernel-patch reproducibility (ADR-014: canon patches/buildroot/linux/ -> 900X sync; E2E 45 Applying, bit-identical to 8e)
- Phases 0-8 complete and stable:
- Kernel 100% own (4.4.186, ABI fix ADR-012)
- Rootfs 100% own (Buildroot, 10.8 MiB)
- TreeFrogUI functional (audio+video+exit — PHYSICAL PASS)
- Boot chain mapped + recovery proven (pin 2/4 + HCProgrammer)
- cubegm/ = 5 files (NOR contract) + treefrog/ = TreeFrogUI stack (shim)
- SD clean (166 MiB factory garbage removed)
- Full repo on GitHub, nothing outstanding.

## CURRENT OBJECTIVE

Kernel 5.12.4 via SDK vendor path (20-patch set + kernel-configs/5.12.4 base). Milestones: 9-2 audit (DTS/CHECK_ADC), 9-3 build, 9-4 serial boot, 9-5 TreeFrogUI + ABI revalidation.

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

9-2: audit 5.12.4 — DTS bindings in patch 0001 (4.4 vs 5.12), CHECK_ADC symbol existence, rebase make_board_dts.sh on the 5.12.4 reference.

## QUICK REFERENCE

| Subsystem | See |
|-----------|-----|
| TreeFrogUI contract | docs/TREEFROG_UI_CONTRACT.md |
| Bootloader post-mortem | docs/experiments/2026-09-20_postmortem-brickeo-bootloader.md |
| ADR-012 (ABI) / ADR-013 (diag opt-in) / ADR-014 (own patches 900X) | DECISIONS.md |
| NOR recovery kit | D:/R36SX/hcprogrammer-restore-kit/ |
| Build manual | docs/BUILD_MANUAL.md |
