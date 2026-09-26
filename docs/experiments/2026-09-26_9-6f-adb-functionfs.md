# 2026-09-26 — 9-6f: ADB via FunctionFS — ¿shell sin overlay azul?

**Fase:** 9-6f (ADB / FunctionFS)
**Kernel:** 5.12.4 k512 `0b549b84` (BUILD PASS 13:21, NO desplegado aún)
**Estado:** EN CURSO — implementación completa (kernel + daemon + stack), deploy
y test físico PENDIENTES (autorización Clase F).

## Objetivo

Probar que un gadget **FunctionFS** (ADB, clase vendor-specific 0xFF) da shell
remota root **sin disparar el overlay azul del AVP** — verificando si el
discriminante del AVP es la clase USB / el perfil de tráfico, sin necesidad del
RE del firmware AVP (pausado tras F1b).

## Hipótesis (de la evidencia 9-6e, ADR-015)

El disparador documentado es **networking activo en cualquier forma**:

| Transporte | Clase USB | netdev/pppd | Overlay | Referencia |
|---|---|---|---|---|
| MTP | 0xFF vendor | no | **NO** | 9-6b PHYSICAL PASS |
| CDC-ACM serial (shell puro) | 02/02/01 modem | no | **NO** | 9-6e v13 |
| CDC-ACM + pppd | 02/02/01 modem | **ppp0** | **SÍ** | 9-6e addendum |
| RNDIS | e0/01/01 | usb0 | **SÍ** | 9-6e v1 |
| CDC-NCM | 02/0d/00 | usb0 | **SÍ** (a los ~30 s, stateful) | 9-6e v6 |
| **FunctionFS ADB (este)** | **0xFF/0x42/0x01** | **no** | **? — A TESTEAR** | — |

FunctionFS+ADB: mismo perfil de tráfico interactivo que ACM serial
(overlay-free probado), misma clase vendor-specific que MTP (overlay-free
probado), sin netdev/u_ether/pppd. Predicción: **sin overlay** en las tres
fases del test.

## Implementación (todo HOST/BUILD PASS al corte)

### Kernel (este repo)

Fragment `boards/r36sx-v26/kernel/r36sx-v26-k512.config.fragment`:

- `CONFIG_USB_FUNCTIONFS=y` + `CONFIG_USB_CONFIGFS_F_FS=y` (→ `USB_F_FS=y`
  vía select; `FUNCTIONFS_GENERIC=y` auto-select del legacy g_ffs, inerte).
- El mismo build lleva los módulos 9-6d F2 (`USB_USBNET/CDCETHER/RNDIS_HOST=m`)
  — **inertes sin insmod**; experimento 9-6d-F2 separado.

Build 2026-09-26 13:21 (`r36sx-v26-k512-build_20260926_132019.log`):
`f_fs.o` + `g_ffs.o` compilados, error `target-post-image` benigno conocido
(`bigger than partition` en romfs.img — imágenes ya generadas).

- **TOOLCHAIN PROVENANCE: PASS** (vermagic `5.12.4-release ... mips-mti-linux-gnu-gcc 6.3.0 ... Sat Sep 26 13:21:04`)
- **PATCH PROVENANCE: PASS** (21 vendor + 5×900X + 6×910X, hashes idénticos repo↔SDK)

### Artefactos

| Artefacto | SHA-256 | Tamaño |
|---|---|---|
| `vmlinux.uImage` (kernel 9-6f) | `0b549b8477681e657bb8a3b03843bcef3d5c489ad7ee5301a3b1e718db31c0be` | 8.425.980 B |
| `dtb.bin` (SIN cambios = known-good) | `116ddf26d87dbdf021dbc2624ad28d91e4e9df2c85c6a75b7d1ec9f927195a2b` | 33.250 B |
| `rootfs.cpio` (embed determinista) | `829e0cd8ab5f1f268f6a60db6cd76017305727fb36676602b7ec8100483bf6e7` | — |
| `min_adbd` (daemon, fork TreeFrogUI) | `516fe6e538a831896edbc8a340f20d7b60bfb8fb2e3a31026b16ca84cce325ad` | 611.540 B |

**Una variable principal:** solo cambia `vmlinux.uImage` en la SD (dtb/avp/rootfs
idénticos al known-good `c6e3cc70`).

### Userspace (fork TreeFrogUI `net-mode-app` `9ad7e89`, AGENTS §15)

- `apps/adb_mode/min_adbd.c` (+ binario estático mipsel prebuilt):
  daemon ADB mínimo — descriptores ffs V2 (ff/42/01, 2 bulk EPs: cabe en el
  budget 4-EP del MUSB), CNXN non-secure (sin AUTH/RSA), servicio **shell:**
  v1 raw (features=shell — el host NO negocia shell_v2/PTY), flow control
  1-WRTE-outstanding, resto de servicios → CLSE. Estático (`-static -Os`,
  MTI 6.3.0, headers uapi del sysroot Codescape), `-Wall -Wextra` limpio.
- `apps/adb_mode/adb_mode.sh`: gadget configfs `adb_ffs` (0x18d1:0x4EE2) +
  mount functionfs + daemon (copia a RAM /tmp/bin, como el patrón net_mode) +
  **UDC bind con retry** (el daemon debe abrir ep0/ep1/ep2 antes — activación
  ffs) + sesión bloqueante con exit_watcher (B/cable) + teardown completo
  (`adb_mode.sh stop`), log separado `ADB_MODE_DEBUG.log`.
- Dispatcher `apps/net_mode/net_mode.sh`: flag **`adb.mode`** en la raíz de la
  SD → `adb_mode.sh` (mismo mecanismo que `ppp.mode`/`ecm.mode`).
- `apps/adb_mode/deploy_adb_mode.sh`: instala scripts+binario+dispatcher y crea
  el flag.

## Plan de test físico (3 fases, una variable)

SD en lector → deploy (ver abajo) → boot → conectar USB al PC → menú **NETWORK**
(lanza `adb_mode.sh` sesión bloqueante).

- **Fase A — enumeración idle**: PC `adb kill-server; adb devices` (esperado:
  `R36SX0001 device`). **Esperar ≥60 s** mirando el display (el overlay NCM
  apareció a los ~30 s). Registro: foto del display + timestamp.
- **Fase B — shell interactivo**: `adb shell` → `uname -a`, `free`, `ls
  /mnt/sdcard`. Observar el display durante el uso. Salir (`exit`).
- **Fase C — tráfico bulk sostenido**: `adb shell 'dd if=/dev/urandom
  bs=4096 count=2048 | base64'` (≥8 MB de output) — perfil de throughput
  parecido al file-transfer MTP (probado overlay-free). Observar display.
- **Salida**: botón B (exit_watcher) → verificar `restore done rc=0` en el log
  y que el menú queda limpio.
- Evidencia por fase: `ADB_MODE_DEBUG.log` (consola) + fotos del display +
  `adb devices` output (PC).

**Resultados posibles:**
1. Sin overlay en A/B/C → 9-6f PASS: promover `adb_mode.sh` a transporte
   shell/debug de producción (primera shell overlay-free usable sin COM
   terminal); iterar FrogUI entry dedicada.
2. Overlay en alguna fase → nueva evidencia del discriminante del AVP
   (¿tráfico bulk no-red?, ¿timing?); documentar y comparar contra MTP.

## Deploy plan (Clase F — REQUIERE AUTORIZACIÓN EXPLÍCITA)

Backup previo: el known-good `c6e3cc70` ya está preservado
(`G:\boot\vmlinux.uImage.prev-d3.bak` + backup SD completo 2026-09-23).

```bash
# WSL, con la SD montada en /mnt/g
cp /mnt/g/boot/vmlinux.uImage /mnt/g/boot/vmlinux.uImage.prev-96f.bak   # rollback 1-comando
cp ~/work/r36sx-hclinux/build/r36sx-v26-k512/images/vmlinux.uImage /mnt/g/boot/vmlinux.uImage
cd /mnt/d/GitHub/TreeFrogUI/apps/adb_mode && ./deploy_adb_mode.sh /mnt/g
# dtb.bin, avp.uImage, rootfs/, treefrog/ existentes: SIN cambios
sync
```

Rollback: restaurar `vmlinux.uImage.prev-96f.bak` → `vmlinux.uImage` y borrar
`adb.mode`. Recovery extremo: NOR intacto (no se toca BootROM/bootloader —
solo archivo en SD) + `HCFOTA-factory-restore.bin` si fuera necesario.

## Estado al cierre de esta iteración

- Commits: fragment 9-6f+9-6d-F2 (este repo) + fork `9ad7e89` (apps/adb_mode).
- Pendiente: GO Clase F del usuario → deploy → test físico 3 fases →
  PHYSICAL PASS/FAIL documentado.
