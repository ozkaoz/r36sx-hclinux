# r36-hclinux

**Reproducible Linux/HClinux platform for HiChip HC1600A MIPS handheld consoles (R36SX V2.6, SF3000, SF3500, GB350) with TreeFrogUI as the target frontend.**

## Current State

**Phases 0-9 COMPLETE — console physically boots with our own kernel + our own rootfs + TreeFrogUI fully functional.**
**Phase 9-6 (maximize kernel 5.12.4) IN PROGRESS.**

What works:
- Own kernel 5.12.4 (CLEAN PHYSICAL PASS: menu, audio, input, emulators; provenance-gated build, ABI fix ADR-012)
- Own rootfs (Buildroot, ~10 MiB, deterministic embed)
- TreeFrogUI fully functional (audio, video, emulator exit) — verified on hardware
- USB Mode: MTP PHYSICAL PASS (Windows detection + file transfer)
- USB networking: NCM/RNDIS network adapter + remote root shell work, but trigger the AVP **blue overlay** (display-only; kernel stays alive); CDC-ACM serial shell works with no overlay
- Factory bootloader preserved (NOR contract documented, 2 attempts to replace resulted in bricks)
- Recovery method proven (pin 2/4 short + HCProgrammer USB)
- cubegm/ reduced to 4 files (NOR boot contract) + treefrog/ = full TreeFrogUI stack

## Architecture

```
BootROM → DDR-init → bootloader (stock, preserved) → AVP/HCRTOS (stock) → Linux 5.12.4 (ours) → TreeFrogUI
```

## Quick Start

```bash
# Setup
tar xzf hclinux-2024.02.y.2.tar.gz -C ~/work/r36-hclinux/
# Build
./scripts/build_kernel.sh r36sx-v26
# Deploy
cp artifacts/r36sx/vmlinux.uImage /mnt/g/cubegm/
sync
```

## Documentation

- [Build Manual](docs/BUILD_MANUAL.md) — compilation guide + methodology
- [TreeFrogUI Contract](docs/TREEFROG_UI_CONTRACT.md) — formal interface
- [Post-mortem](docs/experiments/2026-09-20_postmortem-brickeo-bootloader.md) — bootloader lessons
- [Roadmap](docs/ROADMAP.md) — phases 0-9 done; phase 9-6 (kernel max development) in progress

## Recovery

Factory NOR restore kit (proven twice): `D:\R36SX\hcprogrammer-restore-kit\`
Method: short NOR pins 2/4 → BootROM USB blank-chip mode → HCProgrammer + HCFOTA-factory-restore.bin
