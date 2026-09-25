# Fase D — F1: firmware AVP propio (research + primer build)

**Fecha:** 2026-09-25
**Clase:** D (GO del usuario recibido para la fase)
**Contexto:** overlay azul del AVP con networking activo — ineludible por software (docs/experiments/2026-09-25_9-6d-visual-blue-daemon.md). Única vía: AVP propio en `cubegm/avp.uImage` (SD-deployed, rollback trivial).

## Research (evidencia)

1. **Workspace**: `~/work/r36sx-hclinux/avp-build/` = worktree git del submodule
   `SOURCE/avp` del SDK (HCRTOS del coprocesador; stock, sin cambios locales).
   Contiene builds previos sin documentar del 17-09 (`avp-own-9b/9e.uImage` —
   flujo de build validado, nunca deployado).
2. **El AVP de fábrica** (`a9788995`, descomprimido 2.6 MB): strings revelan
   build `avp-custom` de `linsen.chen` para `E3100_R36` — **fork interno de
   Hichip que NO está en el SDK**. Sin strings de hudi/usbcast/hccast.
   Pila de red newlib presente (sockets).
3. **Handlers de decode del AVP**: el avp-own usa **PREBUILTS cerrados y
   ofuscados** (`BR2_PACKAGE_PREBUILTS_AUDDRIVER/VIDDRIVER=y` + plugins
   mp3/aac/h264/...). Los `_IOW` de AUDDEC/VIDDEC en el binario 96f son la
   **ABI vieja (0x82600301/0x82840400 = 608/644)** — los prebuilts del SDK
   Jul-2024 no traen los structs Dic-2025 (632/664) que el userspace de
   fábrica envía. Los pads aplicados al hcuapi del AVP NO afectan a los
   prebuilts (binarios ya compilados).
4. **Dispatch**: la cadena ABI completa es
   `libhudi.so (fábrica) → /dev avp-proxy (kernel, pads 9001/9002 = acepta
   632/664) → AMPRPC → AUDDRIVER/VIDDRIVER prebuilt del AVP (espera 608/644)`.

## Camino técnico (fases)

- **F1 — primer boot del avp-own**: `avp-own-96f.uImage` (`be57d381`,
  1.240.901 B, load/entry 0x8bda4000 == formato golden) = SDK stock +
  pads ABI en headers (inofensivos) + config apps-avp/prebuilts
  (kernel+amprpc+fb+decoders prebuilt, SIN apps extra). Deploy con backup
  del golden en SD. Validar: boot, panel, fb del menú, RPC básico.
  Riesgo: si el avp-custom de fábrica maneja el panel/display de forma no
  replicada → pantalla muerta → rollback inmediato (SD en lector).
- **F2 — audio/video**: traducción de ABI en el avp-proxy del KERNEL
  (nuestro código): aceptar 632/664 del userspace de fábrica y reenviar
  608/644 al AVP-own (inverso del patrón 9l; solo AUDDEC_INIT/VIDDEC_INIT
  cargan los structs grandes). Patch kernel propio nuevo (0006/9006).
- **F3 — el overlay azul**: con el avp-own corriendo, activar NCM y
  verificar si el trigger del azul (vive en el avp-custom) desaparece
  → requisito completo: red viva + pantalla normal.

## Artefactos

- `patches/avp/0001-auddec-abi-2025-padding-24B.patch`,
  `patches/avp/0002-vidmp-abi-2025-padding-20B.patch` (canónicos; aplicados
  al árbol `SOURCE/avp` — documentan la ABI aunque los prebuilts no los usen).
- `avp-build/output/images/avp-own-96f.uImage` (be57d381) + `avp.bin` (2.158.144 B).
- Nota de proceso: el make incremental del avp-build NO propaga cambios de
  headers → rebuilds con `rm -rf output/{build,staging}` (config resguardado).
