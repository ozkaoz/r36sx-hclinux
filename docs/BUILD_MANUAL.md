# r36sx-hclinux — Build Manual & Methodology
> Technical guide for compiling and deploying Linux/TreeFrogUI on HiChip HC1600A consoles. Captures the full method, tools, and lessons learned.

## 1. Target Hardware

| Component | Specification |
|---|---|
| SoC | HiChip HC1600A (MIPS32r2 little-endian, dual-core) |
| Board ID | E3100v20 (identified from factory) |
| RAM | 256 MiB DDR (175 MiB Linux + 80 MiB AVP) |
| NOR Flash | 512 KiB SPI (partitions: boot/eromfs/persistentmem) |
| Display | 1280x720 MIPI-DSI (R63311 panel) |
| Audio | via HC-I2SO/AVP |
| Compatible | R36SX V2.6, SF3000, SF3500, GB350 |

## 2. Boot Chain (discovered via RE)

BootROM → DDR-init (12 KiB .abs from NOR) → bootloader.bin (DDR-init + hcboot) → AVP HCRTOS uImage @0x8bda4000 (stock) → Linux 4.186 @0x80000000 → DTB @0x85ff0000 → initramfs → S99app → TreeFrogUI.

### 2.1 NOR Boot Contract (immutable)

Factory bootloader reads 4 files from cubegm/:
- dtb.bin, avp.uImage, vmlinux.uImage, xgame-logo.bmp

Without these 4 files the console will not boot. This is the contract between NOR and SD.

## 3. Environment Setup

### 3.1 Requirements
- WSL2 Ubuntu 24.04 (ABSOLUTE INVARIANT: ALL dev in WSL).
- SDK: hclinux-2024.02.y.2.tar.gz (sha256 e321b41f...).
- Toolchain: Codescape GNU Tools 2019.09-03-2 MIPS32 MTI Bare Metal.
- Python 3, dtc, gcc, qemu-mipsel-static.
- USB-C cable for PC↔console.
- Jumper wire for recovery mode (short pins 2/4 on NOR).

### 3.2 Setup
```bash
tar xzf hclinux-2024.02.y.2.tar.gz -C ~/work/r36sx-hclinux/
./scripts/prepare_sdk.sh
./scripts/verify_sources.sh
```

## 4. Build Process

### 4.1 Build kernel + rootfs
```bash
./scripts/build_kernel.sh r36sx-v26
```

Generates:
- vmlinux.uImage (kernel with embedded initramfs)
- dtb.bin
- rootfs-own.cpio

### 4.1b Own kernel patches (Phase 9-1 — ADR-014)
Canonical own patches live in `patches/buildroot/linux/` (unified-diff `a/`/`b/`, apply with `-p1`).
`build_kernel.sh` step 3b syncs them to `SDK/patches/linux-<KVER>/` with prefix `900X` (000N -> 900N, applied AFTER the vendor 00XX set). KVER is read from the defconfig — works for 4.4.186 and 5.12.4 alike.
The 4 current patches: 9001 auddec ABI pad 24B (ADR-012), 9002 vidmp ABI pad 20B (ADR-012), 9003 amprpc debug logging, 9004 avp-proxy snd-xfer debug budget (ADR-013).
They target only SOURCE/linux-drivers files (injected pre-patch via rsync) — version-agnostic, no conflicts with the vendor set (verified both sets).
Verified E2E: clean scratch `make linux-patch` = 45 Applying; the 4 patched files are bit-identical to the known-good 8e tree.

### 4.2 Deploy to SD
```bash
cp artifacts/r36sx/vmlinux.uImage /mnt/g/cubegm/
cp artifacts/r36sx/dtb.bin /mnt/g/cubegm/
sync
```

### 4.3 Verify
```bash
mkimage -l /mnt/g/cubegm/vmlinux.uImage
sha256sum /mnt/g/cubegm/vmlinux.uImage
```

## 5. Critical Discovery — ABI Drift (ADR-012)

**Problem:** Audio and video dead on our kernel despite AMP and AVP working.
**Root cause:** Factory userspace binaries (Dec-2025) send structs with different sizeof than the Jul-2024 SDK compiles (24 B in audio_config, 20 B in video_config). The sizeof is encoded in the ioctl number. Without a match, the proxy doesn't recognize the command.
**Fix:** Padding at the end of UAPI structs to match factory ABI.
**Detection method:** On-device trace (amprpc debug) + lui+ori constant reconstruction from factory binaries.

## 6. Bootloader Lessons (2 brickeos)

**Attempt 1:** Wrong NOR-DTB (SD DTS, long panel-init-sequence) → bricked.
**Attempt 2:** Correct NOR-DTB (GATE PASS) but SDK 2024 hcboot binary is incompatible with hardware → bricked.
**Conclusion:** Factory bootloader is NOT replaceable with the available SDK. cubegm/ with 4 files is the minimum NOR contract.

### 6.1 Recovery (tested twice)
1. Short pins 2/4 on NOR SPI → BootROM enters USB blank-chip mode.
2. HC Program + HC Programmer (both open) → Firmware select → HCFOTA-factory-restore.bin.
3. Start Burn → completes in ~1 min → reboot → console restored.

## 7. SD Card Organization

```
cubegm/  = 4-5 files (NOR boot contract, do not remove)
treefrog/ = 41 items (TreeFrogUI stack, apps, drivers)
frogui/   = themes, settings, icons
roms/     = games
rootfs/   = factory runtime libs
```

## 8. Development Workspace
- Git: ~/projects/r36sx-hclinux
- SDK: ~/work/r36sx-hclinux/sdk/
- Builds: ~/work/rsx-hclinux/build/
- Staging: ~/work/r36sx-hclinux/artifacts/

## 9. Mandatory Gates
1. TOOLCHAIN PROVENANCE PASS — real cross-compile
2. PATCH PROVENANCE — all applied
3. DTB SEMANTIC PASS — semantically identical to stock
4. NOR-DTB vs FACTORY (for bootloader) — GATE implemented with PASS
5. ABI VERIFIED — ioctl match with factory binaries (ADR-012)

## 10. Roadmap & Phase 9 (5.12.4)
- Phase 9: upgrade to Linux 5.12.4 as next technical step.
- Pre-requisite: 4.4.186 known-good physically (DONE) + reproducible own-patch set (9-1 DONE, ADR-014).
- SDK evidence: NO 5.4 support exists (patches only for 4.4.186 and 5.12.4) — the earlier "start with 5.4 LTS" recommendation is VOID. Direct 5.12.4 is the only vendor-supported path.
- Vendor provides kernel-configs/5.12.4/kernel-squashfs.config base config.
- Our 4 own patches are version-agnostic (linux-drivers targets) — no conflicts with the 5.12.4 SDK patch set (verified).
- Risks: DTS binding drift 4.4->5.12 (rebase our board DTS on the 5.12.4 arch-patch reference), ioctl ABI revalidation on hardware, musb stack changes.
- Discipline: one variable per boot. Milestone 1 = serial console boot only. Rollback = restore kernel bundle from D:/R36SX/sd-full-backups/2026-09-21_phase8-known-good/.
