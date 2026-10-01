# Fase E — Kernel switcher: validación física (ida PASS + vuelta desplegada)

**Fecha:** 2026-09-30 / 2026-10-01
**Objetivo:** validar físicamente el kernel switcher stock↔propio (E1–E4) sobre la consola R36SX V2.6 y la SD viva (G:) — requisito de producto del usuario: **el usuario final NO tiene HCProgrammer → CERO flash NOR en el flujo**.

## Resultado

- **IDA → SO STOCK: PHYSICAL PASS** (reporte del usuario, 2026-10-01): *"al prender la consola, llegó correctamente al menú de inicio del SO Stock. Todo parece correcto."*
- **VUELTA → SO PROPIO: desplegada** (boot de cierre pendiente del usuario): boot/ = par nuestro, cubegm/ eliminada con backup verificado.

## Diseño validado (v2 — "el kernel determina el SO")

La clave física: el bootloader propio (fábrica + 7 bytes path-prefix "boot", Fase D) carga SIEMPRE desde `boot/`. El kernel que hay ahí determina el SO:

| Estado | boot/ (carga el bootloader) | Carpeta del sistema | Resultado físico |
|---|---|---|---|
| **SO STOCK** | par de FÁBRICA (53b3e0b3 + 1258f1eb) | `cubegm/` CREADA (sistema stock completo, 2248 archivos) | menú stock PASS ✓ |
| **SO PROPIO** | par NUESTRO (44a1af3e + 116ddf26) | `cubegm/` ELIMINADA → backup | nuestro OS (treefrog/) |

`boot/` **siempre presente** → la consola nunca queda sin arrancar (sin gap). El AVP queda de fábrica en ambos estados (a9788995, nunca tocado).

## Timeline con evidencia

1. **2026-09-30 (tarde)** — file-swap del par a stock en boot/ (sin cubegm/ aún) → el usuario REDIRIGE el requisito: swap de CARPETA (SO completo, no solo el par).
2. **v1 carpeta** — `boot/` movida a backup + `cubegm/` (502MB, verificación total) instalada + paso NOR impreso. **Evidencia física del usuario: "insert tf card"** al encender SIN flashear NOR = el bootloader (fábrica+7B) no encontró `boot/` — confirma: (a) NOR del usuario sigue siendo PROPIO (no flasheó), (b) lee boot/ exclusivamente (Fase D boot-2 re-validado en el mundo real), (c) el gap v1 era inaceptable para el producto.
3. **Rediseño v2 (requisito usuario: cero HCProgrammer)** — `to_stock --folder`: par de fábrica en boot/ + cubegm/ creada; `to_own --folder`: par nuestro + cubegm/ eliminada. `ks_detect_layout`: prioridad boot/ (coexistencia boot/+cubegm/ = estado SO-stock por diseño). HOST PASS 90/90 (selftest T1–T18 + TF1–TF5; fix flaky `cut -c1`→`head -c1`).
4. **2026-10-01 deploy ida** — boot/ restaurada (kernel propio) → `to_stock --folder`: cubegm/ reutilizada + par de fábrica restaurado desde `orig/` → **el usuario enciende: MENÚ STOCK PASS** (física completa: bootloader propio → kernel de fábrica → userspace vendor → sistema cubegm/).
5. **Vuelta desplegada** — `to_own --folder --bundle-dir kernel-switch/sets/20261001T004028Z`: par nuestro (post-verify PASS) + `cubegm/` → `kernel-switch/folders/cubegm-stock-20261001T004643Z/` (move + manifest 2248 archivos). Sets rotados (conservados: 215800Z=stock, 004028Z=nuestro, 004641Z=stock). Boot de cierre pendiente del usuario → round-trip PASS.

## Red de seguridad (verificada en cada paso)

- `orig/` = par de fábrica (recovery point del primer uso, nunca rotado)
- `sets/` ×3 (pares stock/nuestro rotativos, manifests verificados)
- `folders/cubegm-stock-20261001T004643Z/` = sistema stock completo (manifest verificado)
- `D:\R36SX\staging\` = kernel propio externo (44a1af3e + 116ddf26, copias hash-verificadas)
- BootROM-USB siempre disponible (DDR-init fábrica intacto)

## Hallazgos técnicos (canonizados)

1. **`sha256sum -c` ignora silenciosamente líneas con formato inválido** (improperly formatted → WARNING + skip; exit 0 aunque la línea del archivo crítico esté corrompida) → verificación estricta por-archivo (hex-64) ANTES de `-c` y de escribir (selftest T8/T8b).
2. **"insert tf card"** = mensaje del bootloader de fábrica (nuestro binario es fábrica+7B) cuando el path-prefix no existe en la SD — evidencia de diagnóstico rápido para usuarios finales.
3. Selftest flaky: `cut -c1 FILE` devuelve el primer carácter de CADA línea (multiline) → decisiones equivocadas con fixtures aleatorias; `head -c1` para el byte exacto.

## Artefactos

- Scripts: `scripts/kernel_to_own.sh` · `kernel_to_stock.sh` · `kernel_switch_status.sh` · `kernel_switch_lib.sh` (v2, HOST PASS 90/90)
- Selftest: `tests/kernel_switch_selftest.sh` (23 grupos / 90 checks)
- Goldens: `manifests/GOLDEN_STOCK.sha256` (53b3e0b3 / 1258f1eb / a9788995)
- Bases canónicas (ADR-016): Desktop "R36SX V2.6 (0712) Minimal Backup" (stock) · SD viva (propio)

**Pendiente:** boot de cierre del usuario (vuelta a SO propio) → round-trip PHYSICAL PASS → Fase E física completa. Después: E5 (UX usuario final + `docs/RECOVERY.md`) y CLEAN-INSTALL sobre una consola stock de terceros.
