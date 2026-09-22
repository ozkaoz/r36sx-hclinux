# docs/BOOT_CHAIN.md — Cadena de boot R36SX V2.6 (CONFIRMADA)

**Evidencia completa:** `docs/SDK_AUDIT.md` §boot-chain · `docs/ARCHITECTURE.md`. Toda dirección citada abajo tiene ruta de evidencia allí.

## Secuencia (evidencia SDK + manual cross-checkeado)

1. **BootROM** HC16xx → lee bloque **DDR-init** desde NOR (`hc16xx_ddr3_128M_1066MHz.abs`, 12,288 B físicos) e inicializa DDR.
2. BootROM carga **bootloader.bin** = `cat ddrinit u-boot.bin` (post-build.sh:216).
3. **u-boot/hcboot** (compilado desde `SOURCE/avp/components/applications/apps-bootloader`):
   - Inicia **AVP primero**: `avp.uImage` (uImage tipo standalone, Load=Entry=`0x8BDA4000`, gzip/lzma/lzo).
   - Entrega el DTB del AVP vía registro **`0xb8800004`** (main.c:620).
   - Luego `bootm` **Linux**: `vmlinux.uImage` (stock R36SX: Load `0x80000000`, Entry `0x803EC710`), DTB en **`0x85ff0000`** (AutoRun0=`wm 0xb8800004 0x85ff0000`, post-build.sh:125+).
4. **Linux 4.4.186** en core-main; **HCRTOS/AVP** en core-AVP; comunicación **AMPRPC** (amprpc/avp-proxy/kshm), memoria media **MMZ**.

## Direcciones clave (todas con evidencia — tabla comparativa Fase 4)

| Elemento | STOCK (fábrica) | D3100 baseline | R36SX-V26 build (Fase 4B) | Evidencia |
|---|---|---|---|---|
| Linux load | `0x80000000` | `0x80000000` | `0x80000000` | uImage headers ×3 |
| Linux entry | `0x803337c0` (config fábrica, no en SDK) | `0x803e3200` | **`0x803e3200`** (== baseline; config vendor SDK) | uImage headers + readelf |
| DTB address | `0x85ff0000` | idem (pipeline) | idem (DTB idéntico al stock) | post-build.sh:125+ |
| Linux memory | `0x0 + 0xAF91E50` (175.57 MiB) | `0x0 + 0x4F32E40` (79.20) | **`0x0 + 0xAF91E50` (== stock)** | DTB memory node + compare gate |
| AVP load/entry | `0x8BDA4000` | n/a (AVP off) | n/a (AVP stock preservado) | uImage stock SD + ADR-008 |
| AVP sysmem | `0xBDA2E50 + 0xB53600` | `0x4F32E40 + 0xB53600` | **`0xBDA2E50 + 0xB53600` (== stock)** | DTB hcrtos + compare gate |
| AVP entry verificado | sysmem stock +0x1000 → `0x8BDA4000` = entry real avp.uImage stock ✓ | — | — | DTS_STOCK_MODEL §verificación macros |
| FB static | `0xAF91E50 + 0xE11000` | n/a (system) | **== stock** | DTB fb0 |
| mmz0/mmz1 | `0xCDA2E50+0x325D1B0` / `0xC8F6450+0x4ACA00` | otros | **== stock** | DTB hcrtos |

**Diferencia residual documentada (no del DTS):** entry/data-size del kernel stock provienen del config interno del fabricante (no incluido en SDK); nuestro build replica el config vendor SDK. DTB entregado al bootloader = idéntico al stock.

## Zona prohibida (AGENTS.md §5, ADR-005)

DDR-init, bootloader, AVP: **intocables en baseline**. Clase D requiere autorización explícita. Deploy físico (Fase 5): solo reemplazo de `vmlinux.uImage` (+`dtb.bin`) en SD — la consola bootea desde SD (NOR 3 particiones: boot/eromfs/persistentmem — docs/DTS_STOCK_MODEL.md).

## Ownership de la cadena (verificado 2026-09-18 — post 9m PHYSICAL PASS)

Estado del deploy físico actual (SD de la consola) — qué es NUESTRO vs qué es de fábrica/upstream:

| Componente | Propiedad | Evidencia |
|---|---|---|
| **Kernel Linux (vmlinux.uImage)** | **100% NUESTRO** — vanilla 4.4.186 + linux-drivers SDK + 45 parches vendor + parches propios (canon `patches/buildroot/linux/0001..0004`, sync 900X al SDK — ADR-014: ABI 2025 auddec/vidmp + debug budgets), compilado con Codescape mips-mti-linux-gnu 6.3.0 | BUILD PASS 9m `1b095ac8`; gates TOOLCHAIN+PATCH PROVENANCE PASS; build logs `~/work/r36sx-hclinux/logs/` |
| **DTB (dtb.bin)** | **NUESTRO** — generado desde `boards/r36sx-v26/dts/` (referencia stock auditada) | `04fb8383…`, DTB SEMANTIC PASS 0-diff vs stock |
| **Rootfs/initramfs embebido (rootfs-own.cpio)** | **NUESTRO** — Buildroot propio: busybox nuestro + glibc Codescape + overlay propio (rcS/S09trace/S10mdev/S41hcdaemon/S99app). Única pieza propietaria: `hcdaemon` de fábrica (610.404 B, documentada, ADR-008-nota) | `e305dfc2…`; 8a-8c PHYSICAL PASS |
| **AVP/HCRTOS (avp.uImage)** | **FÁBRICA** — preservado POR DISEÑO (ADR-008; estrategia proxy-side ADR-012, no reemplazo). avp-own construido y archivado como plan C | SD `a9788995…` == `avp.uImage.factory.bak` |
| **DDR-init + bootloader.bin** | **FÁBRICA** — NOR intocado, nunca re-flasheado (zona prohibida §5) | N/A (nunca escrito) |
| **TreeFrogUI stack (cubegm/: picoarch, frogui_libretro, driver_r36sx.so, video_player…)** | **UPSTREAM (tzubertowski/TreeFrogUI)** — binarios del release v1.5.0 del ecosistema, no fábrica-R36SX ni nuestros | mtimes 2026-09-16, hashes TreeFrogUI release |
| **Librerías del rootfs de fábrica en SD (rootfs/lib+usr, libffplayer/libhudi…)** | **FÁBRICA** — usadas por los media apps de fábrica; el ABI contra ellas es el que alineamos (ADR-012) | scan lui+ori (experimento 9m) |

**Conclusión (verificada):** TODO el kernel — código fuente, toolchain, config, DTB y rootfs embebido — es nuestro y reproducible desde `SDK + este repo` (§4 AGENTS.md). Los binarios de fábrica que quedan en el camino de boot son SOLO: DDR-init/bootloader (NOR), AVP y las apps/libs de fábrica en SD — los tres deliberadamente preservados; el kernel que ejecuta Linux es 100% construido por nosotros.
