# POST-MORTEM: El camino al brickeo de la R36SX V2.6 (2026-09-19/20)

> Documento de lecciones técnicas. La consola QUEDÓ BRICKEADA por software
> (pantalla negra, sin boot) tras el flash del bootloader propio (D-2c).
> El mecanismo de recuperación por software está agotado; la restauración
> requiere intervención física (CH341A + clip SOP-8, o corto de pines 2/4).

## Cronología del incidente

### Contexto: qué funcionaba antes
- La consola arrancaba 100% con desarrollo propio (kernel + rootfs Buildroot
  + TreeFrogUI completo: audio, video, salida de emuladores — PHYSICAL PASS
  total en Fase 8).
- `cubegm/` ya estaba reducido a su mínimo NOR: 4 archivos de boot + 2 goldens.

### Paso 1: El objetivo
> "Eliminar cubegm/ al 100% de la SD"

La investigación fue sólida: el path `cubegm/` es la propiedad `path-prefix`
del nodo `/hcrtos/external_files` del **NOR-DTB del bootloader**. El objetivo
exigía reemplazar el bootloader de NOR (zona prohibida §5, con GO explícito).

### Paso 2: D-1 — Dump NOR (la decisión que salvó todo)
- Dump bit-a-bit del NOR desde Linux (`/dev/mtd*ro`, hashes verificados).
- **DDR-init de fábrica extraído byte-exacto** (`d944d9af…`) — no coincidía
  con NINGÚN ddrinit del SDK → decisión correcta: usar solo el extraído.
- Bootloader de fábrica **descomprimido** (LZMA @0x5e48): `hcboot-custom`
  del proyecto `e3100_cube`.
- **NOR-DTB de fábrica extraído** del payload (`factory-nordtb-0.dtb`) —
  disponible desde este momento.

### Paso 3: D-2a' — Prueba del mecanismo MTD (PASS)
- Re-escritura de bytes IDÉNTICOS de fábrica sobre `/dev/mtd1`.
- Readback byte-a-byte verificado → reboot → consola idéntica = mecanismo probado.

### Paso 4: D-2b — Build del bootloader propio

**Piezas correctas:**
- bl defconfig derivado de `cb_d3100_v10_projector_c3_q6` (familia d3100 + dualcore)
- **DDR-init de fábrica** con verificación sha256 en build_kernel.sh
- Entry point adaptado automáticamente por el hook del SDK (`0x89EB0000` ==
  DDR-init `0xa9eb0000`) ✓
- **Parche dual-path fallback** (`/boot/` → `cubegm/`) compilado ✓
- Módulo UPGRADE completo (SD/USBHOST) incluido ✓
- 2.702 strings comunes con fábrica (método 9a) ✓

**LA PIEZA QUE FALTÓ — el error crítico:**
- El NOR-DTB embebido se compiló desde **nuestro DTS stock-normalized**
  (el mismo que genera el `dtb.bin` de la SD).
- **El gate semántico** (`compare_dtb_semantics.sh`) comparaba contra
  `reference/stock-normalized.dts` (el dtb de la SD).
- **NADIE comparó el NOR-DTB compilado contra el `factory-nordtb-0.dtb`** —
  que ya teníamos extraído desde D-1.

### Paso 5: D-2c — El flash (byte-perfecto, consola brickeada)
- Imagen: `bootloader.bin` (425.504 B) con padding 0xFF a 442.368 B.
- Flash ejecutado con GO explícito del usuario.
- **mtdnor verificó el readback byte-a-byte → el flash fue impecable.**
- Reboot → **PANTALLA NEGRA, Linux nunca arrancó.**

---

## Causa raíz

```
Nuestro build compiló el NOR-DTB desde el DTS stock-normalized
    ↓
Ese DTB tiene una panel-init-sequence LARGA (la del kernel/SD)
    ↓
El NOR-DTB de FÁBRICA tiene una secuencia CORTA (diferente)
    ↓
El bootloader usa fdtp (SU NOR-DTB embebido) para TODO su hardware init
    ↓
LCD init con la secuencia/pinmux/LP-CLK-DIV equivocados → el panel
queda mal inicializado / el driver se cuelga o crashea
    ↓
El bootloader muere ANTES de cargar cualquier archivo de la SD
    ↓
No hay Linux → no hay S09trace → no hay mtdnor → no hay recovery por SD
```

**Diff del NOR-DTB de fábrica vs el nuestro (89 líneas):**

| Propiedad | Fábrica | Nuestro | Impacto |
|---|---|---|---|
| `panel-init-sequence` | CORTA (3 comandos) | LARGA (100+ comandos) | **LCD mal inicializado** |
| `LP-CLK-DIV` | ausente | `<0x02>` extra | Reloj DSI incorrecto |
| `pinmux-active` | 4 pines | 6 pines (extra) | Pines mal configurados |
| `uart@1` | `status="okay"` + pinmux | Ausente | Sin consola serial |
| `bootargs` | `console=ttyHC0,115200N8` | `console=tty1` | Sin earlycon |
| `path-prefix` | `"cubegm"` | `"boot"` | El cambio intencional ✓ |

## Por qué cada intento de recuperación falló

| Intento | Por qué falló |
|---|---|
| **S07norflash** (auto-flash en boot) | Requiere que Linux arranque → nunca arrancó |
| **HCFOTA.bin en raíz de SD** | `upgrade_force()` se dispara solo si un `bootm` falla → el bl muere antes de llegar a cualquier bootm |
| **HCProgrammer USB** | El sondeo USB (`sys_hcprogrammer_check_timeout`, bootm_os.c:88) corre en el bootloader **justo antes de lanzar el kernel** → nunca se ejecutó |
| **Tecla upgrade** | El nodo `hcfota-upgrade` no existe ni en el NOR-DTB de fábrica |
| **Serial** | `serial0 = "/hcrtos/uart_dummy"` en nuestro NOR-DTB + no hay cable |

## Las lecciones (para ADR)

1. **El gate semántico del DTB comparaba contra la referencia equivocada para
   el bootloader**: para el KERNEL, la referencia correcta es el `dtb.bin` de
   la SD (stock-normalized). Para el BOOTLOADER, la referencia correcta es el
   **NOR-DTB de fábrica** extraído del bootloader descomprimido. Son DTBs con
   propósitos distintos y contenido diferente.

2. **Teníamos la evidencia y no la usamos**: el `factory-nordtb-0.dtb` fue
   extraído en D-1, pero nunca se hizo un diff completo contra nuestro NOR-DTB
   compilado antes del flash. El diff habría revelado las 89 líneas de
   diferencia (incluida la secuencia del panel) y el flash no se habría ejecutado.

3. **La "una variable por boot" se violó en el flash**: en un solo flash
   cambiamos: el bootloader completo + el NOR-DTB (path-prefix + panel +
   pinmux + uart) + el defconfig fuente. Si hubiéramos flasheado primero un
   bootloader con el NOR-DTB de fábrica VERBATIM (solo path-prefix cambiado),
   habría funcionado.

4. **El mecanismo de flash fue impecable**: DDR-init correcto, entry correcto,
   readback verificado. El brickeo fue por CONTENIDO (el DTB), no por PROCESO.

## El fix-forward (diseñado, no ejecutado)

Si la consola se restaura (vía CH341A + clip SOP-8, o corto de pines 2/4):

1. bl DTS = decompile del `factory-nordtb-0.dtb` (la referencia CORRECTA) +
   SOLO `path-prefix="boot"` cambiado.
2. Nodo `hcfota-upgrade` con SELECT como tecla upgrade (decisión del usuario).
3. Dual-path fallback ya compilado ✓
4. DDR-init de fábrica ya integrado ✓
5. **Gate nuevo**: diff completo NOR-DTB compilado vs factory-nordtb-0.dtb =
   0 líneas de diferencia (excepto path-prefix + hcfota-upgrade).

## Estado de la consola al cierre de este documento

- NOR contiene nuestro bootloader (flash verificado byte-a-byte)
- Pantalla negra al encender; Linux nunca arranca
- La SD no influye en el estado (probado con 2 SDs distintas)
- Recuperación por software: agotada
- Recuperación física: `D:\R36SX\hcprogrammer-restore-kit\factory\spinorflash.bin`
  (512 KB, bytes exactos de fábrica) + CH341A + clip SOP-8 (recomendado)
  o corto de pines 2/4 del NOR SOP-8 al encender (método oficial HiChip)

---

## RECUPERACIÓN EXITOSA (2026-09-21) ✅

**La consola fue revivida mediante el corto de pines 2/4 del NOR + HCProgrammer USB.**

### Procedimiento que funcionó:

1. **Corto de pines 2/4** (pin 1 = punto, lado izquierdo contando hacia abajo:
   pin 2 = segundo = MISO, pin 4 = abajo = GND) — con la consola apagada,
   USB-C ya conectado al PC.
2. **Encender la consola** con el corto activo → el BootROM no puede leer
   el NOR (MISO a GND) → entra al modo USB de chip-vacío.
3. **Windows reconoce el dispositivo** como "HiChip 16xx USB Device".
4. **Driver**: `HiChip16xxUSB.inf` (del SDK, en `driver/` del kit).
5. **HCProgrammer.exe** con "Firmware select" =
   `HCFOTA-factory-restore.bin` (generado por HCFota_Generator oficial:
   updater + DDR-init de fábrica + 3 particiones del NOR con bytes del dump).
6. **Start Burn** → el tool detecta el dispositivo, inicializa DDR con los
   parámetros de fábrica, carga el flash-writer (updater), y escribe el NOR.
7. **Reboot** → el bootloader de FÁBRICA arranca → pantalla normal →
   TreeFrogUI bootea correctamente.

### Hallazgos técnicos del proceso de recuperación:

- **HCProgrammer requiere ambos ejecutables abiertos simultáneamente**
  (HCProgram.exe + HCProgrammer.exe) para que la detección funcione.
- **El formato de firmware correcto es HCFOTA.bin** (generado por
  HCFota_Generator con `-r ddrinit.abs -p hc16xx_jtag_updater.bin`).
  El `spinorflash.bin` (binario crudo del NOR) NO funciona — el tool
  busca secciones "updater" y "DDR info" dentro del archivo.
- **El modo USB del BootROM persiste mientras el corto 2/4 esté activo**
  (la línea MISO a GND mantiene el BootROM en blank-chip mode).
- El HCFOTA.bin exitoso parsea con: Version=2609200000, Product=HC16D3100V20,
  3 particiones (boot + eromfs + persistentmem), versión check disabled.

### Archivo final que revivió la consola:

```
D:\R36SX\hcprogrammer-restore-kit\HCFOTA-factory-restore.bin
(988.648 B, sha256 29ed112c766fbe5c…)
```

### Lecciones de la recuperación:

1. El formato HCFOTA.bin (no el binario crudo) es el que el HCProgrammer
   espera como "firmware".
2. El DDR-init de fábrica (`d944d9af…`) es esencial — el tool lo envía al
   BootROM para inicializar RAM antes de poder flashear.
3. El `hc16xx_jtag_updater.bin` del SDK es el flash-writer que corre en
   el chip para escribir el NOR.
4. El corto 2/4 es seguro y reversible (MISO a GND durante el power-on).
5. La paciencia y el orden correcto (corto → encender → detectar → flashear)
   son críticos: el BootROM sale del modo USB si pasa demasiado tiempo.

### Estado final de la consola:

- **NOR = bytes exactos de fábrica** (bootloader stock + eromfs + persistentmem).
- **Pantalla normal, TreeFrogUI funciona**.
- La SD con nuestro kernel 8e + rootfs propio + TreeFrogUI sigue funcional.
- El caso cubegm queda como estaba antes del flash del bootloader propio.

---

## SEGUNDO INCIDENTE (2026-09-21, tarde) — fix-forward con NOR-DTB correcto TAMBIÉN brickeó

**Contexto:** Se implementó el fix-forward diseñado (DTS desde factory-nordtb-0.dtb,
GATE PASS con /hcrtos/ == fábrica). El NOR-DTB compilado tenía la secuencia
CORTA de panel, pinmux y uart de fábrica — la causa raíz del PRIMER brickeo
estaba eliminada. Sin embargo, la consola siguió en pantalla negra.

**GATE PASS en el build:**
- panel-init-sequence: FÁBRICA (CORTA) ✓
- pinmux: FÁBRICA ✓
- uart: FÁBRICA ✓
- path-prefix: "boot" (cambio deliberado) ✓
- hcfota-upgrade: SELECT (cambio deliberado) ✓

**Causa probable (no confirmada por falta de serial):**

La causa raíz NO era solo el NOR-DTB. El binario `hcboot` compilado desde
nuestro SDK (2024.02.y.2) tiene diferencias adicionales respecto al
`hcboot-custom` de fábrica que causan pantalla negra incluso con el DTB correcto:

1. **CONFIG_BOOT_HCRTOS_OR_HCLINUX_DUALCORE (nuestro) vs boot always-dualcore (fábrica)**:
   El defconfig c3_q6 tiene modo OR (condicional según standby slot). Si el
   slot no es SECONDARY, el bootloader intenta bootear HCRTOS en vez de Linux
   → pantalla negra sin Linux. La fábrica siempre arranca dualcore.

2. **Prebuilt libraries**: Los `prebuilts/boot/sysroot` (libauddrv, libviddrv)
   del SDK 2024.02.y.2 pueden diferir de los que usó la fábrica (línea 2025).

3. **Gap de versión SDK**: El SDK 2024.02.y.2 (Jul-2024) vs la línea e3100_cube
   (Dic-2025) puede tener cambios en el código del bootloader, bug fixes, o
   diferencias en el toolchain que afectan el boot chain crítico.

4. **Timing**: Diferencias sutiles en la inicialización del hardware (DDR,
   periféricos) que no se manifiestan como errores visibles pero impiden que
   el kernel arranque correctamente.

**Recuperación (segunda vez):** Mismo método probado — corto de pines 2/4 +
HCProgrammer + HCFOTA-factory-restore.bin. Consola restaurada en ~10 min.

## CONCLUSIÓN DEFINITIVA: el bootloader de fábrica NO ES reemplazable con el SDK disponible

Después de DOS intentos con validación creciente:
- Intento 1: NOR-DTB incorrecto (DTS de SD) → BRICKEO
- Intento 2: NOR-DTB correcto (GATE PASS, /hcrtos/ de fábrica) → BRICKEO

**La conclusión es que el binario hcboot compilado desde el SDK 2024.02.y.2
es fundamentalmente incompatible con la consola R36SX V2.6**, independientemente
del DTB. El bootloader de fábrica fue compilado con una versión del SDK y
toolchain que no tenemos acceso, y el resultado es un artefacto que funciona
en hardware donde el nuestro no.

**RECOMENDACIÓN FINAL**: Aceptar `cubegm/` con sus 4 archivos (3,9 MB) como
el **contrato de boot NOR** — una limitación de hardware documentada, igual que
el DDR-init que NO podemos reconstruir. El objetivo "eliminar cubegm/ 100%"
queda en estado NO ALCANZABLE con las herramientas actuales. La alternativa
sería obtener el SDK exacto que usó el fabricante (línea e3100_cube, Dic-2025).

**Qué SÍ funcionó en el proceso:**
- Kernel propio: 100% nuestro ✓
- Rootfs Buildroot propio: 100% nuestro ✓
- TreeFrogUI funcional con audio+video+salida ✓
- Instalación limpia en SD ✓
- ABI fix (ADR-012): audio+video funcionando ✓
- Diagnóstico opt-in (ADR-013) ✓
- El bootloader de fábrica con path-prefix="cubegm" es el contrato inamovible

**Qué NO funcionó:**
- Bootloader propio (2 intentos, 2 brickeos)
- La lección: el bootloader es la pieza más crítica y sensible del sistema,
  y ni siquiera un GATE perfecto del DTB compensa las diferencias binarias
  entre versiones del SDK
