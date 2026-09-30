# r36-hclinux

**Reproducible Linux/HClinux platform for HiChip HC1600A MIPS handheld consoles (R36SX V2.6, SF3000, SF3500, GB350) with TreeFrogUI as the target frontend.**

## Current State

**FASE D COMPLETE — cubegm/ 100% eliminated. Console fully controlled.**

What works:
- **Boot 100% from `/boot/`** — own bootloader in NOR (factory + 7-byte path-prefix patch, flashed via HCProgrammer)
- **cubegm/ does NOT exist** on the SD — all binaries recompiled or binary-patched with treefrog/ paths
- Own kernel 5.12.4 (CLEAN PHYSICAL PASS: menu, audio, input, emulators, video, games, shutdown)
- Own rootfs (Buildroot, deterministic embed)
- TreeFrogUI fully functional (audio, video, emulator exit, shutdown)
- USB Mode: MTP PHYSICAL PASS (Windows detection + file transfer)
- USB networking: NCM adapter + telnet root (blue overlay = accepted AVP limitation, ADR-015)
- Internet via PC ICS: ping/DNS/wget PASS
- Module loader: PHYSICAL PASS (gf128mul .ko Live)
- Recovery method proven (BootROM-USB always available — DDR-init factory preserved)

## Architecture

```
BootROM → DDR-init (factory) → bootloader (factory + path-prefix "boot") →
AVP/HCRTOS (factory) → Linux 5.12.4 (ours) → TreeFrogUI (treefrog/)
```

## SD Structure (no cubegm/)

```
boot/       → dtb.bin + avp.uImage + vmlinux.uImage + xgame-logo.bmp
treefrog/   → full TreeFrogUI stack (binaries with treefrog/ paths)
rootfs/     → our rootfs (lib, usr, bin, sbin, etc)
roms/       → games
frogui/     → icons, skins
picoarch/   → configs
```

## Kernel switcher (Fase E — in progress)

Scripts to switch a console between OUR kernel and the stock kernel (end-user facing):

```bash
# Install OUR kernel+DTB on a stock console SD (auto-backup of the user's boot + SHA256 + rollback point)
./scripts/kernel_to_own.sh --sd /mnt/g --bundle-dir <dir-with-vmlinux.uImage+dtb.bin>

# Return to the stock/previous kernel (user backup -> snapshot -> verified factory goldens)
./scripts/kernel_to_stock.sh --sd /mnt/g

# Read-only status: layout, hashes vs goldens, backups inventory
./scripts/kernel_switch_status.sh --sd /mnt/g
```

- Works on both boot layouts: stock bootloader reads `cubegm/`, our NOR bootloader (Fase D) reads `boot/` — auto-detected, **no NOR flash required**.
- Never touches NOR/AVP (AVP only with explicit `--avp`). Factory goldens pinned in `manifests/GOLDEN_STOCK.sha256`.
- HOST PASS 56/56 (`tests/kernel_switch_selftest.sh`); physical CLEAN-INSTALL validation pending. Details: `docs/ROADMAP.md` §Fase E.

## Quick Start

```bash
# Setup
tar xzf hclinux-2024.02.y.2.tar.gz -C ~/work/r36-hclinux/

# Build kernel + bootloader + rootfs
./scripts/build_kernel.sh r36sx-v26 k512

# Flash bootloader (own path-prefix "boot") via HCProgramme
# Firmware: D:/R36SX/hcprogrammer-own-kit/HCFOTA-own-v3.bin
# Recovery: D:/R36SX/hcprogrammer-restore-kit/HCFOTA-factory-restore.bin

# Deploy to SD
cp build/r36sx-v26-k512/images/vmlinux.uImage /mnt/g/boot/
```

## Validation

| Check | Status |
|---|---|
| STATIC | sh -n S99app, provenance gates (toolchain + patches) |
| HOST | build_kernel.sh BUILD OK |
| BUILD | kernel uImage + rootfs.cpio + bootloader.bin |
| PHYSICAL | boot → menu → input → videos → games → shutdown |
| INTERNET | ping 8.8.8.8 + DNS + wget (ICS) |

## Key Decisions

- **ADR-012**: ABI drift fix (factory Dic-2025 userspace vs SDK Jul-2024) — kernel-side struct padding
- **ADR-013**: Diagnostics opt-in only (production silent)
- **ADR-014**: Own patches canonical in `patches/buildroot/linux/` + 900X sync
- **ADR-015**: NCM = production network transport; blue overlay = accepted display-only limitation

## Safety

- NOR bootloader: factory + 7 bytes (path-prefix). Recovery via BootROM-USB (~300ms after DDR-init)
- Factory recovery firmware: `D:/R36SX/hcprogrammer-restore-kit/HCFOTA-factory-restore.bin`
- Full SD backup: `D:/R36SX/sd-full-backups/2026-09-23_mtp-knowngood/`

## License

See [LICENSE](LICENSE)
