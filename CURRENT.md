# CURRENT.md — Operational Snapshot (CACHE — Git is the truth)

**Updated:** 2026-09-22 (PHASE 9: 9-1/9-2/9-3 DONE — kernel 5.12.4 BUILD PASS)
**Rule:** small snapshot, no history. No changelog.

## PROJECT

r36sx-hclinux — reproducible Linux/HClinux platform for HiChip consoles (HC16xx/MIPS) with TreeFrogUI. **Expanded goal: multi-console ArkOS/darkOS-like ecosystem** (not just R36SX — also SF3000, SF3500, GB350).

## CURRENT PHASE

**9-6b COMPLETE: USB MODE MTP PHYSICAL PASS (2026-09-23). Windows detecta TreeFrogUI MTP + transferencia de archivos VERIFICADA FISICAMENTE por el usuario.**
La saga completa (14 test fisicos): HOST-only crash -> DUAL_ROLE | configfs sin mountpoint -> S90configfs | /lib sombreado por el bind del rootfs de fabrica -> modulos visibles | busybox+kmod segfault -> kmod standalone | **module loader del kernel OOPSEA en resolve_symbol con cualquier .ko -> gadget stack BUILT-INTO** | check built-in -> usb_gadget | **EL BUG RAIZ FINAL: f_mtp Android-4.4 llamaba usb_os_desc_prepare_interf_dir ANTES de config_group_init_type_name (inocuo con la array-API de 4.4, FATAL con la list-API de 5.12: list_add sobre grupo zerado -> NULL deref en el mkdir del gadget = el reinicio del kernel)** -> orden corregido en el 9103.
Kernel: fdd1d7cc (todo el gadget built-in + ports 9101-9104 + el fix del orden). Stack: usb_mode.sh parchado (check usb_gadget; backup .prebuiltin.bak).

## CURRENT OBJECTIVE

9-4: physical milestone-1 — swap ONLY cubegm/vmlinux.uImage on SD (keep SD dtb.bin 1258f1eb + treefrog/ + rootfs), serial/visual boot evidence. Requires explicit authorization (class F). Then 9-5 TreeFrogUI+ABI revalidation, 9-6 musb port + DTB reconciliation.

## CURRENT HEAD

(see git log -1 — cache)

## KNOWN-GOOD STATE

- NOR = FACTORY (stock bootloader, not replaceable)
- SD = kernel 5.12.4 69f247dc (gadget built-in + f_mtp order fix) + MTP PHYSICAL PASS (verificado 2x: deteccion Windows + transferencia + salida limpia)
- cubegm/ = 4-file NOR boot contract + diag.enabled (activo para diagnostico)
- Rollback fisico: USR-MTP: PHYSICAL PASS (Windows detecta + transferencia + salida limpia sin capa azul — confirmado 2026-09-23 en kernel 69f247dc)
- RNDIS (9-6e): rolled back — dos bugs documentados (Win Codigo 28: descriptores del gadget; pantalla azul: regresion kernel RNDIS built-in) — iteracion dedicada pendiente
- kmod real + telnetd busybox deployados en rootfs/ (inertes, reutilizables)
- Backup known-good: D:/R36SX/sd-full-backups/2026-09-23_mtp-knowngood/ (fresco, hash-verified)

## BUILD STATUS

KERNEL 5.12.4 (k512 variant): BUILD PASS + CLEAN PHYSICAL PASS (menu/audio/input/emulators; 26 patches = 21 vendor + 4 own-900X + 1 own-9101).
KERNEL 4.4.186: BUILD PASS (superseded on SD; buildable via base defconfig — deprecation decision pending).
ROOTFS: deterministic embed (v6 flow). Gates: TOOLCHAIN/PATCH PASS.
BOOTLOADER: NOT REPLACEABLE (2 attempts, 2 bricks — use factory bootloader).

## PHYSICAL STATUS

CONSOLE OPERATIONAL: factory NOR + kernel 8e + own rootfs + TreeFrogUI working.

## SOURCE SDK SHA256

e321b41f8d649c7d7838f7f19b8cca5cf30ba6cb1ff9545be6943845fbf8d5d — HiChip SDK

## ACTIVE BLOCKERS

None technical.

## NEXT EXACT ACTION

**9-6e v7 estado: NCM DETECTADO COMO RED POR WINDOWS + KERNEL VIVO CON SHELL REMOTO A UN PASO.**

LOGROS DEL ULTIMO TEST:
- NCM funciona: Windows detecta la consola como DISPOSITIVO DE RED (no COM7) — el driver matching de CDC-NCM es nativo Windows 7+
- El kernel VIVO: telnet conecto a 192.168.137.2 — el sistema Linux funciona por debajo de la pantalla azul (el display corrupto es cosmetic)
- Login falla con "bad salt": el /etc de fabrica rootfs/ estaba VACIO — FIX APLICADO: passwd/shadow copiados (root sin contrasena)

LA PANTALLA AZUL (causa confirmada):
- Es DISPLAY-ONLY: el kernel, red, USB y telnetd funcionan debajo
- Ocurre cuando un gadget USB con interrupt EP esta activo (RNDIS y NCM ambos lo usan, MTP no)
- La causa raiz: el vendor musb gadget no maneja interrupt EPs correctamente -> DMA corrupte el framebuffer/display
- El fix kernel-side (hcusbhsdma.c / hcusb.c) = la siguiente iteracion de debugging

PROXIMO TEST (con la SD ya fixeada):
1. SD a la consola -> enciende -> USB Mode -> A -> conecta cable
2. Windows: adaptador de red aparece
3. ncpa.cpl -> IPv4 -> 192.168.137.1 / 255.255.255.0
4. telnet 192.168.137.2
5. Login: root / (Enter, sin contrasena)
6. = SHELL REMOTO A LA CONSOLA

Con el shell remoto, el debugging de la pantalla azul se hace EN VIVO (dmesg, /proc, /sys sin desmontar la SD).
