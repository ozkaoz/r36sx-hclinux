# DECISIONS.md — Decisiones arquitectónicas durables

Formato ADR. STATUS: ACTIVE | SUPERSEDED | DEPRECATED. No registrar aquí nada mutable (eso va a CURRENT.md).

---

## ADR-001 — Desarrollo WSL-only

- **DATE:** 2026-09-14
- **STATUS:** ACTIVE
- **SCOPE:** todo el proyecto
- **CONTEXT:** toolchains MIPS/Buildroot requieren Linux nativo; WSL2 Ubuntu 24.04 disponible con gh, gcc, make, dtc, 7z verificados; Windows solo aporta datos en `/mnt/d`.
- **DECISION:** todo desarrollo, builds, Git/GitHub y generación de artefactos se ejecuta desde WSL. Rutas Windows son solo fuentes de datos. Literal en AGENTS.md §0.
- **RATIONALE:** permisos Unix, symlinks, velocidad de filesystem, compatibilidad Buildroot/toolchain, cuenta `gh` ya configurada.
- **CONSEQUENCES:** todo script es bash; el repo vive en filesystem nativo WSL (`~/projects/r36sx-hclinux`), nunca en `/mnt/d`.
- **EVIDENCE:** preflight 2026-09-14 (WSL2 kernel 6.18.33.2, Ubuntu 24.04.4, git 2.43, gh 2.96, gcc 13.3, make 4.3, dtc, 7z presentes).
- **RELATED:** AGENTS.md §0, docs/ai/BUILD_CONTRACT.md

## ADR-002 — SDK vendor inmutable como fuente de verdad

- **DATE:** 2026-09-14
- **STATUS:** ACTIVE
- **SCOPE:** gestión de fuentes
- **CONTEXT:** `/mnt/d/GitHub/KERNEL` contiene el SDK HCLinux completo (2.0 GiB) + manuales + patches + hcdrivers; es evidencia vendor irrepetible.
- **DECISION:** el SDK y todos los archivos de `/mnt/d/GitHub/KERNEL` se tratan como evidencia inmutable: nunca se modifican ni se desarrolla dentro. Workspace derivado en `~/work/r36sx-hclinux/{sdk,build,cache}`. Los cambios propios viven en este repo como patches/configs/boards/overlays.
- **RATIONALE:** reconstrucción garantizada desde SDK ORIGINAL + este repo; trazabilidad de evidencia; el repo previo homónimo murió por contaminar workspace y fuentes.
- **CONSEQUENCES:** `prepare_sdk.sh` siempre extrae desde el tar original verificado por SHA256; artefactos grandes viven en `out/` (ignorado).
- **EVIDENCE:** SHA256 SDK `e3211b41...45fbf8d5d` (manifests/SOURCES.sha256); inventario completo docs/SOURCE_INVENTORY.md.
- **RELATED:** AGENTS.md §4, scripts/prepare_sdk.sh, scripts/verify_sources.sh

## ADR-003 — Reinicio limpio sin herencia técnica

- **DATE:** 2026-09-14
- **STATUS:** ACTIVE
- **SCOPE:** historia del proyecto
- **CONTEXT:** existió un repo `r36sx-hclinux` previo (WSL local + remoto GitHub) eliminado el 2026-09-14; su historial completo quedó preservado en bundles.
- **DECISION:** este proyecto arranca desde CERO sin reutilizar código, docs, configs ni historia del repo previo. El bundle preservado es solo red de seguridad, no antecedente técnico. Decisión explícita del usuario: "no partas de ningún repo previo", "todo el trabajo debe ser nuevo".
- **RATIONALE:** partir de cero evita arrastrar decisiones y errores no re-evidenciados; todo lo que se necesite debe re-derivarse del SDK con evidencia propia.
- **CONSEQUENCES:** cualquier afirmación técnica de este repo cita evidencia nueva de `/mnt/d/GitHub/KERNEL` o del SDK extraído. Bundles legacy: `Temp\opencode\bundles-20260914\` (solo recuperación).
- **EVIDENCE:** bundles `r36sx-hclinux.bundle` + `r36sx-hclinux-legacy-unpushed-255f7cd-20260914.bundle` (historial completo verificado); repos remotos ozkaoz listados (sin r36sx-hclinux).
- **RELATED:** CURRENT.md KNOWN-GOOD STATE

## ADR-004 — Linux 4.4.186 como baseline; 5.12.4 experimental diferido

- **DATE:** 2026-09-14
- **STATUS:** ACTIVE (pendiente de confirmación por auditoría SDK — Fase 1)
- **SCOPE:** kernel
- **CONTEXT:** `/mnt/d/GitHub/KERNEL` contiene sets de patches vendor para linux-4.4.186 (41 patches) y linux-5.12.4 (21 patches); el requisito del proyecto fija 4.4.186 como baseline si el SDK lo confirma.
- **DECISION:** baseline = Linux 4.4.186. La línea 5.12.4 se abre solo cuando 4.4.186 sea known-good físico. 4.4.186 = GOLDEN; 5.12.4 = EXPERIMENTAL.
- **RATIONALE:** minimizar variables; el firmware stock del R36SX V2.6 debe ser el punto de compatibilidad inicial.
- **CONSEQUENCES:** Fase 9 diferida; cada regresión 5.12 se compara contra 4.4.
- **EVIDENCE:** directorios `linux-4.4.186/` (41 .patch) y `linux-5.12.4/` (21 .patch) en /mnt/d/GitHub/KERNEL — verificación del contenido del SDK tar pendiente en Fase 1.
- **RELATED:** docs/SDK_AUDIT.md (pendiente), docs/ROADMAP.md

## ADR-005 — AVP/HCRTOS preservado durante baseline

- **DATE:** 2026-09-14
- **STATUS:** ACTIVE
- **SCOPE:** boot/AVP
- **CONTEXT:** el firmware stock ejecuta HCRTOS/AVP en un segundo núcleo con AMPRPC como puente; audio/DDR/display dependen de él (hipótesis a confirmar en Fase 1).
- **DECISION:** durante Fases 0–6 el AVP se preserva intacto: no se modifica bootloader, DDR init, ni AVP. Un solo cambio principal por experimento.
- **RATIONALE:** riesgo de brick y pérdida de funciones críticas; "una variable por experimento".
- **CONSEQUENCES:** clase de cambio D (boot/AVP) requiere autorización hardware explícita.
- **EVIDENCE:** hcdrivers/amprpc/, hcdrivers/avp-proxy/ presentes en /mnt/d/GitHub/KERNEL (confirmación del mecanismo completo: Fase 1).
- **RELATED:** AGENTS.md §5, §7; docs/ai/HARDWARE_SAFETY.md

## ADR-006 — Repositorio GitHub público

- **DATE:** 2026-09-14
- **STATUS:** ACTIVE
- **SCOPE:** repositorio
- **CONTEXT:** proyecto open-source de ingeniería reproducible; nombre `r36sx-hclinux` libre en GitHub (verificado via gh).
- **DECISION:** repo público `ozkaoz/r36sx-hclinux`, rama `main`, español como lengua de trabajo, inglés en README público.
- **RATIONALE:** visibilidad, journal técnico autoritativo, referencia a referencias públicas (ArkOS, TreeFrogUI, R36S V2.6 Wiki).
- **CONSEQUENCES:** sin binarios vendor gigantes en git; artefactos vía manifests + releases futuros.
- **EVIDENCE:** `gh repo view ozkaoz/r36sx-hclinux` → not found (2026-09-14); lista de repos ozkaoz sin conflicto.
- **RELATED:** docs/ai/RELEASE_CONTRACT.md

## ADR-007 — d3100_v20 como vendor baseline provisional (NO identidad final de board)

- **DATE:** 2026-09-14
- **STATUS:** ACTIVE
- **SCOPE:** build vendor de referencia
- **CONTEXT:** Fase 2 requería reproducir un build vendor conocido. El manual §16.1 usa `hichip_hc16xx_db_d3100_v20_defconfig` como ejemplo canónico; la evidencia física del DTB stock de la consola revela `board label = "hc1600a@dbE3100v20"` (E3100 — board inexistente en el SDK).
- **DECISION:** `d3100_v20` es el **VENDOR BASELINE CANDIDATE (CONFIDENCE: HIGH)** para reproducir el pipeline del fabricante. **FINAL BOARD IDENTITY: NOT YET PROVEN** — la board real es familia E3100 v20; los artefactos d3100_v20 NO se consideran compatibles con la consola real (memoria/display divergen) y **jamás se flashean** en la R36SX.
- **RATIONALE:** el pipeline (toolchain, patches, DTS plumbing, post-build) es común a la familia; solo la board difiere. El vermagic stock del fabricante usa el mismo toolchain Codescape 2018.09-02 que nuestro build → validación fuerte del pipeline.
- **CONSEQUENCES:** Fase 4 (board propia `r36sx-v26`) es obligatoria y deriva del DTB stock decompilado; todo build d3100_v20 queda etiquetado solo como referencia de pipeline.
- **EVIDENCE:** docs/experiments/2026-09-14_vendor-baseline-d3100-v20.md; docs/HARDWARE_R36SX_V26.md; DTB stock sha `1258f1eb...`.
- **RELATED:** ADR-003, ADR-004, docs/SDK_AUDIT.md

## ADR-008 — Baseline kernel-only (HCBOOT/AVP deshabilitados en build)

- **DATE:** 2026-09-14
- **STATUS:** ACTIVE
- **SCOPE:** alcance del build baseline
- **CONTEXT:** compilar hcboot/AVP requiere toolchain bare-metal `mips32-mti-elf` (Codescape 2019.09-03-2) distribuido solo vía GitLab privado de HiChip (requiere login; `/opt/mips32-mti-elf` local es symlink roto a directorio inexistente). En la consola real, AVP/bootloader stock se preservan siempre (ADR-005): no los reemplazamos.
- **DECISION:** el baseline (y builds de Fases 4-5) compilan **kernel + DTB + rootfs** con `BR2_TARGET_HCBOOT` y `BR2_PACKAGE_AVP` off en el .config del output (defconfig vendor intacto). Los artefactos de flasheo que requieren bootloader.bin quedan fuera de alcance hasta obtener el bare-metal o decisión explícita del usuario.
- **RATIONALE:** una variable por experimento; el AVP stock ya funciona en el dispositivo; sin bare-metal no hay alternativa honesta.
- **CONSEQUENCES:** `target-post-image` fallará al final (bootloader.bin ausente) — error esperado y documentado; los artefactos del kernel se generan antes. Si en el futuro se obtiene el bare-metal, reevaluar.
- **EVIDENCE:** error build literal: `Toolchain /opt/mips32-mti-elf/2019.09-03-2/bin/mips-mti-elf-gcc not exist`; GitLab HiChip pide login (HTML 8331B); experimento 2026-09-14.
- **RELATED:** ADR-005, docs/BUILD.md

## ADR-009 — Gates de provenance como parte del gate C

- **DATE:** 2026-09-14
- **STATUS:** ACTIVE
- **SCOPE:** validación de builds de kernel
- **CONTEXT:** Fase 2.5 (requisito del usuario) demostró que "presence ≠ use" para toolchains y patches; la prueba primaria es la invocación registrada (.cmd de kbuild, patch log, árbol resultante) y "vermagic ≠ toolchain identity". Se crearon gates reproducibles.
- **DECISION:** todo build de kernel (clase C) debe pasar `scripts/audit_toolchain.sh` (TOOLCHAIN PROVENANCE: PASS) y `scripts/audit_kernel_patches.sh` (PATCH PROVENANCE: PASS) antes de considerarse apto para la fase siguiente. Regla permanente en AGENTS.md §14.
- **RATIONALE:** evita suposiciones de provenance en builds futuros; los gates son read-only, idempotentes y automáticos.
- **CONSEQUENCES:** el gate C queda: config validation + kernel build + DTB validation + audit_toolchain + audit_kernel_patches.
- **EVIDENCE:** ambos gates PASS sobre el baseline d3100_v20 (experimento docs/experiments/2026-09-14_fase25-provenance-audit.md).
- **RELATED:** AGENTS.md §14, docs/TOOLCHAIN_PROVENANCE.md, docs/PATCH_PROVENANCE.md

## ADR-010 — r36sx-v26: board stock-equivalent con DTS verbatim y allowlist cero

- **DATE:** 2026-09-14
- **STATUS:** ACTIVE
- **SCOPE:** board propia / DTS
- **CONTEXT:** Fase 4 demostró que el DTB stock decompilado es semánticamente reproducible (roundtrip PASS) y que el pipeline SDK compila DTS con macros (gcc -E + dtc). El DTS de la board propia se ensambla por script desde la referencia auditada, no editado a mano.
- **DECISION:** la board `r36sx-v26` usa como DTS el **cuerpo stock-normalized verbatim** + encabezado de macros con los valores exactos del mapa stock (docs/DTS_STOCK_MODEL.md). El gate `scripts/compare_dtb_semantics.sh` exige **allowlist de diferencias = 0** contra el stock; cualquier desviación futura (optimización) requiere entrada en la allowlist documentada + ADR + evidencia.
- **RATIONALE:** stock equivalence primero (requisito Fase 4); DTS editado a mano reintroduce riesgo de divergencia silenciosa del hardware description; el ensamblado por script es reproducible y auditable (make_board_dts.sh).
- **CONSEQUENCES:** modificar el DTS = modificar la referencia o el ensamblador — siempre por script + gate. Los archivos fuente del repo son la única fuente de verdad (build_kernel.sh sincroniza al workspace SDK).
- **EVIDENCE:** experimento 2026-09-14_r36sx-v26-board.md (DTB SEMANTIC PASS 0 diff; dtb.bin == stock roundtrip byte-idéntico `04fb8383...`).
- **RELATED:** ADR-007, docs/DTS_STOCK_MODEL.md, docs/R36SX_D3100_DELTA.md, scripts/{make_board_dts,compare_dtb_semantics,build_kernel}.sh

## ADR-010 — r36sx-v26: board stock-equivalent con DTS verbatim + allowlist cero

- **DATE:** 2026-09-14
- **STATUS:** ACTIVE
- **SCOPE:** board propia / DTS
- **CONTEXT:** Fase 4A demostró que el DTB stock decompilado es reproducible (roundtrip SEMANTIC PASS) y autoritativo (jerarquía Fase 4 del usuario); la alternativa "híbrido con includes vendor" introduciría riesgo de desviación silenciosa del hardware stock.
- **DECISION:** el DTS de `r36sx-v26` se genera por `scripts/make_board_dts.sh` = encabezado con macros del sistema SDK (CONFIG_MEMORY_SIZE/LINUX_MEMORY_SIZE/SYSMEM_OFFSET con valores stock exactos) + cuerpo `reference/stock-normalized.dts` VERBATIM. NO se edita a mano. Gate obligatorio: `scripts/compare_dtb_semantics.sh` debe dar **0 diferencias vs stock** (allowlist vacía). Cualquier desviación futura intencional requiere: entrada en la allowlist del script + evidencia + ADR propia.
- **RATIONALE:** stock-equivalence verificable > elegancia de includes; el pipeline vendor (fixup-load-addr vía gcc -E) queda satisfecho con las macros del encabezado; reproducibilidad total (DTS derivado de referencia auditada, regenerable con un comando).
- **CONSEQUENCES:** cambios de hardware (p.ej. futuras optimizaciones de Fase 7) pasan por allowlist+ADR; la referencia stock nunca se modifica.
- **EVIDENCE:** experimento docs/experiments/2026-09-14_r36sx-v26-board.md — DTB build == stock roundtrip (sha 04fb8383...), 0 diff semántico; kernel config delta 0.
- **RELATED:** ADR-007, docs/DTS_STOCK_MODEL.md, docs/R36SX_D3100_DELTA.md

## ADR-011 — Diagnóstico físico del boot parcial requiere serial (DTB de diagnóstico, no baseline)

- **DATE:** 2026-09-15
- **STATUS:** SUPERSEDED para su propósito original (2026-09-18: el boot parcial se resolvió en 6x sin serial y el media-fix se resolvió sin serial vía ABI forense — ADR-012). El DTB de diagnóstico queda como HERRAMIENTA disponible (reversible) para debugging futuro; el cable USB-TTL sigue recomendado como equipo del taller.
- **SCOPE:** Fase 5 — SAFE PHYSICAL BOOT TEST / diagnóstico de causa raíz
- **CONTEXT:** Fase 5 (2026-09-15) desplegó el kernel r36sx-v26 (Fase 4B, vendor-config) en la SD: la consola arrancó y mostró el splash TreeFrogUI (criterio b PASS) pero NO llegó al menú ni fue navegable (criterio c FAIL). Rollback ejecutado y verificado (consola recuperada usable con stock). La causa raíz no es el entry del uImage (bootm lo respeta) ni el DTB (idéntico al stock); apunta a diferencia de config entre el kernel de fábrica y el vendor SDK en algún driver de runtime (fb/input/audio/amprpc). El `.config` de fábrica NO es extraíble del uImage stock (vmlinux.bin no es ELF y no tiene CONFIG_IKCONFIG: 0 matches IKCFG_ST). La evidencia decisiva sería dmesg, pero en el DTS stock todos los `hc_uart@*` están `status="disabled"` y bootargs usa `console=tty1`; el USB OTG expone solo gadget MTP/PTP (sin CDC ACM serial), por lo que el cable USB-C OTG NO sirve para capturar dmesg.
- **DECISION:** para diagnosticar el boot parcial se creará un **DTB de diagnóstico "serial-only"**: derivado del DTS stock-normalized (cuerpo verbatim + allowlist), con UN `hc_uart` habilitado y `console=ttyS0,115200n8` en bootargs, SOLO para captura de dmesg vía serial (USB-TTL al UART). Este DTB NO es el baseline ni se despliega como tal; es una herramienta de diagnóstico temporal. El baseline r36sx-v26 sigue con DTS verbatim stock (ADR-010, allowlist 0). Mientras no se confirme el driver de runtime faltante, el boot parcial queda con estado **CAUSA RAIZ NO CONFIRMADA**.
- **RATIONALE:** el diagnóstico exige ver dónde se cuelga el kernel tras el splash; sin serial no hay evidencia decisiva; el DTB de diagnóstico es reversible y no toca NOR/bootloader/AVP/rootfs (solo `cubegm/vmlinux.uImage` + `cubegm/dtb.bin` si se desplegara para el test). Se documenta por separado para no contaminar el baseline ni violar ADR-010.
- **CONSEQUENCES:** requiere que el usuario tenga/adquiera un cable USB-TTL (UART de la consola, 115200 8N1). El DTB de diagnóstico se versiona en `boards/r36sx-v26/dts/diagnostic-serial/` o similar, etiquetado NO-BASELINE. Si el usuario no dispone de cable serial, la alternativa es comparar símbolos/drivers del kernel vendor contra los que la UI requiere, con menor fiabilidad.
- **EVIDENCE:** experimento docs/experiments/2026-09-15_fase5-physical-boot.md; DTS stock (hc_uart disabled + console=tty1); config kernel (USB_ACM not set, USB_G_SERIAL not set, MTP/PTP only); vmlinux stock sin IKCONFIG.
- **RELATED:** ADR-010, docs/BOOT_CHAIN.md, docs/DTS_STOCK_MODEL.md

## ADR-012 — Drift ABI fábrica(Dic-2025) ↔ SDK(Jul-2024): los structs UAPI del kernel se rellenan (padding al final) hasta el sizeof que usa el userspace de fábrica

- **DATE:** 2026-09-18
- **STATUS:** ACTIVE
- **SCOPE:** Fase 8/media — fix AVP-media (audio 9l, video 9m); política para cualquier ABI futuro
- **CONTEXT:** los binarios userspace de fábrica (driver_r36sx.so, libffplayer.so, libhudi.so — builds Dic-2025) hablan con el kernel vía el avp-proxy, cuyo dispatch es un `switch(cmd)` donde cada ioctl se genera con `_IOW/_IOR(..., struct X)` — **el sizeof del struct queda codificado en el número de ioctl**. Los headers UAPI del SDK hclinux-2024.02.y.2 (Jul-2024) compilan structs MÁS PEQUEÑOS que los que usan los binarios de fábrica: `struct audio_config` 608 vs 632 (24 bytes), `struct video_config` 644 vs 664 (20 bytes). Con el mismatch, el case del proxy no matchea el cmd de fábrica → `KSHM_WRITE_HDL_ACCESS` no se envía → el AVP recibe la RPC por el camino default (responde OK) pero sin handle kshm el userspace no tiene buffers → familia media muerta sin un solo error en dmesg (el AVP "ACKa en silencio", hallazgo 8g). Este desfase explica TODO el cluster AVP-media (audio juegos/música/video sin sonido, video sin imagen, 7c/7d/7e refutadas porque la causa no estaba en config/drivers/kernel).
- **DECISION:** para cada struct UAPI con drift verificado contra fábrica, se añade al FINAL del struct un campo de padding explícito (`uint8_t _pad_abi_2025[N];`) con comentario de evidencia, hasta que el ioctl compilado sea byte-a-byte el que emiten los binarios de fábrica. El tamaño objetivo de fábrica se obtiene por (1) evidencia on-device (amprpc debug: `IOCTL cmd=0x...`) y/o (2) reconstrucción de constantes `lui+ori` de los binarios de fábrica (método validado: reproduce exactamente el cmd observado on-device). El padding va al final porque los binarios de fábrica confirman offsets preservados (los fixups del proxy sobre campos tempranos extradata/extradata_size funcionan post-fix). Prohibido "adivinar" paddings: cada N debe venir del cmd observado/reconstruido. Fix aplicado: auddec.h +24 (9l, AUDIO PHYSICAL PASS) y vidmp.h +20 (9m, desplegado, test pendiente). Patches: `patches/kernel/0001..0002`.
- **RATIONALE:** el kernel es el único lado que compilamos (userspace+AVP son binarios de fábrica inmutables en el camino al objetivo); por tanto el ABI se alinea desde el lado kernel. El padding es la intervención mínima: no cambia el wire-format de fábrica, solo hace que el kernel reconozca los cmd correctos; reversible y auditado por hash en patches/kernel/.
- **CONSEQUENCES:** cualquier otro ioctl con struct grande que no matchee se diagnostica con el mismo método (scan lui+ori + amprpc debug). Riesgo residual: si un futuro struct de fábrica insertara campos EN MEDIO (no al final), el padding al final no bastaría — se detectaría porque el fix no produce PHYSICAL PASS y los valores de campos clave (ej. codec_id) llegarían corruptos al AVP. El avp-own (9a-9e) queda disponible como plan C (par consistente SDK-SDK), archivado en artifacts/avp/.
- **EVIDENCE:** docs/experiments/2026-09-18_fase9m-video-abi-fix.md; evidence-9l-boottrace.log (AUDIO ABI on-device); scan libffplayer.so/libhudi.so (AUDDEC 0x82780301 == boottrace; VIDDEC 0x82980400); probe mips32r2 sizeof 632/664; objdump avp-proxy.o (`lui v0,0x8278/0x8298`).
- **RELATED:** ADR-008 (supera su limitación para el media-fix vía proxy ABI, no vía AVP propio), ADR-010, docs/experiments/2026-09-17_fase8-own-rootfs.md (addendums 8g/9-series), patches/kernel/

## ADR-013 — Diagnóstico on-device OPT-IN: producción silenciosa, flag en SD para habilitar trazas

- **DATE:** 2026-09-18
- **STATUS:** ACTIVE
- **SCOPE:** Fase 7 — optimizaciones; política de diagnóstico permanente
- **CONTEXT:** las herramientas de diagnóstico construidas en Fases 5–9 (S09trace con copia a SD en cada boot ~30 ciclos copy+sync de 3 archivos durante 60s ≈ 5+ MB/boot; amprpc/amprpc+avp-proxy prints por RPC/PCM-xfer) fueron decisivas para cerrar el caso AVP-media (ADR-012), pero en producción generan desgaste de SD, churn de I/O durante el primer minuto de uso y ruido en dmesg — costo permanente sin valor cuando no se debuggea.
- **DECISION:** todo diagnóstico on-device es **opt-in**: (1) S09trace v5 solo escribe a la SD si existe el flag `/media/*/cubegm/diag.enabled` (archivo vacío que el usuario crea al debuggear y borra al terminar); sin flag, buffers solo en /tmp (RAM, inspección en shell vivo) y auto-apagado tras el probe post-picoarch; (2) todo print de debug del kernel ligado a caminos calientes (snd_xfer por-PCM-xfer) lleva **budget** (contador atómico con tope, patrón amprpc_dbg/SND_XFER_DBG_MAX=500) — primeras N trazas conservadas, luego cero costo. El ABI-trace de amprpc (2000) se mantiene como está por su valor probado y su autolímite.
- **RATIONALE:** el diagnóstico demostrado decisivo NO se elimina: se vuelve condicional. El flag es descubrible y documentado en el propio S09trace y en README/docs; el mecanismo es idéntico al patrón opt-in de zhijack (log.txt). El presupuesto de prints evita el costo por-evento en playback sin sacrificar las primeras evidencias de una sesión.
- **CONSEQUENCES:** un boot de producción NO deja boottrace/virtuart/treefrog_ui en la SD — si un test futuro requiere evidencia, crear `diag.enabled` ANTES del boot. Los prints con budget requieren inspección temprana (las primeras N entradas de la sesión, no las últimas).
- **EVIDENCE:** iteración 7a (CHANGELOG 2026-09-18); S09trace v5 (`boards/r36sx-v26/rootfs-overlay-own/etc/init.d/S09trace`); `patches/kernel/0004-avp-proxy-snd-xfer-debug-budget500-fase7a.patch`.
- **RELATED:** ADR-012, docs/BUILD.md, docs/experiments/2026-09-18_fase9m-video-abi-fix.md

## ADR-014 — Own kernel patches: canonical in patches/buildroot/linux/ + 900X sync to SDK (clean-build reproducibility)

- **DATE:** 2026-09-22
- **STATUS:** ACTIVE
- **SCOPE:** Phase 9-1 — reproducibility of the own kernel patch set; applies to 4.4.186 and 5.12.4+
- **CONTEXT:** ADR-012/iterations 9f-9m left 4 kernel-side fixes (auddec 24B, vidmp 20B, amprpc debug, avp-proxy snd-xfer budget) applied MANUALLY to the r36sx-v26 build tree and archived as diffs in `patches/kernel/` with absolute-path headers. A clean rebuild did NOT reproduce them: reproducibility gap in the known-good 8e kernel. The SDK buildroot (2020.02) does not support colon-separated BR2_GLOBAL_PATCH_DIR (verified: fails with "contains nonexistent directory <whole-string>") — second global patch dir approach discarded.
- **DECISION:** (1) The canonical own patches live in `patches/buildroot/linux/` in canonical unified-diff `a/`/`b/` format (apply with `patch -p1`, the buildroot apply-patches.sh standard). (2) `build_kernel.sh` step 3b syncs them to `SDK/patches/linux-<KVER>/` with prefix `900X` (000N -> 900N: they sort AFTER the vendor 00XX set), reading KVER from the defconfig — same mechanism as board-file sync (repo = source of truth, SDK workspace = derived). (3) `audit_kernel_patches.sh` v3 gates: 41 vendor patches identical to the external reference, 900X present and hash-identical to the repo, and the 4 tree markers (pads + debug symbols) in the resulting tree. (4) `patches/kernel/` remains as historical archive (absolute-path format, not buildroot-applicable).
- **RATIONALE:** the 4 patches touch ONLY SOURCE/linux-drivers files injected by the PRE_PATCH rsync — identical content for any kernel version, so they are version-agnostic (valid for 4.4.186 and 5.12.4 unchanged). E2E verified: scratch `make linux-patch` = 45 Applying (41 vendor + 4 own, in order) and the 4 resulting files BIT-IDENTICAL to the known-good 8e tree.
- **CONSEQUENCES:** clean builds now reproduce the known-good; the PATCH PROVENANCE gate detects a missing sync; any NEW own patch goes into patches/buildroot/linux/ with 000N numbering (the 900 prefix is added by the sync, not by the author). The SDK workspace patch set now contains the 900X files (expected audited state).
- **EVIDENCE:** ~/work/r36sx-hclinux/logs/linux-patch-91-integration.log (45 Applying); phase9 e2e: EXACT-MATCH x4 vs 8e tree, gate PASS on scratch AND known-good trees; conflict scan: no SDK patch (4.4.186 or 5.12.4 set) touches auddec.h/vidmp.h/amprpc.c/avp-proxy.c.
- **RELATED:** ADR-012 (patches 9001/9002 are its implementation), ADR-013 (budgets 9003/9004), docs/BUILD_MANUAL.md §4.1b
