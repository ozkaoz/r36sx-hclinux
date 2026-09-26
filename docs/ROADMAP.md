# docs/ROADMAP.md — Fases, gates y formato de iteración

## Visión

BootROM → DDR-init (fábrica) → **bootloader propio (fábrica + path-prefix "boot")** → AVP/HCRTOS (stock, preservado) → **kernel propio (5.12.4 = known-good)** → **DTB propio** → **rootfs propio (Buildroot, embed determinista)** → picoarch → **TreeFrogUI como shell principal** → ecosistema multi-consola. **cubegm/ 100% eliminado.**

## Fases

| Fase | Objetivo | Estado |
|---|---|---|
| **0. Bootstrap** | Repo + contexto + agentes + GitHub | ✅ DONE |
| **1. Auditoría SDK** | Extraer y auditar SDK completo | ✅ DONE |
| **2. Baseline vendor** | Reproducir build vendor | ✅ DONE |
| **2.5 Provenance** | Cross-compile + patch provenance | ✅ DONE |
| **3. Hardware R36SX** | Documentar hardware real | ✅ DONE |
| **4. Board propia** | r36sx-v26 derivada por evidencia | ✅ DONE (ADR-010) |
| **5. Kernel propio** | Reemplazar kernel/DTB → PHYSICAL PASS | ✅ DONE (iteración 6x) |
| **6. Contrato TreeFrogUI** | Matriz de dependencias + ABI fix | ✅ DONE (ADR-012) |
| **7. Optimizaciones** | Boot rápido + dieta kernel + rendimiento | ✅ CLOSED |
| **8. Rootfs propio** | Buildroot + clean install | ✅ DONE (sin SHIM — boot directo desde /boot/) |
| **D. Boot propio + eliminar cubegm/** | Bootloader en NOR con path-prefix "boot" + cubegm/ 100% eliminado | ✅ **COMPLETE** (2026-09-25) |
| **9. Kernel 5.12.4** | Upgrade desde 4.4.186 known-good | ✅ DONE — CLEAN PHYSICAL PASS |

## Fase D — COMPLETE ✅

**Eliminación total de cubegm/ + control del boot (2026-09-25)**

- Bootloader en NOR: **fábrica + 7 bytes** (path-prefix `cubegm`→`boot`), flasheado via HCProgrammer (formato HCFOTA decodificado del SDK, CRCs recalculados y validados).
- Recovery BootROM-USB **siempre disponible** (DDR-init fábrica preservado — ventana ~300ms tras encender).
- `/boot/` = fuente única de boot: `dtb.bin` + `avp.uImage` + `vmlinux.uImage` + `xgame-logo.bmp`.
- **cubegm/ NO EXISTE** en la SD — 0 archivos, 0 bytes, 0 refs en binarios.
- S99app: **escrito desde cero** (0 cubegm, sin bind mount, sh -n OK). Causa raíz de fallos previos: syntax errors de sed/replace.
- Todos los binarios: recompilados (picoarch, frogui, zhijack, picoarch_hi — treefrog/ paths) o binary-patcheados (driver*.so, pcsx4all, frogshell, pico286, lgpt, ebook, rockbox, video_player, image_viewer, libemu_md — cubegm→tf, null-padded).
- Shutdown: **FIXEADO** (exec→regular call; powergpio rc=0).
- SD structure: `boot/` + `treefrog/` + `rootfs/` + `roms/` + `frogui/` + `picoarch/` — sin cubegm/.

**Docs**: `docs/experiments/2026-09-25_faseD-2c-hcprogrammer-flash.md` + `2026-09-25_faseD-2b2-bl-nordtb-factory.md` + `2026-09-20_postmortem-brickeo-bootloader.md`

## **9-6. Optimización máxima del kernel 5.12.4** (EN CURSO)

| Sub | Ítem | Estado |
|---|---|---|
| **9-6a** | Port MUSB/USB (host + gadget) | ✅ DONE (host PHYSICAL PASS) |
| **9-6b** | USB Mode MTP gadget | ✅ DONE (2026-09-23) |
| **9-6c** | Module loader | ✅ DONE (2026-09-25 PHYSICAL PASS: gf128mul Live; fix gcc magic-div + vendor 8B) |
| **9-6d** | Internet por USB | 🔶 F1 DONE (ICS via PC PASS) / F2 (celular) PENDIENTE |
| **9-6e** | Red USB / overlay AVP | ✅ DONE (NCM producción, ADR-015) |
| **9-6f** | ADB (FunctionFS) | ⏳ PENDIENTE |
| **9-6b'** | Reconciliación DTB | ⏳ PENDIENTE |
| **9-6c'** | Latencia de display (~10s vs 8s) | ⏳ PENDIENTE |

## **Punto de decisión (post 9-6): kernel 5.12.4 a máximo desarrollo**

Cuando 9-6 complete, decidir:

1. **Migración 5.15 LTS (o posterior)** — pró: horizonte de mantenimiento (5.12.4 es EOL); drift mínimo desde 5.12 (los 21 parches vendor aplicarían con fuzz menor); contra: repetir validación física completa. Feasibility audit read-only recomendada antes de comprometerse.
2. **Firmware AVP propio** (eliminar el overlay azul) — clase D, requiere GO explícito. Workspace `~/work/r36sx-hclinux/avp-build/` disponible. Ver ADR-015 y `docs/experiments/2026-09-25_faseD-F1-avp-own-research.md`.
3. **Ecosistema multi-consola** (SF3000, SF3500, GB350) — expandir el port a otras consolas HiChip.
