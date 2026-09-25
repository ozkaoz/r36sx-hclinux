# Fase D-2b-v2: NOR-DTB del bootloader = FÁBRICA + path-prefix boot (defecto de raíz corregido)

**Fecha:** 2026-09-25 (noche)
**Contexto:** el flash D-2c-v1 (HCFOTA-own, staging 1734c340) instaló OK por
HCProgrammer pero la consola no dio pantalla; recovery factory OK (método
dominado). Diagnóstico: el NOR-DTB embebido de nuestro hcboot NO era el de
fábrica (2.685 líneas de diff — era el DTS de proyecto regenerado): el panel
no se inicializa. Misma causa raíz de los brickeos históricos #1/#2.

## Causa técnica

`boot/hcboot/hcboot.mk` (SDK) **pisa el DTS del bootloader con el del kernel**
(`BR2_LINUX_KERNEL_CUSTOM_DTS_PATH`) en el configure y en el make: el
defconfig del bl (`CONFIG_CUSTOM_DTS_PATH`) es ignorado → el hcboot siempre
embebió el DTS del proyecto. Además el fragment del kernel quedó con el
bloque de test F1b-TEST (canal AVP off) del experimento del avp-own —
detectado porque el kernel del build falló con `undefined reference:
avp_work_notifier_*/mmz_*` (hcfb depende de mmz+avp_proxy).

## Correcciones (todas canonizadas)

1. **Fragment del kernel**: bloque F1b-TEST eliminado (repo + SDK) →
   kernel de producción (e45547a2-equivalente) de vuelta.
2. **`patches/sdk/hcboot.mk.decoupled` + `Config.in.hcboot-dtspath`** (y
   aplicados al SDK workspace): nueva variable `BR2_TARGET_HCBOOT_DTS_PATH`
   desacopla el DTS del bootloader del kernel (3 referencias en el mk).
3. **`boards/r36sx-v26/bootloader/r36sx-v26-bl-nordtb.dts`** (también en el
   SDK board-dir): **round-trip byte-fiel del `factory-nordtb-0.dtb`**
   (dtc 1.6.0 del SDK: decompile→recompile == fábrica BYTE-EXACTO,
   verificado) con UN único cambio: `path-prefix = "cubegm"` → `"boot"`,
   + `#define HCRTOS_BOOTMEM_OFFSET 0x09da0000` (la macro que el flujo
   load-addr del apps-bootloader espera; el dts de proyecto la traía de
   includes del kernel, el round-trip no).
4. **`r36sx-v26_bl_defconfig`**: CONFIG_CUSTOM_DTS_PATH/DEFAULT_DEVICE_TREE
   → bl-nordtb (informativo; el mk ahora respeta la variable nueva).
5. **defconfig k512 (repo+SDK)**: `BR2_TARGET_HCBOOT_DTS_PATH` → bl-nordtb.dts.
6. Nota de proceso: el sync del bl-defconfig al SDK sigue siendo manual
   (deuda menor: integrar en build_kernel.sh).

## GATE 9a-v2 — PASS (la garantía máxima alcanzable)

- bootloader.bin nuevo: `3cf0a8c1` (425.008 B; DDR-init fábrica + hcboot).
- NOR-DTB embebido: **32.944 B == tamaño fábrica**; decompilado y comparado:
  **diff = UNA SOLA LÍNEA** (`path-prefix "cubegm"` → `"boot"`) — el
  panel/pinmux/UART/clocks son byte-fábrica.

## Artefactos de flasheo (listos)

- staging: `D:\R36SX\staging\bootloader-r36sx-v26-faseD2c-v2.bin`
  (442.368 B con padding 0xFF, sha `19c6f7f0…`).
- firmware: `D:\R36SX\hcprogrammer-own-kit\HCFOTA-own-v2.bin`
  (988.648 B, sha `5cabb831…`; versión 2609250002; CRCs del formato HCFOTA
  recalculados y re-check PASS; boot embebido == staging verificado).
- Protocolo: mismo HCProgrammer que el v1 (que instaló OK) — Firmware
  select = HCFOTA-own-v2.bin. Recovery factory disponible e intacto.
