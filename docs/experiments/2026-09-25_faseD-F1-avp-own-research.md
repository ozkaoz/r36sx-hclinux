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

---

# ADDENDUM F1b-RESULT (2026-09-25, cierre de sesión)

- **Kernel-test sin canal AVP: NO VIABLE** — el hcfb (framebuffer del menú)
  depende de mmz + avp-proxy (mmz_memalign / avp_work_notifier_*): sin el
  canal no hay fb. Vía descartada.
- **Test solo-AVP (kernel fuera del boot): REBOOT-LOOP IGUAL** → el avp-own
  (96g, con CONFIG_DRV_WDT=y) **ni siquiera arranca sin kernel** → el
  problema es fundamental del boot del avp-own: el bootloader de fábrica
  no lo acepta/arranca, o muere al inicio. Pendiente: entender el flujo de
  carga del avp.uImage por el bootloader (¿validación? ¿formato custom del
  avp-custom? ¿entry/ddr-init-dependencia?).
- **Consola restaurada a known-good**: kernel `e45547a2` + AVP golden
  `a9788995` + dtb `116ddf26` (verificado). Fase D: PAUSADA como
  investigación del boot-AVP (los artefactos avp-own 9b/9e/96f/96g quedan
  preservados en avp-build/output/images).
- **Limpieza de disco (petición del usuario)**: liberados ~38 GB dentro del
  VHDX de WSL (D:\WSL\Ubuntu-24.04): builds 4.4.186 (r36sx-v26, superseado),
  baseline d3100-v20 (regenerable), KERNEL_BUILD pre-proyecto (19 GB,
  SDK duplicado), patch-audit interno (regenerable), avp-build build+staging
  (regenerable), mtp_kernel (pre-eliminación). Conservados: k512 (activo),
  SDK maestro, artifacts, avp-build/images. Compactación física del VHDX:
  pendiente (requiere fstrim sudo + diskpart elevado; opcional).

---

# ADDENDUM F1c+F2 (2026-09-29 — clase D retomada: BOOT DEL AVP-OWN RESUELTO; display gap mapeado; pivot a vía 3)

## F1c — el misterio del boot RESUELTO: el TIPO del uImage

mkimage -l del golden reveló: **"MIPS U-Boot Standalone Program"** vs los
avp-own 96f/96g = **"MIPS Linux Kernel Image"** (el build F1 empaquetó por
otra vía con el tipo incorrecto; el SDK sí usa -T standalone en
post-build.sh:156/162). Mismo load/entry 0x8bda4000.

**avp-own-96h** (129f8e2a) = el binario 96g (CONFIG_DRV_WDT=y) reempaquetado
con la convención exacta de fábrica: **SIN REBOOT-LOOP**. Físico: el kernel
arranca (S09trace, hcdaemon, rpcwork0-7 vivos a los 00:00:04 — log.txt),
la pantalla muestra el logo (del bootloader) y la consola permanece viva.
El WDT ya no mata (el 96g con el feed correcto) y el formato era el
co-asesino con el timing exacto de F1.

## F2 — traducción ABI implementada (0006/9006)

- Los pads 9001/9002 son **campos finales** (auddec.h:103 [24B],
  vidmp.h:208 [20B]): el struct legacy == los primeros 608/644 bytes del
  padded → basta reescribir la palabra de comando; _IOC_SIZE redimensiona
  el payload en ambas direcciones.
- Patch 0006 (canonico en patches/buildroot/linux/): fwd_cmd = _IOC(...,608)
  para AUDDEC_INIT / _IOC(...,644) para VIDDEC_INIT en avp_ioctl_unl (solo
  el reenvio; los switches locales siguen matcheando la palabra del userspace).
- Aplicado al arbol + rebuild: kernel 722ce8ce (TOOLCHAIN+PATCH PASS).
- **REGLA CRITICA aprendida**: kernel F2 + AVP golden INCOMPATIBLES (el golden
  ESPERA 632/664 de fabrica; el F2 reenviaria 608/644). El rollback SIEMPRE
  debe restaurar AMBOS archivos juntos.

## F2-test fisico: el menu no llega — crash-loop del frogui

- frogui_crash.log (41.764 B): **retro_init complete x133** — el frontend
  inicializa COMPLETO (render_init, scan_directory, theme...) y cruza al
  momento de renderizar el menu → el supervisor lo relanza → loop.
- picoarch_init.log: instancias repetidas con **geometrias fb corruptas**
  (v640x11040 bpp=16!) — los ioctls hcfb devuelven exito con valores basura.
- game_history.txt: ultima entrada con paths cubegm (era del boot-resume).

## CONCLUSION (la frontera exacta)

El gap NO era solo la ABI de 2 comandos: **el stack de display de fabrica
depende de los servicios de composicion/fb del avp-custom** (fork interno
linsen.chen E3100_R36, fuente NO en el SDK) que el avp-own del SDK no
replica. El menu nunca renderiza con el avp-own. Boot: RESUELTO. Display:
bloqueado en compatibilidad de servicios.

## LAS 3 VIAS RESTANTES (eleccion: via 3)

1. **Patch binario del golden** — RE dirigido del trigger del azul (firma
   06 f2 / rgb:ff0000ff / ~30s) + NOPs. Conserva TODO el stack de fabrica.
2. **Completar el display del avp-own** — RE de los servicios fb del golden
   o reescribir el userspace de display. Multi-sesion, alto costo.
3. **[ELEGIDA] Cazar el canal de monitoreo** — el avp-custom detecta el
   networking por ALGUN canal (amprpc/memoria compartida/hcdaemon). El
   patch 9003 (amprpc_dbg) YA vive en el kernel desplegado 5adde850:
   sesion NCM + overlay activo + dmesg | grep amprpc → identificar el RPC
   del trigger → patch kernel que presenta estado "sin red" al AVP.

## Rollback ejecutado (2026-09-29)

kernel 5adde850 + AVP golden a9788995 + adb.mode (canal ADB completo) =
known-good verificado. Backups en boot/: prev-5adde.bak, golden.bak,
prev-96f.bak (c6e3cc70), prev-d3.bak.
