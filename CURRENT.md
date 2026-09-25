# CURRENT.md — Operational Snapshot (CACHE — Git is the truth)

**Updated:** 2026-09-25 (9-6e CERRADO con limitación: NCM producción, ADR-015; stack NCM desplegado a SD, read-back PASS)
**Rule:** small snapshot, no history. No changelog.

## PROJECT

r36sx-hclinux — reproducible Linux/HClinux platform for HiChip consoles (HC16xx/MIPS) with TreeFrogUI. **Expanded goal: multi-console ArkOS/darkOS-like ecosystem** (not just R36SX — also SF3000, SF3500, GB350).

## CURRENT PHASE

**Fase 9-6 — kernel 5.12.4 a máximo desarrollo.**

Trabajo FUERA del árbol git (scripts del stack) vive en el fork TreeFrogUI (`D:\GitHub\TreeFrogUI`, branch **`net-mode-app`**, commit `66a3cbe`) — ver AGENTS §15.

### 9-6e — USB NETWORKING: CERRADO con limitación (ADR-015)

- **Producción = NCM** (adaptador de red nativo Windows + `telnet 192.168.137.2` → root). Networking **PHYSICAL PASS** (bajo el azul).
- **Overlay azul del AVP = limitación aceptada, display-only**: lo dispara CUALQUIER networking activo — gadget CDC-network (NCM/ECM/RNDIS) y TAMBIÉN PPP sobre CDC-ACM (refutado 2026-09-24, incluso con LCP sin respuesta). Kernel/red/shell siguen vivos debajo; capa residual tras B hasta reboot. Vías de evitación AGOTADAS del lado kernel/DTS: DTS `usb0 disabled` (v15) ✗ · subclase CDC ✗ · serial-ACM networking ✗. Eliminarlo exige **firmware AVP propio → PARCADO (clase D)**.
- ACM serial puro (shell interactivo, sin pppd) NO dispara azul — queda como transporte auxiliar.
- PPP/SLIP del kernel + pppd del rootfs: retenidos experimentales (kernel desplegado los incluye).

### Resto de 9-6

| Sub | Ítem | Estado |
|---|---|---|
| 9-6a | Port MUSB/USB (host) | ✅ host PHYSICAL PASS |
| 9-6b | USB Mode MTP gadget | ✅ PHYSICAL PASS (kernel `fdd1d7cc`; MTP `69f247dc`) |
| 9-6c | Module loader (`resolve_symbol` OOPS) | ⏳ PENDIENTE (workaround: built-ins) — bloquea 9-6d |
| 9-6b' | Reconciliación DTB (SD-proven vs build) | ⏳ PENDIENTE |
| 9-6c' | Latencia de display (5.12 ~10s vs 4.4 8s) | ⏳ PENDIENTE |
| 9-6d | Wi-Fi | ⏳ PENDIENTE (depende 9-6c) |
| 9-6e | Red USB / overlay AVP | ✅ CERRADO con limitación (NCM producción, ADR-015) |
| 9-6f | ADB (FunctionFS) | ⏳ PENDIENTE |

## CURRENT HEAD

HEAD = commit de cierre 9-6e-PPP (ADR-015 + refutación serial) — caché; validar con `git log -1`.

## KNOWN-GOOD STATE

- NOR = FACTORY (stock bootloader, NOT replaceable — 2 bricks).
- SD = kernel 5.12.4 `e07844bd` (8.271.323 B; NCM/ECM/ACM/RNDIS + PPP/SLIP built-in, `usb0 disabled` en DTS) + `dtb.bin` `116ddf26` + rootfs propio (con pppd) + TreeFrogUI. Backup pre-PPP en SD: `cubegm/vmlinux.uImage.preppp.bak` (6.886.264 B).
- `avp.uImage` SD == golden fábrica `a9788995` (verificado 2026-09-24).
- Backup known-good MTP: `D:/R36SX/sd-full-backups/2026-09-23_mtp-knowngood/` (hash-verified).
- cubegm/ = contrato NOR de 4 archivos + `diag.enabled`.
- Rollback de kernel: goldens stock preservados (uImage `53b3e0b3`, dtb `1258f1eb`, avp `a9788995`).
- Flags SD raíz: `net.mode` presente → la próxima activación USB MODE entra en modo red (dispatcher nuevo → NCM).

## BUILD STATUS

- **KERNEL 5.12.4 k512 (PPP)**: BUILD PASS → `e07844bd` **DESPLEGADO** (build #43; NCM/ECM/ACM/RNDIS=y + PPP/SLIP=y, `usb0 disabled`).
- **KERNEL 5.12.4 k512 (ECM)**: `7d87d15c` compilado, NO desplegado — premisa refutada (rama muerta, archivada).
- **ROOTFS**: embed determinista (v6 flow) + pppd/chat (experimental retenido, ADR-015). Gates TOOLCHAIN/PATCH PASS.
- **KERNEL 4.4.186**: superseado; buildable (deprecación pendiente).
- **BOOTLOADER**: NO reemplazable.

## PHYSICAL STATUS

CONSOLA OPERATIVA: NOR de fábrica + kernel 5.12.4 `e07844bd` + rootfs propio + TreeFrogUI. MTP PHYSICAL PASS · networking NCM PHYSICAL PASS con overlay azul (limitación aceptada, ADR-015) · ACM serial sin azul. **Stack NCM desplegado en SD (2026-09-25, fork `66a3cbe`, read-back PASS)**: dispatcher default NCM + `net_ppp.sh` experimental + shim `usb_mtp.sh`. Test físico de producción PENDIENTE (usuario): activar NETWORK → NCM → adaptador de red + `telnet 192.168.137.2` (azul esperado y aceptado).

## SOURCE SDK SHA256

e3211b41f8d649c7d7838f7f19b8cca5cf30ba6cb1ff9545be6943845fbf8d5d — HiChip SDK

## ACTIVE BLOCKERS

- **9-6c**: module loader del kernel 5.12 (OOPS `resolve_symbol`) — workaround: built-ins.

## NEXT EXACT ACTION

1. **Test físico (usuario) de la sesión de red de PRODUCCIÓN:** expulsar la SD del lector → arrancar consola → activar NETWORK → verificar adaptador de red NCM en Windows + `telnet 192.168.137.2` → root (azul esperado y aceptado, ADR-015) → B → apagar.
2. Luego: elegir **9-6f ADB (FunctionFS)** o **9-6c fix del module loader**.
3. PARA DESPUÉS (clase D, GO explícito): firmware AVP propio (`~/work/r36sx-hclinux/avp-build/`) — única vía para eliminar el overlay azul.

Detalle: `docs/experiments/2026-09-24_9-6e-ppp-slip.md` y `2026-09-24_usb-networking-blue-overlay.md` (+ addendum refutación PPP).
