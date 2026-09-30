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
| **E. Kernel switcher stock ↔ propio** | Usuario final: cambiar fácilmente al kernel propio desde SO/boot stock, y volver al stock | 🔶 **EN CURSO** — E1–E3 DONE (HOST PASS 56/56); física pendiente |

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

## **Fase E — Kernel switcher: stock ↔ propio (usuario final)** 🔶 EN CURSO (2026-09-30)

**Objetivo (directiva del usuario, 2026-09-30):** que un usuario final con el SO stock + TreeFrogUI y el boot stock pueda **cambiar fácilmente a nuestro kernel propio** y **volver al kernel stock con facilidad** — vía scripts reproducibles con backup automático, verificación SHA256 y camino de vuelta garantizado. Sin flash obligatorio cuando la vía SD-only alcance; NOR solo como opción documentada.

**Por qué es efectivable ya (materia prima 100% verificada físicamente):**

- Cadena de boot 100% mapeada y controlada (Fase D): BootROM → DDR-init (fábrica) → bootloader → AVP → kernel.
- Kernel propio 5.12.4 CLEAN PHYSICAL PASS + DTB propio `116ddf26` + ABI con userspace fábrica resuelta (ADR-012).
- Goldens stock preservados con hash: kernel `53b3e0b3`, DTB `1258f1eb`, AVP `a9788995`.
- Formato HCFOTA decodificado (CRCs recalculados y validados) + kits probados: `D:\R36SX\hcprogrammer-own-kit\` (bootloader propio: fábrica + path-prefix 7 bytes) y `D:\R36SX\hcprogrammer-restore-kit\` (NOR 100% fábrica, PHYSICAL PASS 2026-09-21, LEEME v3).
- Recovery BootROM-USB **siempre disponible** (~300ms tras encendido) = garantía anti-brick permanente.
- Patrón de puntos de rollback probado en SD: `boot/*.prev-*.bak`, `avp.uImage.golden.bak`.

| Sub | Ítem | Estado |
|---|---|---|
| **E1** | `scripts/kernel_to_own.sh` — sobre consola stock: backup automático de SUS archivos de boot → instalar kernel + DTB propios en el layout que SU bootloader espera (`boot/` con NOR propio vía kit own; `cubegm/` con bootloader stock, SIN flash) → SHA256 + punto de rollback | ✅ DONE (HOST PASS) |
| **E2** | `scripts/kernel_to_stock.sh` — volver al kernel stock: prioridad `kernel-switch/orig` (backup del primer uso) → `--from-set` (snapshot) → base golden verificada contra `manifests/GOLDEN_STOCK.sha256` (kernels de FÁBRICA, con AVISO); verificación pre/post | ✅ DONE (HOST PASS) |
| **E3** | `scripts/kernel_switch_lib.sh` + `kernel_switch_status.sh` — gestión de rollback: recovery point `orig/` (nunca rotado) + snapshots `sets/` (rotación 3) + manifiestos SHA256 verificados pre/post escritura | ✅ DONE (HOST PASS) |
| **E4** | **MODO CARPETA** (`--folder`): `boot/` ↔ `cubegm/` (SISTEMA stock completo, 502MB, verificación total + par vs goldens) con **PASO NOR impreso** (kits factory-restore / own-v3 probados) — el flash es físico (GUI HCProgrammer + ventana BootROM) | ✅ DONE (HOST PASS 84/84) — físico pendiente |
| **E5** | UX usuario final: vía de ejecución (script PC con SD montada / modo consola), guía paso a paso, matriz de riesgo + garantía anti-brick documentada | ⏳ |

**Gates y validación:**

- **Regla de simetría:** la vuelta a stock (E2+E3) se implementa y valida ANTES que la ida (E1). Ningún switch sin camino de vuelta probado.
- E1–E3 = **Clase B**: shellcheck + HOST PASS en SD de test → **CLEAN-INSTALL PHYSICAL PASS**: kernel propio instalado sobre SD/consola stock → boot → menú → juego → shutdown → vuelta a stock → boot stock PASS.
- Compatibilidad kernel propio + SD/userspace 100% stock: **NO asumida** — experimento físico dedicado; si requiere rootfs/S99app propios, definir el conjunto mínimo (ADR nueva).
- E4 = **Clase D+F**: autorización hardware explícita; solo con dump NOR previo (`scripts/nor_dump.sh`) y BootROM-USB verificado.
- Cada script cumple AGENTS §5: identificar dispositivo → mostrar info → confirmar tamaño/modelo/mounts → autorización → escribir. La SD stock original del usuario es golden: solo se tocan los archivos de boot del switch documentado.
- E5 completa `docs/RECOVERY.md` (contrato PENDIENTE) con el procedimiento verificado.

**Implementado (2026-09-30 — E1–E3):** `scripts/kernel_to_own.sh` · `kernel_to_stock.sh` · `kernel_switch_status.sh` + lib común (`kernel_switch_lib.sh`: escritura atómica tmp+rename+hash, contrato §5) y `tests/kernel_switch_selftest.sh` — **HOST PASS 56/56** (18 casos: corrupción de backup, golden adulterado, layouts cubegm/boot, `--avp`, rotación, idempotencia, `--from-set`, dry-run). Dry-runs verificados contra la SD real (read-only, cero escrituras). Bases canónicas fijadas (ADR-016): STOCK = Desktop "R36SX V2.6 (0712) Minimal Backup" (byte-idéntico a los goldens) · PROPIO = SD viva. **Hallazgo selftest:** `sha256sum -c` ignora silenciosamente líneas con formato inválido (exit 0 con hash corrupto) → verificación estricta por-archivo (hex-64) ANTES de `-c` y de escribir. shellcheck no disponible en WSL (PEP 668/sin sudo) — gate cumplido con `bash -n` + selftest funcional. **Pendiente físico:** CLEAN-INSTALL PHYSICAL PASS sobre SD/consola stock (autorización F).

## **Punto de decisión (post 9-6): kernel 5.12.4 a máximo desarrollo**

Cuando 9-6 complete, decidir:

1. **Migración 5.15 LTS (o posterior)** — pró: horizonte de mantenimiento (5.12.4 es EOL); drift mínimo desde 5.12 (los 21 parches vendor aplicarían con fuzz menor); contra: repetir validación física completa. Feasibility audit read-only recomendada antes de comprometerse.
2. **Firmware AVP propio** (eliminar el overlay azul) — clase D, requiere GO explícito. Workspace `~/work/r36sx-hclinux/avp-build/` disponible. Ver ADR-015 y `docs/experiments/2026-09-25_faseD-F1-avp-own-research.md`.
3. **Ecosistema multi-consola** (SF3000, SF3500, GB350) — expandir el port a otras consolas HiChip.
