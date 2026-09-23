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
- SD = kernel 5.12.4 9731d6a5 + own rootfs (embedded cpio 460 entries) + functional TreeFrogUI menu (PHYSICAL)
- cubegm/ = 4-file NOR boot contract (avp.uImage, dtb.bin 1258f1eb, vmlinux.uImage 5.12.4, xgame-logo.bmp) + diag.enabled (remove after confirmation)
- Kernel-4 PURGED from SD (user-authorized, all preserved hash-verified in D: backup): .8e.bak, .stock.bak, treefrog/modules/4.4.186-release, rootfs lib+lib32 modules/4.4.186-release. rootfs/ userspace kept (ADR-012 forensic value, not kernel-loadable)
- Rollback (if needed): restore from D:/R36SX/sd-full-backups/2026-09-21_phase8-known-good/sd-full.tar (contains 8e f8fb6768 + factory 53b3e0b3 hash-verified)
- Boot ~10s
- Recovery kit verified twice; full backup: D:/R36SX/sd-full-backups/2026-09-21_phase8-known-good/ + D:/R36SX/nor-dump-20260919/

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

Prioridades 9-6 restantes (decidir con el usuario):
1. **9-6e RNDIS** (AHORA TRIVIAL: el gadget configfs funciona — f_rndis = funcion mainline + network config; ~1 build + test)
2. **9-6f ADB** (functionfs + adbd — mas trabajo userspace)
3. **9-6c kernel module loader** (el OOPS de resolve_symbol con .kos — pendiente tecnico; bloquea Wi-Fi 9-6d salvo que se haga built-in tambien)
4. 9-6b2 DTB reconciliation + 9-6c2 display latency (pulido)
Notas tecnicas heredadas: CONFIG_MODULE_UNLOAD=n del vendor base (rmmod no disponible); el flujo usb_mode.sh del stack espera modulos visibles (los built-ins pasan via el check usb_gadget parchado — divergence documentada vs upstream).
