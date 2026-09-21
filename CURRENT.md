# CURRENT.md — Snapshot operacional (CACHÉ — Git es la verdad)

**Actualizado:** 2026-09-21 (Fase 7 CERRADA sin optimizaciones. Proyecto en punto de decisión estratégica.)
**Regla:** snapshot pequeño, sin historia. No changelog.

## PROJECT

r36sx-hclinux — plataforma Linux/HCLinux reproducible para consolas HiChip (HC16xx/MIPS) con TreeFrogUI. **Objetivo ampliado: ecosistema multi-consola tipo ArkOS/darkOS** (no solo R36SX — también SF3000, SF3500, GB350).

## CURRENT PHASE

**FASES 0-8 COMPLETAS. Punto de decisión estratégica.**

Todo lo planificado en el ROADMAP original está hecho:
- Kernel 100% nuestro (4.4.186, ABI fix ADR-012, audio+video+salida OK)
- Rootfs 100% propio (Buildroot 10.8 MiB)
- TreeFrogUI funcional (PHYSICAL PASS total)
- Contrato TreeFrogUI formalizado (TREEFROG_UI_CONTRACT.md)
- Boot chain completamente mapeado
- Recovery probado (pin 2/4 + HCProgrammer + HCFOTA)
- cubegm/ minimizado a NOR contract (4 archivos) + treefrog/ shim activo
- Fase 7 cerrada sin optimizaciones (decisión del usuario)

## CURRENT OBJECTIVE — DECISIÓN DEL USUARIO

El objetivo ampliado (ecosistema multi-consola tipo ArkOS) abre tres frentes:

**A. Multi-consola**: agregar boards para SF3000, SF3500, GB350 (cada una necesita
su DTB, DDR-init, config fragment, y validación física). El framework ya lo
soporta (`build_kernel.sh <board>`, `boards/<board>/`).

**B. Features de ecosistema** (ArkOS-like):
   - Escaneo/organización de ROMs
   - Gestión de configuración de emuladores
   - Perfiles de rendimiento
   - Sistema de updates (HCFOTA ya funciona con bootloader nuestro; con
     bootloader de fábrica, updates via SD)
   - Documentación para usuarios finales

**C. Kernel 5.12.4** (Fase 9 original, DIFERIDO): ahora que 4.4.186 es
known-good físico, se puede intentar el upgrade. Trae: drivers más modernos,
mejor soporte de periféricos, posibles mejoras de rendimiento.

## CURRENT HEAD

`(ver git log -1 — caché)`

## KNOWN-GOOD STATE

- **NOR = FÁBRICA** (restaurado 2026-09-21 vía BootROM USB blank-chip)
- **SD = kernel 8e `f8fb6768` + rootfs propio + TreeFrogUI funcional**
- **cubegm/ = 5 archivos** (contrato NOR) + **treefrog/ = 104 archivos** (stack)
- **Boot ~8s** (aceptado, sin optimizar)
- Backup completo: `sd-full.tar` + `D:\R36SX\nor-dump-20260919\`
- Kit de recuperación: `D:\R36SX\hcprogrammer-restore-kit\` (probado 2 veces)

## ACTIVE BLOCKERS

Ninguno técnico.

## NEXT EXACT ACTION

Decisión del usuario: ¿A (multi-consola), B (features), o C (kernel 5.12.4)?

## REFERENCIA RÁPIDA

| Subsistema | Ver |
|------------|-----|
| Contrato TreeFrogUI formal | `docs/TREEFROG_UI_CONTRACT.md` |
| Post-mortem bootloader (2 brickeos) | `docs/experiments/2026-09-20_postmortem-brickeo-bootloader.md` |
| ADR-012 (ABI) / ADR-013 (diag opt-in) | `DECISIONS.md` |
| Kit de recuperación NOR | `D:\R36SX\hcprogrammer-restore-kit\` |
| ROADMAP completo | `docs/ROADMAP.md` |
