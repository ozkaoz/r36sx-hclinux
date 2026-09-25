# CURRENT.md — Operational Snapshot (CACHE — Git is the truth)

**Updated:** 2026-09-25 (9-6e CERRADO con limitación: NCM producción, ADR-015; stack NCM desplegado a SD, read-back PASS)
**Rule:** small snapshot, no history. No changelog.

## PROJECT

r36sx-hclinux — reproducible Linux/HClinux platform for HiChip consoles (HC16xx/MIPS) with TreeFrogUI. **Expanded goal: multi-console ArkOS/darkOS-like ecosystem** (not just R36SX — also SF3000, SF3500, GB350).

## CURRENT PHASE

**Fase 9-6 — kernel 5.12.4 a máximo desarrollo.**

Trabajo FUERA del árbol git (scripts del stack) vive en el fork TreeFrogUI (`D:\GitHub\TreeFrogUI`, branch **`net-mode-app`**, commit `66a3cbe`) — ver AGENTS §15.

### 9-6e — USB NETWORKING: ✅ DONE (producción NCM, ADR-015)

- **Producción = NCM** (adaptador de red nativo Windows + `telnet 192.168.137.2` → root). **PRODUCTION PHYSICAL PASS (usuario, 2026-09-25)**: adaptador de red + telnet root bajo el azul; sesión limpia con `restore done rc=0` (evidencia `NET_MODE_DEBUG.log`).
- **Overlay azul del AVP = limitación aceptada, display-only**: lo dispara CUALQUIER networking activo — gadget CDC-network (NCM/ECM/RNDIS) y TAMBIÉN PPP sobre CDC-ACM (refutado 2026-09-24, incluso con LCP sin respuesta). Kernel/red/shell siguen vivos debajo; capa residual tras B hasta reboot. Vías de evitación AGOTADAS del lado kernel/DTS: DTS `usb0 disabled` (v15) ✗ · subclase CDC ✗ · serial-ACM networking ✗. Eliminarlo exige **firmware AVP propio → PARCADO (clase D)**.
- ACM serial puro (shell interactivo, sin pppd) NO dispara azul — queda como transporte auxiliar.
- PPP/SLIP del kernel + pppd del rootfs: retenidos experimentales (kernel desplegado los incluye).

### Resto de 9-6

| Sub | Ítem | Estado |
|---|---|---|
| 9-6a | Port MUSB/USB (host) | ✅ host PHYSICAL PASS |
| 9-6b | USB Mode MTP gadget | ✅ PHYSICAL PASS (kernel `fdd1d7cc`; MTP `69f247dc`) |
| 9-6c | Module loader (`resolve_symbol` OOPS) | ✅ **DONE — PHYSICAL PASS** (2026-09-25, kernel `e45547a2`: insmod gf128mul rc=0 Live; fix 0005 + strip_vendor_8B) |
| 9-6b' | Reconciliación DTB (SD-proven vs build) | ⏳ PENDIENTE |
| 9-6c' | Latencia de display (5.12 ~10s vs 4.4 8s) | ⏳ PENDIENTE |
| 9-6d | Internet por USB | ✅ **F1 PHYSICAL PASS vía PC (ICS)** — F2 celular (drivers .ko) y modo daemon PENDIENTES |
| 9-6e | Red USB / overlay AVP | ✅ DONE — NCM producción PRODUCTION PHYSICAL PASS (ADR-015) |
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

- **KERNEL 5.12.4 k512 #45 (fix 9-6c COMPLETO: 0005/9005 + vendor-8B strip)**: BUILD PASS → **`e45547a2`** (8.270.717 B) **DESPLEGADO — PHYSICAL PASS**. Gates TOOLCHAIN+PATCH PASS.
- **KERNEL 5.12.4 k512 #43 (PPP)**: BUILD PASS → `e07844bd` **DESPLEGADO** (NCM/ECM/ACM/RNDIS=y + PPP/SLIP=y, `usb0 disabled`).
- **KERNEL 5.12.4 k512 (ECM)**: `7d87d15c` compilado, NO desplegado — premisa refutada (rama muerta, archivada).
- **ROOTFS**: embed determinista (v6 flow) + pppd/chat (experimental retenido, ADR-015). Gates TOOLCHAIN/PATCH PASS.
- **KERNEL 4.4.186**: superseado; buildable (deprecación pendiente).
- **BOOTLOADER**: NO reemplazable.

## PHYSICAL STATUS

CONSOLA OPERATIVA: NOR de fábrica + kernel 5.12.4 `e45547a2` (9-6c loader fix) + rootfs propio + TreeFrogUI. **Module loader FUNCIONAL** (gf128mul Live; primer módulo cargado de la historia del port 5.12). **INTERNET FUNCIONAL vía PC** (ICS: ping 8.8.8.8 + DNS + HTTP; evidencia 96d). MTP PHYSICAL PASS · networking NCM **PRODUCTION PHYSICAL PASS (2026-09-25, usuario)**: adaptador de red + `telnet 192.168.137.2` root bajo el overlay azul (limitación aceptada, ADR-015); sesión `restore done rc=0` · ACM serial sin azul. Stack NCM desplegado en SD (fork `66a3cbe`, read-back PASS).

## SOURCE SDK SHA256

e3211b41f8d649c7d7838f7f19b8cca5cf30ba6cb1ff9545be6943845fbf8d5d — HiChip SDK

## ACTIVE BLOCKERS

- **NINGUNO** — 9-6c arreglado (loader funcional). Workaround built-ins puede retirarse gradualmente (los gadget functions siguen built-in por decisión ADR-015/9-6b; no es blocker).

## NEXT EXACT ACTION

1. **9-6d continúa**: (a) investigación del overlay azul durante red activa (experimentos de una variable: netdev sin IP / DOWN / renombrado / netns — el disparador correlaciona con netdev activo); (b) modo daemon del stack (navegar menú con red viva, fork); (c) vía celular: compilar USB_USBNET+CDCETHER+RNDIS_HOST como .ko (loader funcional) + consola host-mode + udhcpc.
2. Luego: 9-6f ADB · 9-6b' DTB · 9-6c' latencia.
2. Recomendación: cosechar evidencia final de la SD (results.log del PASS) al volver la SD al lector.
3. PARA DESPUÉS (clase D, GO explícito): firmware AVP propio (`~/work/r36sx-hclinux/avp-build/`) — única vía para eliminar el overlay azul; D-2c flash del bootloader propio (staging `1734c340` — riesgo brick documentado).
4. Post 9-6: decisión de migración 5.15 LTS (feasibility audit read-only primero).

Detalle 9-6c: `docs/experiments/2026-09-25_9-6c-module-loader-fix.md`. 9-6e: `docs/experiments/2026-09-24_9-6e-ppp-slip.md` y `2026-09-24_usb-networking-blue-overlay.md`.
