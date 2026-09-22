# r36-hclinux

**Reproducible Linux/HClinux platform for HiChip HC1600A MIPS handheld consoles (R36SX V2.6, SF3000, SF3500, GB350) with TreeFrogUI as the target frontend.**

## Current State

**Phases 0-8 COMPLETE — console physically boots with our own kernel + our own rootfs + TreeFrogUI fully functional.**

What works:
- Own kernel 4.4.186 (provenance-gated build, ABI fix ADR-012)
- Own rootfs (Buildroot, 10.8 MiB)
- TreeFrogUI fully functional (audio, video, emulator exit) — verified on hardware
- Factory bootloader preserved (NOR contract documented, 2 attempts to replace resulted in bricks)
- Recovery method proven (pin 2/4 short + HCProgrammer USB)
- cubegm/ reduced to 5 files (NOR boot contract) + treefrog/ = full TreeFrogUI stack

## Architecture

```
BootROM → DDR-init → bootloader (stock, preserved) → AVP/HCRTOS (stock) → Linux 4.4.186 (ours) → TreeFrogUI
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
- [Roadmap](docs/ROADMAP.md) — phases 0-8 done, phase 9 deferred

## Recovery

Factory NOR restore kit (proven twice): `D:\R36SX\hcprogrammer-restore-kit\`
Method: short NOR pins 2/4 → BootROM USB blank-chip mode → HCProgrammer + HCFOTA-factory-restore.bin
