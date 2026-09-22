# docs/TREEFROG_UI_CONTRACT.md — Contrato formal TreeFrogUI ↔ (kernel + rootfs propios)

**Estado:** VÁLIDO FÍSICAMENTE (2026-09-18, 9m PHYSICAL PASS TOTAL: audio+video+salida-cores bajo kernel propio)
**Fuentes:** matriz viva diag6x/diag8/9l/9m (evidence-*) · `docs/TREEFROGUI_COMPATIBILITY.md` (matriz rápida) · ADR-012/013
**Mantenimiento:** este documento describe el contrato que TODO kernel/rootfs futuro r36sx-v26 debe cumplir para que TreeFrogUI arranque y funcione íntegro (menú, juegos con audio, música, video, salida limpia de cores).

---

## 1. Flujo de arranque (boot-to-menu, verificado)

```
BootROM → DDR-init(12 KiB .abs, fábrica) → bootloader.bin(fábrica) →
AVP HCRTOS uImage @0x8BDA4000 (fábrica, preservado) →
Linux 4.4.186 NUESTRO (uImage @0x80000000, DTB @0x85ff0000) →
initramfs propio (rcS → S10mdev → S41hcdaemon → S99app [*S09trace opt-in]) →
S99app: monta SD (/dev/mmcblk0p1→/media/mmc) → bind /mnt/sdcard → binds rootfs/{lib,usr,bin,sbin,etc}[*] →
zhijack.sh (RAM-reexec) → congela icube, mata rkgame → cubevol + nosleep →
picoarch + cores/frogui_libretro.so (menú TreeFrogUI) →
lanzamientos: cores/standalone (video_player, lgpt, pcsx4all…) vía /tmp/frogui_launch.txt
```

[*] **8e EJECUTADO (2026-09-18, CLEAN-INSTALL PHYSICAL PASS):** el stack TreeFrogUI vive en `/treefrog/`; S99app v2 lo aliasa: `mount --bind /mnt/sdcard/treefrog /mnt/sdcard/cubegm` (los binarios llevan paths `/mnt/sdcard/cubegm/…` compilados dentro — frogui 100 refs, picoarch 14; evidencia en el plan 8e). `cubegm/` queda reducido a **10 archivos**: 5 de boot (kernel/dtb/avp propios+y de fábrica) + **4 PRE-LINUX-REQUIRED de fábrica (`setting.xml`, `xgame-logo.bmp`, `allfiles.lst`, `root.dat` — al menos uno es leído por AVP/bootloader antes de Linux; eliminarlos = "please insert TF Card" — causa raíz aislada por bisect)** + flag `diag.enabled`. Los binds del `rootfs/` de fábrica siguen (libffplayer/libhudi = motor media ABI Dic-2025, ver §4).

## 2. Servicios del sistema requeridos (initramfs propio)

| Servicio | Rol | Estado |
|---|---|---|
| `S10mdev` + mdev + `mount-helper` | hotplug + montaje SD → `/media/<dev>` | nuestro |
| `S41hcdaemon` (`hcdaemon&`) | daemon de fábrica (610.404 B) — volumen GPIO/ZZd2C, gestionado vía virtuart | **única pieza de fábrica en NUESTRO initramfs** (documentada) |
| `S99app` | montaje directo + binds + lanzamiento de zhijack (8d: sin icube) | nuestro |
| `S09trace` v5 | diagnóstico OPT-IN (ADR-013): sin flag no escribe SD | nuestro |
| `cubevol` (userspace, zhijack) | gpio → `/tmp/joy_key` shm (input de toda la UI) | upstream TreeFrogUI |
| `nosleep` (userspace, zhijack) | desarma sleep de cubevol si `disable_sleep=on` | upstream TreeFrogUI |

## 3. Dependencias de hardware//dev (ABI viva — verificada por fds on-device)

```
auddec backlight check_adc1 check_adc5 dis fb0 fb1 ge hdmi input/event0
mem mmz persistentmem sndC0i2so standby virtuart_proxy avsync
```

- **Video UI**: fb0 (1280x720 bpp16) + **GE** (`/dev/ge`, hwdisp path `use_hw=1`, `map ge register`) + `/dev/dis` (capas).
- **Audio**: `/dev/auddec` (RPC → AVP) → `sndC0i2so` en el AVP (CFG 48K, bitdepth 16); volumen vía `AUDIO_SET/GET_VOLUME` (cubevol).
- **Input**: pipeline `cubevol gpio → /tmp/joy_key` shm — SIN evdev (diseño de fábrica, igual en ambos kernels).
- **Batería**: `/dev/check_adc1` (nivel) + `/dev/check_adc5` (carga) — `CONFIG_CHECK_ADC=y` obligatorio.
- **Transporte**: AMPRPC (IRQ 66) + avp-proxy (kernel) ↔ AVP; kshm para buffers de media.

## 4. Contrato ABI media (ADR-012 — LA regla crítica)

Los binarios userspace de fábrica (Dic-2025: `libffplayer.so` a1625d51…, `libhudi.so` 734e4534…, `driver_r36sx.so` 58b180a2…) codifican el **sizeof del struct en el número de ioctl**. El kernel (headers SDK Jul-2024) DEBE compilar los mismos números o el switch del avp-proxy no matchea → `KSHM_WRITE_HDL_ACCESS` nunca se envía → media muerto sin error visible.

| Struct | sizeof fábrica | ioctl fábrica | Fix propio |
|---|---|---|---|
| `audio_config` | **632** | AUDDEC_INIT `0x82780301` | `_pad_abi_2025[24]` (9l) |
| `video_config` | **664** | VIDDEC_INIT `0x82980400` | `_pad_abi_2025[20]` (9m) |

Patches: `patches/buildroot/linux/0001..0002` (canon; synced to SDK as 900X — ADR-014). Diagnóstico de futuros drifts: trace amprpc on-device + reconstrucción `lui+ori` de los binarios de fábrica.

## 5. Estructura en SD y artefactos (inventario con hashes sha256-16)

**Punto de montaje:** `/media/<dev>` → bind `/mnt/sdcard`. Raíz SD (G:): roms por sistema (`GB/`, `GBA/`, `PS/`…), `log.txt` (opt-in de zhijack: presente ⇒ logging), `picoarch.cfg` (`show_fps/show_hud/scale_size`), `frogui/settings.txt` (k=v; `disable_sleep`), `docs/`, `diag*.sh`.

**`cubegm/` (clasificación — insumo del plan 8e):**

| Clase | Archivos (sha256-16 donde medido) |
|---|---|
| **Nuestro** | `vmlinux.uImage` (7a `2546d199`), goldens: `vmlinux.uImage.stock.bak` (53b3e0b3), `avp.uImage.factory.bak` (a9788995) |
| **Fábrica** (quedan en cubegm; necesarias para rollback stock) | `icube` 21eadc68, `icube.sh` 30551a36, `rkgame` 57d8b4fd, `MyExecutable` b1f8c1d3, `driver.so` 58b180a2, `dtb.bin`, `ApplicationFrame.dll`, `advapi32.dll`, `ui_*.cpd`, `UI_Res.cpd`, `resource(.cpd)`, `joystick.cpd`, `xgame-logo1.hc`, `font.ttf`, `Tahoma.ttf`, `Arial_*.ttf`, `*.wav`, `cubepoweroff.bmp`, `silence.wav`, `pagefile.sys`, `skin/`, `BGM/`, `states/`, `menu.log`, `allfiles.lst`, `root.dat` |
| **Fábrica-modificada** | `setting.xml` d7e8a411 (autorun de fábrica + hijack TreeFrogUI: hotkeys/config UI; usada SOLO en el boot stock) |
| **Stack TreeFrogUI (upstream — a relocar en 8e)** | `zhijack.sh` 14b55648, `picoarch` 02642931, `picoarch_hi` b92e0fef, `cores/frogui_libretro.so` a3dad067, `driver_r36sx.so` 58b180a2 (== driver.so fábrica), `driver_r36sx27.so` e46d5bf3, `driver_sf3000.so` 90727162, `driver_sf3500.so` a3024878, `driver_gb350.so` 4d7e8bb5, `video_player` 0347e4bf, `image_viewer` 68a310de, `mtp-server` 6a26099f, `nosleep` 1e4f3cc3, `powergpio` 2148befa, `tfupdate.sh` 95f689f0, `shutdown.sh` d93bc1d, `usb_mode.sh` 20ab52ff, `version.txt` 2bef00c8, `modules/`, `lib/`, `usr/lib/` (libs runtime), `language/`, `bios/`, `saves/`, `favorites.lst`, `recent.lst`, `setting.xml` (ver fábrica-modificada), docs/README/licencia |
| **Ecosistema usuario (se relocan con el stack)** | `lgpt` + `lgpt.elf`, `pico286`, `pcsx4all` 94036292, `rockbox` + `rockbox.sh`, `ebook` b1f8c1d3-adr (ver nota), `sf3000_keymap.txt` |
| **Diagnóstico (nuestro, caducable)** | `boottrace.log`, `virtuart_boot.log`, `treefrog_ui.log`, `diag*.log` — S09trace v5 ya no los regenera sin flag |

Nota: `libffplayer.so`/`libhudi.so` viven en el **`rootfs/` de fábrica** (NO en cubegm) y quedan como piezas de fábrica del motor media (§4).

## 6. Garantías mínimas para un rootfs futuro (checklist de integración)

1. Kernel config: `HC_GE=y`, `HC_HWSPINLOCK=y`, `CHECK_ADC=y`, `BLK_DEV_INITRD=y` (initramfs cpio CRUDO embebido, paridad fábrica), drivers mmc `dw-mshc`, sin drivers extra que tomen periféricos del AVP (lección 7c).
2. Init scripts propios con: mdev temprano, `hcdaemon&`, S99app directo a zhijack, S09trace opt-in.
3. ABI ADR-012 al día (audits con el método §4 ante cualquier actualización de binarios de fábrica).
4. DTB semánticamente == stock (gate compare_dtb_semantics).
5. `/tmp` funcional (shm joy_key, launch files, re-exec zhijack en RAM).
6. FrogUI/Cores con `LD_LIBRARY_PATH=/mnt/sdcard/cubegm/lib:/mnt/sdcard/cubegm/usr/lib` (a actualizar en 8e).

**Estado de integración: CUMPLIDO Y PROBADO** (Fase 8 COMPLETE — rootfs propio 10,4 MiB BUILD PASS + PHYSICAL PASS total 9m).
