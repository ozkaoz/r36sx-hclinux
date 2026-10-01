# CURRENT.md — Operational Snapshot (CACHE — Git is the truth)

**Updated:** 2026-10-01 — **PROYECTO ARCHIVADO** (decisión del propietario — ADR-017). Snapshot del estado al cierre.
**Rule:** small snapshot, no history. No changelog.

## PROJECT

r36sx-hclinux — plataforma Linux/HCLinux reproducible para consolas HiChip HC16xx (R36SX V2.6) con TreeFrogUI. **ARCHIVADO al cierre de la Fase E.** Guía completa para reanudar/desarrollar: **`docs/ONBOARDING.md`**.

## CURRENT PHASE — CIERRE (Fase E: kernel switcher)

- Modo archivo + modo carpeta (`--folder`) + par end-user (`install_own_os.sh`/`restore_stock_os.sh`) — **HOST PASS 143/143** (`tests/kernel_switch_selftest.sh`).
- **PHYSICAL PASS en NUESTRA consola** (round-trip completo): SO propio → SO stock completo (menú stock) → SO propio — sin flash NOR, sin gap.
- **SD-level ROUND-TRIP BIT-EXACTO** sobre la SD real de un usuario (Stock+TreeFrogUI): baseline 4701 archivos → install → restore → **4701/4701 OK, 0 extras, 0 faltantes**.
- **Pendiente al cierre:** el boot físico del flujo end-user (consola con NOR de fábrica). NOTA: la consola del desarrollador quedó con **NOR de fábrica** tras el flash exitoso del 30-sep 21:44 (log del kit: "Upgrade success, fail 0") — lista para esa prueba si el proyecto se reanuda.

## KNOWN-GOOD STATE (al cierre)

- **Consola**: NOR de fábrica (flash exitoso 2026-09-30 21:44). Para reanudar el flujo `--folder` (boot/): re-flashear `HCFOTA-own-v3.bin` (kit own, método probado — lanzar HCProgrammer con `-WorkingDirectory` en la carpeta del kit).
- **SD viva (G:)**: Stock+TreeFrogUI, bit-exacta a su estado original (verificada 2026-10-01) + `switch-scripts/` (paquete del switcher, versión corregida).
- **Nuestro SO**: `boot/` (kernel `44a1af3e` + dtb `116ddf26` + AVP fábrica `a9788995`) + `treefrog/` + `rootfs/` + `roms/` + `frogui/` + `picoarch/` — sin `cubegm/`.
- **Preservados**: Desktop "SO PROPIO" (copia offline completa de nuestro SO) · `D:\R36SX\goldens-stock\` (kernel/DTB/AVP stock verificados) · `D:\R36SX\staging\` (kernels por fase, incl. par nuestro) · `D:\R36SX\sd-full-backups\` · kits HCProgrammer own + factory-restore (probados).
- **Recovery**: BootROM-USB siempre disponible (~300ms tras encender, DDR-init fábrica intacto).

## BUILD STATUS (al cierre)

- KERNEL 5.12.4 k512: pipeline completo BUILD PASS + gates TOOLCHAIN/PATCH PROVENANCE PASS (flujo: `docs/ONBOARDING.md` §3).
- SDK 100% pristine. Rootfs embed determinista v6. Bootloader propio = fábrica + 7 bytes (kit own v3).
- Selftest del switcher: HOST PASS 143/143.

## PHYSICAL STATUS (al cierre)

Consola 100% funcional (última validación física: round-trip del switcher — menú stock y menú TreeFrogUI NUESTRO, ambos booteados y reportados por el propietario). cubegm/ eliminado de nuestro SO. USB completo: MTP + NCM (telnet root) + ADB (shell/push/pull overlay-free).

## SOURCE SDK SHA256

e3211b41f8d649c7d7838f7f19b8cca5cf30ba6cb1ff9545be6943845fbf8d5d — HiChip SDK (inmutable)

## ACTIVE BLOCKERS

Ninguno. Pendientes documentados: `docs/ROADMAP.md` §cierre + `docs/ONBOARDING.md` §0.

## NEXT EXACT ACTION (para quien reanude)

1. Leer **`docs/ONBOARDING.md`** (guía paso a paso completa: entorno → compilar → desplegar → desarrollar).
2. Prueba física pendiente de la Fase E: consola (NOR fábrica) + SD Stock+TreeFrogUI → `install_own_os.sh` → boot TreeFrogUI → `restore_stock_os.sh` → boot stock → Fase E física completa.
3. Después: E5 (UX usuario final + `docs/RECOVERY.md`), migración 5.15 LTS, AVP propio (ver `docs/ROADMAP.md` §punto de decisión).

Detalle físico Fase E: `docs/experiments/2026-10-01_faseE-kernel-switcher-physical.md`.
