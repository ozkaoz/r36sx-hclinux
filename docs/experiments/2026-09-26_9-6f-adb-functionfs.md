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

## ADDENDUM v6 (2026-09-28) — OPEN aceptado (OKAY) pero el output del shell nunca fluye; fix RAM-shell + pump instrumentado

Con daemon v4: CNXN OK, transport ONLINE, OPEN aceptado con **OKAY** (trace +
probe WinUSB propio), pero **el WRTE del output del shell jamas llega** (probe:
8s timeout tras el OKAY; adb server: 30s sin un byte). El daemon queda vivo
(procesa CLSE posterior). Ambos caminos (-c e interactivo) identicos.

Hipotesis operativa (evidencia net_mode): **exec de /bin/sh desde el rootfs
bind-mounted (SD) con el musb activo puede deadlockear** — exactamente el
patron documentado en net_ncm.sh ("RAM shell wrapper: busybox y exit_watcher
en tmpfs. Sin esto, fork/exec lee del SD bind-mounted mientras el musb
satura el bus"). min_adbd corria desde RAM (/tmp/bin) pero su CHILD exec
/bin/sh desde el SD.

Fix v5 (fork 3faad58):
1. adb_mode.sh crea el RAM shell wrapper ANTES de lanzar el daemon (busybox
   -> /tmp/bin/busybox + /tmp/bin/sh, patron net_mode).
2. min_adbd exec /tmp/bin/sh (fallback /bin/sh).
3. pump instrumentado: logmsg por cada WRTE (bytes + rc) — si vuelve a
   fallar, ADB_MODE_DEBUG.log cuenta la historia exacta via MTP.

Binario ecc891c2. Deploy v7 = min_adbd + adb_mode.sh.

## ADDENDUM FINAL (2026-09-28) — RESULTADO DEL EXPERIMENTO + DEFECTO DEL SHELL DOCUMENTADO

### La pregunta del experimento: RESPONDIDA — SIN OVERLAY

**Hipótesis confirmada en todas las sesiones fisicas (17 boots, ~6h de sesion live):**
gadget ffs (clase 0xFF, ADB ff/42/01) enumerado + idle + CNXN cada 1s por ~20min
+ todo el martilleo de la sesion de debug → **CERO overlay azul** (referencia NCM:
~30s). La consola queda usable (menu/USB MODE/MTP verificados durante sesiones).
El transporte \db devices\ = **R36SX0001 device estable en cada boot**.
**9-6f OVERLAY: PASS.** El shell interactivo ADB queda como defecto abierto.

### Cadeena de bugs REALES arreglados (cada uno verificado en consola)

1. legacy g_ffs built-in reclama el instance ffs unico → EBUSY en configfs
   (g_ffs.c module_init; f_fs.c:3629 guard) → FUNCTIONFS=n (kernel v2 5adde850)
2. FSM ffs exige fase STRINGS antes de crear ep1/ep2 (f_fs.c:330-395) → bloque
   STRINGS vacio (f_fs.c:2600 acepta sin refs)
3. adb descarta devices sin iSerialNumber (usb_windows.cpp:603) → serial en configfs
4. adb Windows exige header == 24 bytes exactos por chunk (transport_usb.cpp
   UsbReadMessage) → send_pkt en DOS writes + ZLP (patron adbd daemon/usb.cpp)
5. stream huerfano rechia el OPEN real con CLSE → reset de stream por CNXN
(+ fix del ethernet del PC: DHCP deshabilitado + IP manual residual 169.254)

### El defecto del shell: evidencia completa y teorias eliminadas

**Sintoma final (v15-v17):** worker ash interactivo spawneado EN EL ARRANQUE
(pre-bind: ash-alive en log), alimentado por stdin post-bind → **MUTE absoluto**
(ni output, ni EOF, ni un byte en el pipe). El daemon (estatico) corre perfecto
en el mismo estado. Autorespawns y feeds via top-level probados.

**Teorias ELIMINADAS por experimento:** colisiones de fd (log: limpias), fd0 pipe
(cerrado: igual), prctl (eliminado: igual), shell/applets en RAM (igual), largo
de argv 1..80 (todos mudos), orden del fork (v4 mudo siendo fork#1), frame de
4KB en stack (static: igual), contexto del fork (top-level: igual), parens del
feed / subshell (eliminados v17: igual), dinamico vs estatico (busybox estatico
construido con el mismo config: igual).

**Anomalias que delimitan el problema:** (a) v3-probe: el shell completo corrio
y fluyo (362B) SIN read pendiente en ep_in; (b) v8 selftest: fork+exec+output
fluyen LIVE con el server conectado; (c) worker pre-existente alimentado
post-bind: mudo. La variable discriminante restante apunta al estado del musb
con IN-request perpetuamente pendiente (como lo mantiene el server adb) vs
reads transitorios (probe), interactuando con el scheduler/wakeup de procesos
que NO estan en el camino USB — sospecha kernel-side: el musb portado (9102)
con f_fs en estado armed-TX.

### NEXT EXACT ACTION (proxima sesion)

1. **Diagnostico definitivo desde el lado NCM**: remover adb.mode → NETWORK
   (NCM) → telnet → con el adb gadget EN SESSION (segunda consola... o
   re-entrar adb tras NCM) → \cat /proc/<worker_pid>/stat /proc/<worker_pid>/wchan   → estado R/S/D del worker mientras esta mudo: D = bloqueo kernel/driver
   confirmado; S = wakeup nunca disparado; R = starvation.
2. Capturar los logs finales (v16/v17) de la SD.
3. Si D/wchan apunta al musb → audit del 9102 (musb port) en el estado
   TX-armed; posible fix kernel o workaround en el daemon (p.ej. no mantener
   el worker: 1 worker por comando spawneado pre... inalcanzable — evaluar).
4. Alternativa productiva YA disponible: NCM (telnet) para shell; ADB queda
   en alpha (devices/transport OK, shell PENDIENTE).

Artefactos: kernel 5adde850 (sin cambios desde v2) · daemon v17 f75f6eaf ·
busybox-static 0110be2a · fork TreeFrogUI net-mode-app 988c8b6.

## CIERRE FINAL v2 (2026-09-28 noche) — EL SHELL ADB VIVO: builtins ejecutan; el fork externo queda como defecto kernel vendor

### LA CADENA DE ROOT CAUSES COMPLETA (todas confirmadas empiricamente)

1. **ffs IN-writes bloquean hasta que el host consume** (experimento keeper2:
   CNXN con read pendiente = respuesta cada ciclo; sin read = daemon muerto).
2. **El ffs vendor IGNORA O_NONBLOCK en AMBAS direcciones** (v22: freeze dentro
   del write del OKAY; v23: freeze dentro del read de ep_out justo tras el OPEN).
3. **Solucion: aislamiento total por threads (v24)**: reader/writer/ep0 dedicados
   que PUEDEN bloquear + loop principal que solo toca pipes/procfs/usleep.
   v24b fix: fds blocking para sus threads (el O_NONBLOCK heredado mataba al
   reader con EAGAIN al arranque).
4. **EL PIPELINE COMPLETO VIVO (v24b/v25, prueba del cat):** OKAY -> feed ->
   output -> marcador -> CLSE -> adb shell RETORNA.
5. EL SHELL EJECUTA (v25): adb shell 

5. EL SHELL EJECUTA (v25): adb shell "echo hello" => hello en el PC — comando
   ejecutado en la consola, output via USB, pantalla limpia, SIN overlay.

### Estado funcional final del shell ADB

- Gadget + transporte + protocolo ADB completo: FUNCIONA (device cada boot)
- Builtins del shell (echo, printf, cd, test...): FUNCIONA (multi-sesion)
- Applets externos (id, uname, ls, cat...): COLGADO — fork() dentro del worker
  ash bajo el gadget ffs live congela al hijo (kernel vendor). Descartados:
  STANDALONE+NOFORK (id es NOEXEC: forkea igual), FD_CLOEXEC (tabla worker
  limpia: igual), busybox estatico, todo-RAM.
- Overlay azul (canal ADB): CERO en todas las sesiones (resultado estable)
- Overlay NCM: CONFIRMADO PRESENTE (patron ~30s, reverificado 2026-09-28)

### La pista para el fix definitivo (kernel-side)

Asimetria clave: telnetd/NCM forkea+executa perfecto bajo su gadget. Solo el
ffs rompe los forks. Fork con ffs endpoints vivos + ops pendientes en los
threads del daemon = hijo congelado. Sospecha: musb portado (9102)/f_fs en
el camino de copy_process/fdtable con USB activo. Reproduccion 100% fiable:
adb shell "id" en sesion fresh.

### Alternativa inmediata sin tocar kernel: servicio adb sync (push/pull)

El file-transfer NO requiere forks (puro I/O — el pipeline ya vive). Implementar
sync: en el daemon = push/pull de archivos SIN overlay y SIN shell — el valor
restante del canal ADB hoy alcanzable con la arquitectura v26 tal cual.

### Artefactos finales

- Kernel 5adde850 (v2) — fragment: FUNCTIONFS=n + CONFIGFS_F_FS=y
- min_adbd v26 c94bd39d: threads ffs-isolated + CLOEXEC + worker + marcador
- busybox-static v3 337253d1: STANDALONE+NOFORK (inofensivo, conservar)
- adb_mode.sh: RAM shell+applets, wrapper alive-proof, flag adb.mode
- Fork TreeFrogUI net-mode-app 8f42063
- PC: registry EnhancedPowerManagementEnabled=0 (R36SX0001); NTKDaemon (Wacom,
  puerto 5563) = el "emulator-5562" fantasma del server adb (identificado)
