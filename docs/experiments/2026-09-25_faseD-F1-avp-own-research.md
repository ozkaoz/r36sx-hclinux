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

---

# ADDENDUM F1 RESULT (cierre 2026-09-25)

- Boot físico con avp-own-96f (`a02681a9`): **AVP-own ARRANCÓ** (consola
  virtuart viva `hc1600a@dbE3100v20#`, panel DTS leído 640x480, display_init,
  audio `CFG 48K`, último print `rgb: ff0000ff` = display-clear AZUL — la
  firma del overlay). Kernel muere pre-S09trace → **reboot-loop** (candidato:
  watchdog de la cadena kernel/hcdaemon↔AVP sin servicio en el avp-own).
- **Rollback ejecutado**: `cubegm/avp.uImage` = golden `a9788995`; kernel
  `e45547a2` y dtb `116ddf26` intactos. Consola known-good.
- Plan F1b: (1) console=virtuart en bootargs del DTB (captura temprana
  kernel); (2) servicio watchdog del lado AVP; (3) explorar
  `D:\R36SX\hclinux-builds` por el avp-custom; (4) reiterar F1→F2→F3.

---

# ADDENDUM F1b (2026-09-25, segunda parte)

- **CAUSA RAÍZ del reboot-loop identificada**: el WDT del SoC lo feedea el
  AVP (nuestro kernel Linux tiene `CONFIG_HC_WDT is not set`) y el avp-own
  96f compiló SIN el driver (`CONFIG_DRV_WDT` not set) → nadie feedea → vence
  a ~10 s → reboot-loop. Timing consistente con el test físico.
- **Fix 96g**: `CONFIG_DRV_WDT=y` en el config del avp-build. Regla de
  proceso del avp-build aprendida: editar `output/.config` → `make
  syncconfig` (regenera `br2_autoconf.h`; el make incremental NO lo hace
  solo) → `rm output/build/kernel` → `make`.
- **avp-own-96g.uImage** = `fa037e15` (1.181.219 B; watchdog.o presente,
  avp.bin +4.624 B). Pendiente: ciclo físico F1b (boot test con WDT feed).
