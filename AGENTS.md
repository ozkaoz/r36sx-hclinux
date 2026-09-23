# AGENTS.md — Constitución permanente de r36sx-hclinux

**Versión:** 1.0 (bootstrap)
**Repo:** https://github.com/ozkaoz/r36sx-hclinux
**Objetivo:** plataforma Linux/HCLinux reproducible para R36SX V2.6 (HiChip HC16xx, MIPS) con TreeFrogUI estable.

---

## 0. INVARIANTE FUNDAMENTAL (literal)

**All development, builds, Git operations and GitHub operations MUST be executed from WSL. Windows paths are data sources only unless explicitly documented otherwise.**

Prohibido compilar/desarrollar desde cmd.exe, PowerShell o Git Bash de Windows, salvo razón de hardware documentada explícitamente. Acceso a datos Windows solo vía `/mnt/`.

## 1. PROTOCOLO DE INICIO (toda sesión)

1. Confirmar que se está dentro de WSL (Linux).
2. Leer en orden: `AGENTS.md` → `CURRENT.md` → `CONTEXT_MAP.md`.
3. Ejecutar `./scripts/agent_preflight.sh` (read-only, seguro).
4. `git status --short --branch` — si hay cambios locales no explicados: **STOP**, mostrar antes de tocar nada.
5. Resolver desde Git: `REPO_ROOT`, `ACTIVE_BRANCH`, `HEAD`, `UPSTREAM`, `AHEAD_BEHIND`, `WORKTREE_STATE`.
6. Identificar objetivo exacto de la iteración y clasificar el cambio (ver §7).
7. Comenzar trabajo.

## 2. FUENTES DE VERDAD (jerarquía, mayor → menor)

1. Requisito explícito actual del usuario.
2. Evidencia física/directa actual.
3. Este `AGENTS.md`.
4. Decisiones ACTIVE de `DECISIONS.md`.
5. **SDK vendor real en `/mnt/d/GitHub/KERNEL`** (el archivo manda, no los resúmenes).
6. Git y filesystem actuales.
7. Builds y artefactos actuales.
8. `CURRENT.md` (ES CACHÉ).
9. Documentación estructural.
10. Historial/changelog.
11. Inferencias anteriores.

**EVIDENCE > MEMORY > PLAN.** Si una fuente de mayor nivel contradice una inferior: actualizar el contexto/documentación afectada primero. Los resúmenes generados son CACHÉ; el SDK real tiene prioridad siempre.

## 3. REGLA DE CONSULTA DEL SDK

Ante ambigüedad, duda de drivers/DTS/memoria/AVP/bootloader/kernel/Buildroot/hardware, información contradictoria u obsoleta, pérdida de contexto por compactación, nueva sesión, o resultado inesperado de build: **NO inventar la respuesta. VOLVER A CONSULTAR** `/mnt/d/GitHub/KERNEL` (tar SDK, manuales, ZIP/7Z, patches, hcdrivers, DTS, configs, scripts, toolchains). Consultables sin límite de veces.

## 4. SDK MAESTRO INMUTABLE

`/mnt/d/GitHub/KERNEL/hclinux-2024.02.y.2.tar.gz` — SHA256 `e3211b41f8d649c7d7838f7f19b8cca5cf30ba6cb1ff9545be6943845fbf8d5d` (2,116,519,773 bytes).

- PROHIBIDO modificar/reemplazar/sobrescribir el SDK y las fuentes de `/mnt/d/GitHub/KERNEL`.
- PROHIBIDO desarrollar dentro de `/mnt/d/GitHub/KERNEL` o `/mnt/d`.
- Workspace derivado en WSL nativo: `~/work/r36sx-hclinux/{sdk,build,cache}`.
- Todo cambio propio vive en ESTE repo: patches, board, configs, scripts, overlays.
- Reconstrucción garantizada desde: SDK ORIGINAL + ESTE REPO + dependencias documentadas.

## 5. HARDWARE SAFETY (NO NEGOCIABLE)

PROHIBIDO escribir sin autorización explícita del usuario: NOR/NAND flash, bootloader, DDR init, particiones críticas, SD física, `/dev/sdX`, firmware interno.

Prohibido usar `rm -rf`, `git reset --hard`, `git clean -fd`, `dd`, `mkfs`, flash tools sobre objetivos no verificados.

Antes de escribir una SD: identificar dispositivo → mostrar info → confirmar tamaño/modelo/mounts → **pedir autorización explícita** → solo entonces proceder. Una SD stock/original se protege siempre como golden recovery.

## 6. ITERACIÓN OBLIGATORIA

```
RESEARCH → PLAN → IMPLEMENT → VERIFY → DOCUMENT → COMMIT → PUSH → VERIFY REMOTE → NEXT
```

GitHub es el journal técnico autoritativo. No trabajar horas localmente para subir al final. Nunca finalizar una iteración local sin actualizar GitHub. No depender del historial del chat.

## 7. CLASES DE CAMBIO Y GATES

| Clase | Alcance | Gate |
|-------|---------|------|
| A | Contexto/docs/agentes | Static review + context checks |
| B | Herramientas host/scripts/tests | shellcheck/tests relevantes |
| C | Kernel/BSP/DTS | Config validation + kernel build + DTB validation |
| D | Boot/AVP/bootloader | Build validation + **autorización hardware** |
| E | Rootfs/Buildroot | Rootfs/build validation |
| F | Deploy físico/SD | **Autorización explícita antes de escribir** |
| G | Release pública | Artefacto validado + **autorización explícita** |

Una variable principal por experimento. Prohibido modificar simultáneamente kernel+bootloader+AVP+rootfs+DDR.

## 8. ETIQUETAS DE VALIDACIÓN

Usar exactamente: `STATIC PASS` · `HOST PASS` · `BUILD PASS` · `PACKAGING PASS` · `EMULATED PASS` · `PHYSICAL PASS` · `CLEAN-INSTALL PHYSICAL PASS` · `DOWNLOAD-BACK PASS`.

Prohibido: DONE, VERIFIED, WORKING. "Compila" ≠ "funciona en R36SX". HOST PASS ≠ PHYSICAL PASS. No inventar pruebas físicas.

## 9. PROTECCIÓN CONTRA ALUCINACIONES

No sabes → BUSCA. Prioridad: filesystem local → SDK → docs adjuntas → Git → repos ozkaoz → upstream → Internet → inferencia. Etiquetar inferencias como inferencias. Prohibido inventar direcciones de memoria, GPIO, offsets, tamaños, DTB, bootargs, modelo de flash, RAM, toolchain, flags, boot sequence — obtener de evidencia con ruta citada.

## 10. STOP CONDITIONS

Detener y pedir intervención humana (con estado exacto + razón + comandos exactos + resultado esperado + datos a devolver) cuando: prueba física requerida, escritura de SD/flash, riesgo de brick, info hardware contradictoria, build roto por dependencia no comprendida, falta fuente crítica, evidencia contradice hipótesis, cambio fuera de scope, contraseña/sudo interactivo, o decisión funcional del usuario.

## 11. ESTRUCTURA DEL REPO

`AGENTS.md` (constitución) · `CURRENT.md` (snapshot, caché) · `CONTEXT_MAP.md` (router) · `DECISIONS.md` (ADRs) · `boards/` · `configs/` · `patches/` · `scripts/` · `manifests/` · `docs/` (+ `docs/ai/` contratos, `docs/experiments/`) · `tests/` · `tools/` · `out/` (ignorado, artefactos locales). Modificar estructura solo con razón técnica documentada.

## 12. HANDOFF

Toda iteración resume: `CHANGE_CLASS · OBJECTIVE · FILES_CHANGED · HEAD · CHECKS_RUN · BUILD_EVIDENCE · PHYSICAL_EVIDENCE · BLOCKER · NEXT_EXACT_ACTION · STOP_CONDITION`. El proyecto continúa desde GitHub sin este chat.

## 13. DOCUMENTATION SYNC (REGLA OBLIGATORIA — PERMANENTE)

La documentación es parte del entregable técnico de CADA iteración. **Una iteración con código/config/scripts/build/evidencia/estado cambiados y documentación afectada sin actualizar = ITERACIÓN INCOMPLETA** (no cerrar, no etiquetar PASS).

**DOCUMENTATION REVIEW OBLIGATORIO antes de CADA commit significativo.** Checklist mínimo a revisar (no implica modificar todos — solo los impactados):

1. ¿Cambió install/prepare/compile? → `README.md` y/o `docs/BUILD.md`
2. ¿Cambió arquitectura/boot/memoria/AVP/kernel/BSP? → `docs/ARCHITECTURE.md`, `docs/BOOT_CHAIN.md`, `docs/SDK_AUDIT.md`
3. ¿Cambió el estado actual? → `CURRENT.md` (en CADA iteración significativa; debe reflejar el estado verdadero al HEAD publicado)
4. ¿Decisión técnica durable? → ADR en `DECISIONS.md` (decisiones, no acciones; "se compiló X" no es ADR, "X será baseline provisional hasta evidencia física" sí)
5. ¿Roadmap/fase completada? → `docs/ROADMAP.md`
6. ¿Nuevo script/comando para otros devs? → `README.md`/`docs/BUILD.md` + README del directorio
7. ¿Particularidad hardware R36SX? → `docs/HARDWARE_R36SX_V26.md`
8. ¿Nueva evidencia SDK? → `docs/SDK_AUDIT.md` con ruta exacta
9. ¿Experimento importante? → `docs/experiments/YYYY-MM-DD_<nombre>.md`
10. ¿Regla permanente de agentes? → `AGENTS.md`
11. ¿Doc nuevo localizable? → `CONTEXT_MAP.md`
12. ¿Visible para recién llegados a GitHub? → `README.md` (portada VIVA: qué es, objetivo, estado, qué funciona/no, quick start, artefactos, validación STATIC/HOST/BUILD/PHYSICAL, seguridad, licencia — sin historia obsoleta)

**Prohibido:** cambios cosméticos para generar actividad; declarar PHYSICAL PASS sin evidencia física; dejar README con estado histórico obsoleto. La historia vive en Git + CHANGELOG + docs/experiments.

**Gate commit/push:** `git status` → `git diff` → validaciones → DOCUMENTATION REVIEW → actualizar docs impactadas → `git diff --check` → commit → push → verificar remote HEAD. Si docs desactualizadas: ITERATION STATUS = INCOMPLETE.

**CHANGELOG.md**: una línea por iteración con cambio técnico relevante; no es diario. Detalles en docs/experiments/.

## 14. KERNEL PROVENANCE GATE (permanente — desde Fase 2.5)

Ningún kernel BUILD PASS es apto para desarrollo posterior sin evidencia CONSERVADA de:

- arquitectura host;
- arquitectura target;
- **cross compiler realmente invocado** (command files de kbuild `.cmd`, no suposición);
- compiler triplet y versión;
- sysroot;
- kernel `ARCH` y `CROSS_COMPILE` efectivos;
- kernel config;
- **patch set efectivo con orden** (log de aplicación, no presencia);
- overlays BSP/vendor aplicados (rsync/injection: hook, momento, source→dest);
- ELF architecture resultante (kernel + userspace + módulos);
- hashes de artefactos.

**"Presence of a toolchain does not prove it was used. Presence of a patch does not prove it was applied."** La presencia NO es aplicación: la prueba es la invocación registrada (`.cmd` files / patch logs / árbol resultante con hunks).

**vermagic ≠ toolchain identity**: `user@host` del vermagic solo describe el entorno de build original; la cadena de versión de compilador embebida es evidencia COMPLEMENTARIA, jamás prueba primaria de toolchain.

Herramientas del gate (parte del gate C futuro): `scripts/audit_toolchain.sh` → `TOOLCHAIN PROVENANCE: PASS/FAIL` · `scripts/audit_kernel_patches.sh` → `PATCH PROVENANCE: PASS/FAIL`.

Regla de patches externos: un patch de `/mnt/d/GitHub/KERNEL` idéntico por SHA256 a uno del SDK que Buildroot ya aplica = `EXTERNAL COPY: VERIFIED IDENTICAL · DOUBLE APPLICATION: NOT REQUIRED` (uso correcto). Un patch externo NO presente en el SDK NO se aplica automáticamente — requiere análisis de versión destino/dependencia/orden/finalidad y decisión documentada.

## 15. STACK-UPSTREAM: desarrollo conjunto con el fork TreeFrogUI (PERMANENTE)

La SD de la consola integra DOS repositorios con ownership separada:

| Repositorio | Remote | Ownership |
|---|---|---|
| **Este (r36sx-hclinux)** | ozkaoz/r36sx-hclinux | La PLATAFORMA: kernel, DTS, rootfs, drivers, overlays, contratos de sistema (configfs, gadget ABI, bind layout) |
| **Fork TreeFrogUI** | ozkaoz/TreeFrogUI (upstream: tzubertowski/TreeFrogUI) | El STACK de userspace de la SD: zhijack.sh, usb_mode.sh, apps/, launcher, la integración con FrogUI |

### Ubicación del fork
`D:\GitHub\TreeFrogUI` (WSL: `/mnt/d/GitHub/TreeFrogUI`). Consultar también su propio AGENTS.md/README antes de trabajar ahí.

### Regla de propiedad (obligatoria)
Cualquier desarrollo que toque archivos del stack en la SD (los `treefrog/*` al desplegarse) se desarrolla y canoniza en el FORK TreeFrogUI — NO como parche ad-hoc permanente en la SD ni como código duplicado en este repo. Este repo provee:
- los contratos de plataforma (S90configfs, gadget built-in, DTB, kernel ABI, rootfs),
- el estado físico documentado (CURRENT.md),
- los handoffs hacia el fork (`contrib/treefrogui-apps/` — paquetes upstreamable: se BORRAN de aquí tras integrarse en el fork).

### Protocolo de trabajo conjunto
1. Al tocar el stack: verificar el estado del fork primero (`git status` en `/mnt/d/GitHub/TreeFrogUI`).
2. Desarrollar en el fork (branch propia por feature; ej. `net-mode-app`).
3. Desplegar desde el fork a la SD (deploy script del fork o el helper del handoff).
4. Validar físicamente en la consola.
5. Documentar el estado resultante AQUÍ (CURRENT.md + CHANGELOG) — este repo es el journal físico de la plataforma completa.

### Inventario de divergencias stack actuales (a canonizar en el fork)
1. `usb_mode.sh`: check built-in `grep ... || [ -d "$CONFIG_ROOT/usb_gadget" ]` (9-6b — necesario con gadget functions built-in).
2. `usb_mtp.sh`: shim dispatcher → `net_mode.sh` con flag `rndis.mode` en la raíz SD (9-6e v2).
3. `rootfs/sbin/telnetd`: busybox multicall deployado desde la plataforma (el runtime /sbin viene del bind de `rootfs/`).
4. `treefrog/modules/5.12.4-release/`: ELIMINADO (gadget built-in — el loader de modulos del kernel esta ROTO: OOPS resolve_symbol; ver 9-6c).

### Apps en desarrollo conjunto (handoff → fork)
- **`apps/net_mode/`** (Conexión de Red): RNDIS USB networking implementado; WiFi placeholder pendiente (requiere 9-6c module loader o wifi built-in). Estructura upstreamable en `contrib/treefrogui-apps/net_mode/`.
- Futuro: la UI FrogUI gana una entrada "NETWORK" que llama `net_mode.sh` directo (mismo wiring que USB MODE → usb_mtp.sh); `usb_mtp.sh` vuelve entonces al upstream verbatim.
