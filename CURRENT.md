# CURRENT.md — Snapshot operacional (CACHÉ — Git es la verdad)

**Actualizado:** 2025-09-21 (PROYECTO FASES 0-8 COMPLETAS Y VERIFICADAS FÍSICAMENTE)
**Regla:** snapshot pequeño, sin historia. No changelog.

## PROJECT

r36sx-hclinux — plataforma Linux/HCLinux reproducible para consolas HiChip (HC16xx/MIPS) con TreeFrogUI. **Objetivo ampliado: ecosistema multi-consola tipo ArkOS/darkOS** (no solo R36SX — también SF3000, SF3500, GB350).

## CURRENT PHASE

**FASES 0-8 COMPLETAS.** El proyecto alcanza su estado objetivo:
- Kernel 100% propio (4.4.186, ABI fix ADR-012)
- Rootfs 100% propio (Buildroot, 10.8 MiB)
- TreeFrogUI funcional (audio+video+salida — PHYSICAL PASS)
- Boot chain mapeado + recovery probado (pin 2/4 + HCProgrammer)
- cubegm/ = 5 archivos (contrato NOR) + treefrog/ = stack TreeFrogUI (shim)
- SD limpia (166 MiB basura removida)
- Repo completo en GitHub, sin outstanding.

## CURRENT OBJECTIVE

Discusión de dirección: multi-consola, features de ecosistema, o Kernel 5.12.4 (Fase 9 — DIFERIDO).

## CURRENT HEAD

(ver git log -1 — caché)

## KNOWN-GOOD STATE

- NOR = FÁBRICA (bootloader stock, no reemplazable)
- SD = kernel 8e f8fb6768 + rootfs propio + TreeFrogUI funcional
- cubegm/ = 5 archivos (NOR contract)
- treefrog/ = 41 items (stack + drivers multi-consola + apps)
- Boot ~8s
- Kit de recuperación verificado 2 veces
- Backup completo: sd-full.tar + D:/R36SX/nor-dump-20260919/

## BUILD STATUS

KERNEL+ROOTFS: BUILD PASS (gates TOOLCHAIN/PATCH/DTB PASS).
BOOTLOADER: NO REEMPLAZABLE (2 intentos, 2 brickeos — usar bootloader de fábrica).

## PHYSICAL STATUS

CONSOLA OPERATIVA: NOR fábrica + kernel 8e + rootfs propio + TreeFrogUI funcionando.

## SOURCE SDK SHA256

e321b41f8d649c7d7838f7f19b8cca5cf30ba6cb1ff9545be6943845fbf8d5d — SDK HiChip

## ACTIVE BLOCKERS

Ninguno técnico.

## NEXT EXACT ACTION

Discusión de dirección (multi-consola, ecosistema, o kernel 5.12.4).

## REFERENCIA RÁPIDA

| Subsistema | Ver |
|------------|-----|
| Contrato TreeFrogUI | docs/TREEFROG_UI_CONTRACT.md |
| Post-mortem bootloader | docs/experiments/2026-09-20_postmortem-brickeo-bootloader.md |
| ADR-012 (ABI) / ADR-013 (diag opt-in) | DECISIONS.md |
| Kit de recuperación NOR | D:/R36SX/hcprogrammer-restore-kit/ |
| Manual de compilación | docs/MANUAL_COMPILACION.md |
