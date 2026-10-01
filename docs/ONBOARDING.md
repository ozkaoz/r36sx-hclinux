# docs/ONBOARDING.md — Guía de incorporación para nuevos desarrolladores

> **Punto de partida del proyecto.** Estado: **ARCHIVADO** (2026-10-01, decisión del propietario — ADR-017). La plataforma está completa y físicamente validada hasta la Fase E (kernel switcher stock↔propio). Esta guía lleva a un desarrollador nuevo **desde cero hasta compilar el kernel y desarrollar software para la consola**, con el estado exacto del cierre.

---

## 0. Qué es este proyecto y en qué estado queda

**r36sx-hclinux** = plataforma Linux/HCLinux reproducible para la consola **R36SX V2.6** (SoC HiChip HC16xx, MIPS32r2): kernel propio, DTB propio, rootfs propio (Buildroot) y TreeFrogUI como shell — con `cubegm/` (el sistema de fábrica) 100% eliminado y **boot propio desde `/boot/`**.

**Logros físicamente validados al cierre:**

| Logro | Evidencia |
|---|---|
| Kernel propio **5.12.4** (desde 4.4.186 vendor) | CLEAN PHYSICAL PASS: boot, menú, input, juegos, videos, shutdown |
| Boot 100% desde `boot/` — bootloader propio en NOR (fábrica + 7 bytes de path-prefix) | Fase D BOOT-1 PHYSICAL PASS + boot-2 (lee `boot/` exclusivamente) |
| `cubegm/` eliminado al 100% de la SD (binarios recompilados/binary-patcheados a `treefrog/`) | Fase D COMPLETE 2026-09-25 |
| USB: MTP + networking NCM (telnet root) + ADB (shell+push/pull, overlay-free) | 9-6b/d/e/f PHYSICAL PASS |
| **Kernel switcher stock↔propio** (modo archivo + modo carpeta + par end-user) | Round-trip PHYSICAL PASS (nuestra consola) + SD-level BIT-EXACTO 4701/4701 (SD real de usuario) |
| Recovery BootROM-USB siempre disponible (DDR-init fábrica intacto) | Probado 2 veces (2026-09-20/21) |

**Pendientes al cierre (documentados, no bloqueantes):** boot físico del flujo end-user con NOR de fábrica (requiere consola de usuario real); velo azul NCM con AVP fábrica (ADR-015, aceptado); migración 5.15 LTS (feasibility audit); firmware AVP propio (parcado, clase D).

**Mapa de documentación:** `CONTEXT_MAP.md` (router por tema). Historia técnica: `CHANGELOG.md` + `docs/experiments/`. Decisiones: `DECISIONS.md` (ADR-001..017).

---

## 1. La consola por dentro (léelo antes de tocar nada)

```
BootROM → DDR-init (NOR, fábrica, 12.288 B) → bootloader (NOR) → AVP/HCRTOS (fábrica) → Linux (NUESTRO) → TreeFrogUI
```

| Componente | Detalle |
|---|---|
| SoC | HiChip **HC16D3100V20** (identificado de fábrica), MIPS32r2 little-endian, dual-core |
| RAM | 256 MiB DDR → **175,57 MiB Linux** + ~80 MiB AVP/HCRTOS (memoria media MMZ) |
| NOR | SPI 512 KiB: particiones boot (bootloader+DDR-init) / eromfs / persistentmem |
| Display | 1280x720 MIPI-DSI (panel R63311) — inicializado por el AVP, NO por Linux |
| Boot files | El bootloader lee **4 archivos** desde la carpeta de su path-prefix (NOR-DTB): `dtb.bin`, `avp.uImage`, `vmlinux.uImage`, `xgame-logo.bmp` |
| Path-prefix | **Fábrica: `cubegm/`** · **Nuestro NOR (Fase D): `boot/`** (patch in-place de 7 bytes `cubegm\0`→`boot\0\0\0`) |
| AVP | Firmware de fábrica corre en el segundo core: display, audio (HC-I2SO), media (RPC AMP). **Preservado por diseño** (ADR-008) — nunca reemplazarlo sin leer los 2 postmortems de brickeo |

**La clave del switcher (Fase E):** el bootloader carga el kernel desde SU carpeta — **el kernel que hay ahí determina el SO**: el kernel de fábrica lanza su userspace vendor desde `cubegm/`; el nuestro (initramfs embebido) lanza `treefrog/`. Por eso el switch cambia solo archivos/carpetas en la SD y jamás toca NOR.

Profundizar: `docs/BOOT_CHAIN.md` (cadena completa con evidencia), `docs/ARCHITECTURE.md`, `docs/HARDWARE_R36SX_V26.md`, `docs/DTS_STOCK_MODEL.md` (modelo DTB verificado).

---

## 2. Preparar el entorno (~30 min)

**Regla absoluta (AGENTS.md §0): TODO se ejecuta desde WSL2 Ubuntu 24.04.** Windows es solo fuente de datos vía `/mnt/`. Nada de compilar/desarrollar desde cmd/PowerShell/Git Bash.

```bash
# 1. Clonar el repo
git clone https://github.com/ozkaoz/r36sx-hclinux.git ~/projects/r36sx-hclinux
cd ~/projects/r36sx-hclinux

# 2. SDK vendor (NO está en el repo — 2,1 GB, inmutable):
#    hclinux-2024.02.y.2.tar.gz — SHA256 e3211b41f8d649c7d7838f7f19b8cca5cf30ba6cb1ff9545be6943845fbf8d5d
#    Colócalo en /mnt/d/GitHub/KERNEL/ (o ajusta scripts/prepare_sdk.sh). Inventario: docs/SOURCE_INVENTORY.md
./scripts/verify_sources.sh      # valida el hash del SDK — PROHIBIDO modificarlo (§4)
./scripts/prepare_sdk.sh         # extrae al workspace ~/work/r36sx-hclinux/sdk/

# 3. Paquetes host (mínimos reales — ADR-002; el setup vendor rompe Ubuntu 24.04):
sudo apt install gperf swig genromfs libtool texinfo mtd-utils autoconf-archive \
  unrar lzop libncurses-dev libssl-dev bc rsync cpio tree

# 4. Variables de entorno OBLIGATORIAS del build (§ docs/BUILD.md):
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"  # PATH sanitizado (WSL hereda rutas Windows con espacios → Buildroot aborta)
export BR2_DL_DIR="$HOME/work/r36sx-hclinux/cache/dl"
export HOST_EXTRACFLAGS="-fcommon"    # GCC13 host vs dtc 4.4 (solo host tools)
```

**Workspace:** repo `~/projects/r36sx-hclinux` (fuente de verdad) · SDK/builds `~/work/r36sx-hclinux/{sdk,build,cache,logs,artifacts}`.

---

## 3. Compilar el kernel (paso a paso)

```bash
./scripts/build_kernel.sh r36sx-v26 k512     # kernel 5.12.4 + rootfs propio embebido
```

**Qué hace el script por dentro** (flujo validado Fase 9, BUILD PASS):

1. Valida insumos del repo: DTS (`boards/r36sx-v26/dts/`), defconfig (`configs/buildroot/`), SDK extraído.
2. Regenera el DTS desde la referencia auditada (`scripts/make_board_dts.sh`) — nunca confiar en copias.
3. Sincroniza board files repo → workspace SDK (board propia; vendor intacto) + **parches propios**: `patches/buildroot/linux/000N` → SDK `patches/linux-5.12.4/900N` (prefijo 900X, tras el set vendor 00XX) y los version-specific `patches/buildroot/linux-5.12.4/` → `910N` (ADR-014).
4. Normaliza ksymtab legacy de 8 bytes de los `.o` vendor (`tools/strip_vendor_ksymtab_8B.py`) — sin esto, todo `insmod` falla con "Unknown symbol".
5. Buildroot: `make default` (construye TODOS los packages + imágenes; el post-image falla benignemente tras `rootfs.cpio` — ADR-008) → `rootfs-own.cpio` (embed determinista v6: el cpio FULL se re-embebe en el kernel con `linux-rebuild`) → `make` final (regenera el uImage desde el vmlinux re-linkeado).
6. Artefactos en `~/work/r36sx-hclinux/build/r36sx-v26-k512/images/`: **`vmlinux.uImage`** (gzip, Load `0x80000000`, Entry `0x803e3200`), **`dtb.bin`**, `rootfs.cpio`, etc.

**Gates OBLIGATORIOS tras cada build (AGENTS.md §14 — un build sin provenance NO sirve):**

```bash
./scripts/audit_toolchain.sh        # TOOLCHAIN PROVENANCE: PASS/FAIL (cross-compiler real invocado, .cmd files)
./scripts/audit_kernel_patches.sh  # PATCH PROVENANCE: PASS/FAIL (parches APLICADOS, no presentes)
./scripts/compare_dtb_semantics.sh  # DTB SEMANTIC PASS (0-diff semántico vs stock)
```

**Errores conocidos** (detalle en `docs/experiments/`): bug kconfig vendor libcast (se desactiva), GCC13+dtc `-fcommon` (host tools), bare-metal AVP/hcboot toolchain NO disponible (ADR-008 → por eso el bootloader propio = binario de fábrica + 7 bytes, ver §5).

**Parches propios vigentes:** 9001 auddec ABI pad (ADR-012), 9002 vidmp ABI pad (ADR-012), 9003 amprpc debug, 9004 avp-proxy snd-xfer debug budget (ADR-013), + 5.12.4-specific 9101+ (timer API). ABI del kernel: `docs/TREEFROGUI_COMPATIBILITY.md` + ADR-012.

**Herramienta de referencia:** `mkimage -l vmlinux.uImage` (tipo/Load/Entry) · `file`, `readelf` (MIPS rel) · `sha256sum`.

---

## 4. Desplegar en la SD — el kernel switcher (Fase E)

Los artefactos van a la carpeta que el bootloader de ESA consola lee. **Nunca copies a mano sin backup** — usa el switcher (backup automático + SHA256 + idempotencia + verificación pre/post escritura):

```bash
# Estado de cualquier SD (read-only):
./scripts/kernel_switch_status.sh --sd /mnt/<letra>

# NUESTRA consola (bootloader propio en NOR → lee boot/):
./scripts/kernel_to_own.sh   --sd /mnt/<letra> --folder [fuente]   # → SO nuestro (boot/ = nuestro par; cubegm/ eliminada con backup)
./scripts/kernel_to_stock.sh --sd /mnt/<letra> --folder            # → SO stock (boot/ = par de FÁBRICA + cubegm/ creada)

# Consola de USUARIO FINAL (bootloader de fábrica → lee cubegm/):
./scripts/install_own_os.sh  --sd /mnt/<letra>   # stock+TreeFrogUI → nuestro SO completo (kernel en cubegm/ + treefrog/ frogui/ picoarch/)
./scripts/restore_stock_os.sh --sd /mnt/<letra>  # → vuelta a SU stock original (bit-exacta)
```

- Todo el estado/backups viven en `<sd>/kernel-switch/` (`orig/` = recovery point del primer uso, `sets/` = snapshots rotativos, `folders/` = backups de carpetas, `created-folders` = registro de lo que el install creó).
- Goldens de fábrica fijados en `manifests/GOLDEN_STOCK.sha256` (kernel `53b3e0b3`, DTB `1258f1eb`, AVP `a9788995`) — TODO restore golden se verifica contra ese manifiesto antes de escribir.
- Validación: `tests/kernel_switch_selftest.sh` → **HOST PASS 143/143** (23 grupos: corrupción, goldens adulterados, layouts, `--avp`, rotación, idempotencia, carpetas pre-existentes del usuario).
- **Seguridad (AGENTS.md §5):** estos scripts SOLO copian archivos dentro de la SD. Flashear NOR/DDR-init/bootloader = clase D, prohibido sin autorización explícita y evidencia. Recovery siempre disponible: BootROM-USB (~300ms tras encender, DDR-init fábrica intacto) con los kits HCProgrammer (`D:\R36SX\hcprogrammer-{own,restore}-kit\`, método probado — lanzar el tool con `-WorkingDirectory` en la carpeta del kit; ver `docs/RECOVERY.md`).
- SD de referencia del proyecto: `boot/` + `treefrog/` + `rootfs/` + `roms/` + `frogui/` + `picoarch/` — sin `cubegm/`.

---

## 5. Bootloader propio: cómo se logró (y por qué NO se recompila)

El SDK 2024 trae hcboot compilable, pero **el binario no inicializa el panel** (2 brickeos documentados — `docs/experiments/2026-09-20_postmortem-brickeo-bootloader.md` + faseD-2b2). La solución validada:

1. `factory-hcboot-decompressed.bin` (extraído del NOR de fábrica) = 100% del código que funciona.
2. Patch in-place de 7 bytes: string `cubegm\0` → `boot\0\0\0` (el bootloader lee hasta `\0`).
3. Recompresión LZMA-alone con los parámetros EXACTOS del factory + reensamblado (DDR-init + stub intactos).
4. Flash vía HCProgrammer (`HCFOTA-own-v3.bin` — formato HCFOTA decodificado del SDK, CRCs recalculados).

**Resultado:** NOR = fábrica + 7 bytes; NOR-DTB = fábrica byte-exacto (una sola línea de diff). La ventana BootROM-USB queda activa (DDR-init fábrica) = recovery sin abrir la consola.

---

## 6. Desarrollar software para la consola

### 6.1 El rootfs propio (Buildroot)
- Overlays: `boards/r36sx-v26/rootfs-overlay-own/` → `rcS`, `S09trace`, `S10mdev`, `S41hcdaemon`, **`S99app`** (lanza TreeFrogUI; escrito desde cero en Fase D — 0 refs cubegm, sin bind mount).
- Flujo embed determinista (v6, `build_kernel.sh`): el cpio FULL (goal default) se re-embebe con `linux-rebuild` — NUNCA empaquetar mid-build.
- Binarios userspace: toolchain **Codescape `mips-mti-linux-gnu` gcc 6.3.0** (mismo que la fábrica — vermagic). Host: Ubuntu 24.04.
- La SD conserva `rootfs/` (libs de fábrica libffplayer/libhudi) — usadas por los media apps vía bind; **ABI alineada por kernel-side padding** (ADR-012: los binarios de fábrica Dic-2025 envían structs con sizeof distinto al SDK Jul-2024; los parches 9001/9002 igualan).

### 6.2 El stack TreeFrogUI (regla de ownership — AGENTS.md §15)
El userspace de la SD (`treefrog/` completo: zhijack.sh, usb_mode.sh, apps/, launcher) **se desarrolla y canoniza en el FORK** `github.com/ozkaoz/TreeFrogUI` (branch `net-mode-app`), NO como parches ad-hoc aquí. Este repo provee la plataforma (kernel, DTB, rootfs, contratos configfs/gadget/bind layout) y documenta el estado físico (CURRENT.md/CHANGELOG). El submódulo `frogui` (UI) también vive en el fork.

### 6.3 Depuración en la consola (vías físicas validadas)
| Vía | Uso | Estado |
|---|---|---|
| **NCM + telnet root** | Shell de producción (adaptador nativo Windows; `rootfs/sbin/telnetd`) | PHYSICAL PASS (overlay azul aceptado — ADR-015) |
| **ADB (FunctionFS)** | `adb shell` + push/pull overlay-free (daemon `min_adbd`, worker por comando) | PHYSICAL PASS (9-6f) |
| **MTP** | Transferencia de archivos modo USB | PHYSICAL PASS (9-6b) |
| **Logs en SD** | `log.txt`, `dmesg-*.txt`, `NET_MODE_DEBUG.log`... leídos por el PC tras apagar | Siempre disponible |
| **Internet vía USB** | ICS del PC: ping/DNS/wget PASS; ADB reverse al 90% al cierre | 9-6d |
| Scripts host | `scripts/diagnose_*.sh`, `diag*.sh` | Vía NCM/ADB |

### 6.4 Emuladores/media
Los cores (`libemu_*.so`, pcsx4all) y apps corren desde `treefrog/` con las libs del rootfs embebido + `rootfs/` de fábrica; el display/audio pasan por el AVP (AMPRPC) — cualquier trabajo de media exige entender ADR-012 y el contrato `docs/TREEFROG_UI_CONTRACT.md` (boot flow, ABI media, inventario+hashes).

### 6.5 Disciplina de desarrollo (no negociable — AGENTS.md)
- Iteración: `RESEARCH → PLAN → IMPLEMENT → VERIFY → DOCUMENT → COMMIT → PUSH → VERIFY REMOTE`.
- Etiquetas de validación EXACTAS (§8): `STATIC PASS · HOST PASS · BUILD PASS · EMULATED PASS · PHYSICAL PASS · CLEAN-INSTALL PHYSICAL PASS`. Prohibido DONE/VERIFIED/WORKING. "Compila" ≠ "funciona en R36SX".
- Una variable por experimento (§7). Evidencia con ruta citada — prohibido inventar direcciones/GPIO/DTB/bootargs (§9).
- Documentation sync obligatoria por iteración (§13): ROADMAP/CURRENT/CHANGELOG/ADRs/experiment docs.
- STOP conditions (§10): escritura de SD/flash, riesgo de brick, build roto por dependencia no comprendida, contradicción evidencia-doc.

---

## 7. Recorrido de arranque rápido (checklist del primer día)

```bash
# 1. Entorno (§2) + SDK verificado
./scripts/agent_preflight.sh                          # TODO PASS
# 2. Build
./scripts/build_kernel.sh r36sx-v26 k512               # BUILD OK → images/
./scripts/audit_toolchain.sh && ./scripts/audit_kernel_patches.sh   # PROVENANCE PASS
# 3. Validación sin hardware
./tests/kernel_switch_selftest.sh                     # HOST PASS 143/143
# 4. Hardware (con SD de test y autorización):
#    - consola con bootloader propio: kernel_to_own.sh --folder → boot → probar → kernel_to_stock.sh --folder
#    - consola stock ajena: install_own_os.sh → boot → restore_stock_os.sh
# 5. Documentar la iteración (CHANGELOG + CURRENT) y pushear
```

## 8. Mapa completo de documentación

| Doc | Para qué |
|---|---|
| `AGENTS.md` | Constitución del proyecto (16 secciones) — leer SIEMPRE primero |
| `CURRENT.md` | Snapshot operativo al cierre |
| `CONTEXT_MAP.md` | Router: qué doc consultar por tema |
| `DECISIONS.md` | ADR-001..017 (decisiones durables con evidencia) |
| `CHANGELOG.md` | Una línea por iteración — la historia técnica completa |
| `docs/ROADMAP.md` | Fases 0–E, gates y estado final |
| `docs/ARCHITECTURE.md` · `BOOT_CHAIN.md` · `HARDWARE_R36SX_V26.md` · `DTS_STOCK_MODEL.md` | Hardware y cadena de boot (con evidencia) |
| `docs/BUILD.md` · `BUILD_MANUAL.md` · `ai/BUILD_CONTRACT.md` | Compilación (histórico + método) |
| `docs/TOOLCHAIN_PROVENANCE.md` · `PATCH_PROVENANCE.md` | Gates §14 |
| `docs/SDK_AUDIT.md` · `SOURCE_INVENTORY.md` · `BOARD_IDENTITY.md` · `R36SX_*_DELTA.md` | Auditoría del SDK y la board |
| `docs/TREEFROGUI_COMPATIBILITY.md` · `TREEFROG_UI_CONTRACT.md` | Contrato del stack (ABI, /dev, servicios) |
| `docs/RECOVERY.md` · `ai/HARDWARE_SAFETY.md` · `ai/VALIDATION.md` · `ai/RELEASE_CONTRACT.md` | Seguridad, recuperación, validación |
| `docs/experiments/*.md` | Evidencia experimental día a día (empezar por los postmortems de brickeo y la Fase D) |
| `manifests/GOLDEN_STOCK.sha256` | Hashes golden de fábrica (contrato del switcher) |

**Al reanudar el proyecto (ADR-017):** el camino corto = flashear NOR propio (kit own, una vez) → desplegar el SO con el switcher → continuar desde `docs/ROADMAP.md` §pendientes. Todo el estado físico documentado en `CURRENT.md` era cierto al commit de cierre.
