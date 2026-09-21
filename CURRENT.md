# CURRENT.md — Snapshot operacional (CACHÉ — Git es la verdad)

**Actualizado:** 2026-09-21 (CONSOLA REVIVIDA ✅ — NOR restaurado a fábrica vía BootROM USB (corto 2/4 + HCProgrammer + HCFOTA-factory-restore.bin); TreeFrogUI funcional; el caso cubegm/bootloader propio queda documentado como POST-MORTEM — ver docs/experiments/2026-09-20_postmortem-brickeo-bootloader.md)
**Regla:** snapshot pequeño, sin historia. No changelog.

## PROJECT

r36sx-hclinux — plataforma Linux/HCLinux reproducible para R36SX V2.6 (HC16xx/MIPS), TreeFrogUI estable, control total de kernel/DTB/rootfs/boot.

## CURRENT PHASE

**CONSOLA RESTAURADA A FÁBRICA (NOR) + SD CON DESARROLLO PROPIO FUNCIONAL.** El bootloader de NOR es el de fábrica (restaurado vía blank-chip USB). La SD tiene nuestro kernel 8e + rootfs propio + TreeFrogUI funcional (audio, video, salida de emuladores — PHYSICAL PASS). El caso "eliminar cubegm/ 100%" está PAUSADO tras el brickeo del bootloader propio. El POST-MORTEM completo con las 4 lecciones + el fix-forward diseñado está en docs/experiments/2026-09-20_postmortem-brickeo-bootloader.md.

## CURRENT OBJECTIVE

1. Decisión del usuario: retomar el objetivo cubegm 0% (con el fix-forward diseñado: bl DTS desde factory-nordtb-0.dtb + SELECT upgrade key + gate NOR-DTB-vs-fábrica) O continuar con otras prioridades.
2. Si retoma: PRIMER PASO obligatorio = gate nuevo (diff NOR-DTB compilado vs factory-nordtb-0.dtb) ANTES de cualquier build/flash.

## CURRENT HEAD

`(ver git log -1 — caché)`

## KNOWN-GOOD STATE

- **NOR = FÁBRICA** (restaurado 2026-09-21 vía BootROM USB blank-chip mode)
- **SD = instalación limpia + cubegm mínimo NOR** — PHYSICAL PASS total (audio/video/salida/TreeFrogUI)
- Kernel 8e `f8fb6768` (ABI fixes 9l/9m + S99app v2 + S09trace v5.1 + snd_xfer budget)
- Backup completo: `sd-full.tar` (`963dfd23…`) + `D:\R36SX\nor-dump-20260919\` (NOR + DDR-init + bootloader descomprimido + ambos NOR-DTB)
- Kit de recuperación: `D:\R36SX\hcprogrammer-restore-kit\` (HCFOTA-factory-restore.bin `29ed112c…` + HCProgrammer + driver + todos los archivos)
- Staging: `D:\R36SX\staging\` (fase9m, fase7a, fase8e — fase8e es el bootloader que brickeó, NO desplegar sin fix-forward)

## BUILD STATUS

**KERNEL+ROOTFS: BUILD PASS** (gates TOOLCHAIN/PATCH/DTB PASS).
**BOOTLOADER: NO DESPLEGAR** el build actual (fase8e `f8fb6768` NOR — brickeó por NOR-DTB incorrecto; fix-forward requerido).

## PHYSICAL STATUS

**CONSOLA FUNCIONAL** — NOR de fábrica + SD con desarrollo propio. TreeFrogUI bootea. El bootloader propio queda como experimento fallido documentado.

## SOURCE SDK SHA256

`e3211b41f8d649c7d7838f7f19b8cca5cf30ba6cb1ff9545be6943845fbf8d5d` — /mnt/d/GitHub/KERNEL/hclinux-2024.02.y.2.tar.gz

## ACTIVE BLOCKERS

Ninguno. El fix-forward del bootloader está diseñado y documentado (requiere: DTS desde factory-nordtb-0.dtb + gate nuevo + una-variable-por-boot).

## NEXT EXACT ACTION

1. Usuario decide: retomar cubegm 0% con fix-forward, o continuar con otras prioridades.
2. Si retoma: implementar el bl DTS desde factory-nordtb-0.dtb + gate NOR-DTB-vs-fábrica + SELECT upgrade key.

## REFERENCIA RÁPIDA

| Subsistema | Ver |
|------------|-----|
| POST-MORTEM + recuperación exitosa + fix-forward | `docs/experiments/2026-09-20_postmortem-brickeo-bootloader.md` |
| Contrato TreeFrogUI (boot/ABI/layout) | `docs/TREEFROG_UI_CONTRACT.md` |
| ADR-012 (ABI) / ADR-013 (diag opt-in) | `DECISIONS.md` |
| Kit de recuperación NOR | `D:\R36SX\hcprogrammer-restore-kit\` |
| Reglas (§5 hardware, §13 sync, §14 provenance) | `AGENTS.md` |
