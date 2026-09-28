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

## ADDENDUM v2 (2026-09-27) — DEPLOY v1 FALLECIÓ EN `mkdir ffs.adb`: causa raíz cazada

**Evidencia física (deploy v1, kernel `0b549b84`)**: menú/boot/MTP 100% OK
(USB MODE PHYSICAL PASS con el kernel nuevo). NETWORK con `adb.mode` → **retorno
inmediato al menú** (sin reinicio de consola, sin sonido USB en Windows). Log
`ADB_MODE_DEBUG.log` (leído via MTP COM desde el PC):

```
mkdir: can't create directory '.../usb_gadget/adb_ffs/functions/ffs.adb': Device or resource busy
ln: .../configs/c.1/ffs.adb: No such file or directory
FAIL link → exit 1 → menú
```

**Causa raíz (análisis del código del tree 5.12.4 — evidencia citada):**

1. `CONFIG_USB_FUNCTIONFS=y` (v1) compila el driver **legacy** `g_ffs.c`
   BUILT-IN (`legacy/Makefile:32`).
2. Su `module_init(gfs_init)` con solo FUNCTIONFS_GENERIC → `func_num<2` →
   `gfs_single_func=true` → `usb_get_function_instance("ffs")` +
   **`ffs_single_dev()` marca el único instance ffs como `single`**
   (g_ffs.c ~186-206).
3. Desde el boot, CUALQUIER `mkdir ffs.*` en configfs pasa por
   `_ffs_alloc_dev()`: `if (_ffs_get_single_dev()) return ERR_PTR(-EBUSY)`
   (f_fs.c:3629-3631) → **EBUSY exacto del log**, desde boot limpio.

El legacy sabotea el camino configfs consumiendo el instance único. **El
configfs NO necesita el legacy**: `CONFIG_USB_CONFIGFS_F_FS` selecciona
`USB_F_FS` (f_fs.c se compila igual; solo deja de construirse g_ffs.c).

**Fix v2 (1 línea fragment):** `CONFIG_USB_FUNCTIONFS=y` →
`# CONFIG_USB_FUNCTIONFS is not set` (se mantiene `CONFIG_USB_CONFIGFS_F_FS=y`).
Rebuild k512 v2 → redeploy → retest 3 fases.

**Fix stack (fork `4d4278c`):** el `mkdir ffs.adb` con error era enmascarado
por el fallback `log "ffs.adb exists"` — ahora es fatal con pista de
diagnóstico (`FAIL mkdir ffs.adb (kernel: ... legacy FUNCTIONFS off?)`).

Discriminator físico del deploy v1 que valida la hipótesis de partida: MTP
(role switch + configfs + musb) funciona perfecto en el kernel 0b549b84 →
el fallo era SOLO del camino ffs.

## ADDENDUM v3 (2026-09-27 noche) — kernel v2 OK; daemon v1 murió por la fase STRINGS de ffs

**Evidencia física (deploy v2, kernel `5adde850`)**: NETWORK → **mkdir ffs.adb
OK** (`gadget creado (ff/42/01, 2 bulk eps)`), mount functionfs OK, role OK
→ el fix del legacy FUNCIONA. Pero:

```
min_adbd: open endpoints: No such file or directory
FAIL UDC bind after 30 tries (15 s) → restore → menú
```

El "sonido de conexión" de Windows NO fue enumeración: fue el role switch a
peripheral sin gadget bindeado (musb sin pullup de descriptores).

**Causa raíz #2 (f_fs.c:330-395)**: la máquina de estados ffs es
`READ_DESCRIPTORS → READ_STRINGS → epfiles_create → FFS_ACTIVE`. **ep1/ep2
solo existen tras la fase STRINGS** — el daemon v1 escribía descriptores y
saltaba las strings (iInterface=0 ⇒ asumimos omitibles). El ffs quedó en
READ_STRINGS para siempre → open ep1 ENOENT → sin activación → bind nunca.

**Fix (daemon-only, kernel v2 queda)**: tras los descriptores, escribir el
bloque STRINGS mínimo — `str_count=0, lang_count=0` — que `__ffs_data_got_strings`
acepta cuando los descriptores no referencian strings (`if (!needed_count)
return 0`, f_fs.c:2600). Binario `min_adbd` v2:
`72784bfb5ce8171f3c7e318106f174b1c02d3a1691c28a48dd4808ba84277bd9`.
Fork commit `eb17efc`. Deploy: solo `treefrog/min_adbd`.

## ADDENDUM v4 (2026-09-27 noche 2) — enumeración OK + SIN OVERLAY; adb v37 caía por transfer única header+payload — fix: DOS transfers (patrón adbd)

**Estado físico tras v3** (kernel `5adde850` + daemon v2 + serial USB en el
gadget): **Windows enumera "TreeFrogUI ADB (FunctionFS)", WinUSB bound
(`winusb.inf` "ADB Device", match inbox ff/42/01), sesión ESTABLE y
SIN OVERLAY AZUL durante conexión prolongada.** El fix del serial era
obligatorio: adb DESCARTA devices sin iSerialNumber
(`usb_windows.cpp:603 cannot get serial number -> usb_cleanup_handle`,
trace ADB_TRACE=usb).

**Síntoma restante**: `adb devices` vacío; el server repetía cada 1s:
`adding a new device → CNXN (24+302 escritos) → usb_read got: 142 →
connection terminated: read failed → kick`.

**Diagnóstico local (todo reproducido sin tocar la consola):**
1. **Harness TCP** con el mismo core del daemon (test_adbd.c): `adb connect`
   + `adb devices` = **device** + **`adb shell` funciona** → protocolo y shell
   100% correctos (CRC verificado: crc32("123456789")=cbf43926).
2. **Probe WinUSB propio** (csc/C#): CNXN exchange OK por USB — PERO los
   descriptores ACTIVOS muestran **EP OUT=0x01** (el autoconfig de ffs
   renumeró el 0x02 declarado; IN=0x81, ambos bulk 512, HS).
3. **Source de adb** (mirror LineageOS = packages/modules/adb): causa raíz
   final en `client/transport_usb.cpp` — `UsbReadMessage()`: lee un chunk de
   `max_packet_size` (512) y **requiere `n == 24` exacto** para el header;
   el daemon v2 enviaba header+payload como **UNA transfer de 142 B** →
   `n=142 != 24` → connection terminated. El adbd real envía header y
   payload como **writes separados** (`daemon/usb.cpp Write()`:
   header block + payload blocks, con ZLP cuando el payload es múltiplo del
   maxpacket — usb_ffs zero_mask). TCP funciona porque el socket lee los
   24 bytes exactos progresivamente.

**Fix v3 (daemon-only):** `send_pkt` = write(24 header) + write(payload)
(+ ZLP si `len & 511 == 0`), patrón adbd exacto. Binario:
`eb005c8505b9abd7026c8dd7ad72a529e16569fdc7b039d0dc938430e248e2c4`,
fork commit `234b1d5`. Kernel y stack sin cambios.

**Evidencia de overlay acumulada hasta aquí**: gadget ffs enumerado + idle
prolongado + CNXN repetido cada 1s durante ~20 min → **CERO overlay**
(muy por encima de la referencia NCM de ~30 s). La consola quedó usable
(USB MODE/MTP verificado durante la sesión).

## ADDENDUM v5 (2026-09-27 madrugada) — transporte ONLINE; shell colgado por stream huérfano — fix daemon v4

Con el fix v3 (dos transfers), **db devices = R36SX0001 device** (transporte
ONLINE, banner parseado). Pero db shell colgaba. Trace ADB_TRACE=usb,transport
evidenció dos bugs del daemon (ambos introducidos/expuestos por mis propios
probes):

1. **Stream huérfano**: un probe abrió shell: y terminó sin CLSE → daemon
   quedó have_stream=1 → el OPEN real del server fue rechazado con CLSE
   (trace: 	o remote [OPEN] arg0=3 shell:uname -a → rom remote [CLSE]
   arg0=1 arg1=3) → shell nunca abre → hang. **Fix: cada CNXN resetea el
   estado de stream** (nueva conexión = estado limpio; host muerto
   mid-stream no bloquea al siguiente).
2. **Servicio sin NUL**: el probe envió shell:uname -a sin el NUL de
   terminación (adb real manda 15 bytes con NUL — hex del trace) → el parser
   leyó basura tras data_length → sh ejecutó uname -a<garbage> →
   uname: invalid option. **Fix: copia defensiva del servicio acotada a
   data_length con NUL garantizado.**

Binario min_adbd v4: ebe57ed97f14c2e37c69a08512d6f1e5d44aeca6bdb5b22a4e6bdea9094b6732,
fork commit de7015. Nota menor: emulator-5562 (resto Genymotion en
localhost:5562/5563) agrega ruido de reconexión al server — inofensivo para el
device R36SX.
