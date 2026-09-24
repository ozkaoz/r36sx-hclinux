# CURRENT.md — Operational Snapshot (CACHE — Git is the truth)

**Updated:** 2026-09-24 (9-6e: red USB + overlay AVP; consolidación de documentación y del stack)
**Rule:** small snapshot, no history. No changelog.

## PROJECT

r36sx-hclinux — reproducible Linux/HClinux platform for HiChip consoles (HC16xx/MIPS) with TreeFrogUI. **Expanded goal: multi-console ArkOS/darkOS-like ecosystem** (not just R36SX — also SF3000, SF3500, GB350).

## CURRENT PHASE

**Fase 9-6 — kernel 5.12.4 a máximo desarrollo.**

Trabajo FUERA del árbol git (Scripts del stack) vive en el fork TreeFrogUI (`D:\GitHub\TreeFrogUI`, branch **`net-mode-app`**, commit `d9ef355`) — ver AGENTS §15.

### 9-6e — USB NETWORKING (EN CURSO)

- **MTP**: PHYSICAL PASS (Windows detecta "TreeFrogUI MTP" + transferencia) — sin `net.mode` en la SD.
- **NCM** (`ncm.mode`): Windows detecta la consola como ADAPTADOR DE RED (CDC-NCM nativo) + `telnet 192.168.137.2` → root. **PERO dispara el overlay azul del AVP.**
- **CDC-ACM serial** (`net_serial.sh`): shell por COM, **sin pantalla azul** → el AVP reacciona al *network gadget*.
- **Overlay azul**: comportamiento del firmware AVP (fb con relleno uniforme `06 f2`; NO es corrupción DMA — el 9106 está en dead code). El kernel sigue vivo bajo el azul (telnet + red funcionan).
- **v15** (`2fe467e`): fix por DTS — `usb0 status="disabled"` en `/hcrtos/`. Desplegado en la SD (kernel `fd4f0d0e` + dtb `116ddf26`), **sin PHYSICAL PASS documentado**.
- **v16 ECM** (subclase 06, misma familia que ACM probada sin azul, con netdev): kernel `7d87d15c` **compilado (build #42, 2026-09-24 12:19), NO desplegado**. `net_mode.sh` default = ECM (`ncm.mode` → NCM).

### Resto de 9-6

| Sub | Ítem | Estado |
|---|---|---|
| 9-6a | Port MUSB/USB (host) | ✅ host PHYSICAL PASS |
| 9-6b | USB Mode MTP gadget | ✅ PHYSICAL PASS (kernel `fdd1d7cc`; MTP `69f247dc`) |
| 9-6c | Module loader (`resolve_symbol` OOPS) | ⏳ PENDIENTE (workaround: built-ins) |
| 9-6b' | Reconciliación DTB (SD-proven vs build) | ⏳ PENDIENTE |
| 9-6c' | Latencia de display (5.12 ~10s vs 4.4 8s) | ⏳ PENDIENTE |
| 9-6d | Wi-Fi | ⏳ PENDIENTE (depende 9-6c) |
| 9-6e | Red USB / overlay AVP | ⏳ EN CURSO |
| 9-6f | ADB (FunctionFS) | ⏳ PENDIENTE |

## CURRENT HEAD

`2fe467e` (v15) — caché; validar con `git log -1`.

## KNOWN-GOOD STATE

- NOR = FACTORY (stock bootloader, NOT replaceable — 2 bricks).
- SD = kernel 5.12.4 `fd4f0d0e` (v15) + `dtb.bin` `116ddf26` + rootfs propio + TreeFrogUI.
- Backup known-good MTP: `D:/R36SX/sd-full-backups/2026-09-23_mtp-knowngood/` (hash-verified).
- Rollback físico de USB Mode: MTP PHYSICAL PASS ×2.
- cubegm/ = contrato NOR de 4 archivos + `diag.enabled`.
- Rollback de kernel: goldens stock preservados (uImage `53b3e0b3`, dtb `1258f1eb`, avp `a9788995`).

## BUILD STATUS

- **KERNEL 5.12.4 k512 (ECM)**: BUILD PASS → `7d87d15c` (ECM/NCM/ACM/RNDIS=y, `usb0 disabled`). **Pendiente deploy.**
- **KERNEL 5.12.4 k512 (v15)**: desplegado (`fd4f0d0e`).
- **ROOTFS**: embed determinista (v6 flow). Gates TOOLCHAIN/PATCH PASS.
- **KERNEL 4.4.186**: superseado; buildable (deprecación pendiente).
- **BOOTLOADER**: NO reemplazable.

## PHYSICAL STATUS

CONSOLA OPERATIVA: NOR de fábrica + kernel 5.12.4 + rootfs propio + TreeFrogUI (MTP + red + shell remoto; overlay azul pendiente bajo networking).

## SOURCE SDK SHA256

e321b41f8d649c7d7838f7f19b8cca5cf30ba6cb1ff9545be6943845fbf8d5d — HiChip SDK

## ACTIVE BLOCKERS

- **9-6e**: overlay azul del AVP con gadget de red (display-only).
- **9-6c**: module loader del kernel 5.12 (OOPS `resolve_symbol`).

## NEXT EXACT ACTION

**9-6e: desplegar el kernel ECM `7d87d15c` en la SD y validar físicamente** (requiere autorización clase F):
1. Copiar `~/work/r36sx-hclinux/build/r36sx-v26-k512/images/vmlinux.uImage` → `cubegm/vmlinux.uImage` (dtb `116ddf26` ya desplegado). Backup del uImage actual.
2. En la consola: crear flag `net.mode` en la raíz SD → conectar USB → verificar adaptador de red en Windows + `telnet 192.168.137.2` **sin overlay azul**.
3. Si PASS: promover ECM + actualizar CURRENT/CHANGELOG/ROADMAP a PHYSICAL PASS. Si azul: el discriminante es `netdev`/u_ether, no la subclase → volver a ACM serial como transporte de producción.

Detalle y artefactos: `docs/experiments/2026-09-24_usb-networking-blue-overlay.md`.
