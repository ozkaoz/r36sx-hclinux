# 2026-09-24 — 9-6e: USB networking + la "pantalla azul" (overlay AVP)

**Fase:** 9-6e (RNDIS/networking USB)
**Kernel:** 5.12.4 (variante k512)
**Estado:** EN CURSO — sin PHYSICAL PASS. El kernel ECM está compilado, **no desplegado**.

## Objetivo

Habilitar networking por USB (adaptador de red en el PC + shell remoto root en la
consola) sin disparar el **overlay azul** que el firmware AVP pinta sobre el
display cuando ve un gadget de red (patrón uniforme `06 f2` = azul RGB565).

## Cronología de teorías (una variable por experimento)

1. **RNDIS** (`net_rndis.sh`, kernel `651f1ca5`): Windows Código 28 (driver
   `usb8023.sys` deprecado) + pantalla azul. Rollback.
2. **CDC-NCM** (`net_ncm.sh`, kernel `7dc0c9dc`): Windows detecta el adaptador de
   RED de forma nativa, y **funciona**: `usb0` 192.168.137.2 + `telnetd` → shell
   root en la consola. PERO el overlay azul persiste.
3. **Teoría DMA (9116) REVOCADA**: el framebuffer contiene `06 f2` UNIFORME en
   todo el buffer — no es corrupción de DMA sino un **relleno deliberado**. Además
   `CONFIG_MUSB_DMA_XFER_ALIGN` no está activado → el bloque con el supuesto bug
   (9106) ni siquiera compila. El 9105 (interrupt EP → PIO) sí está activo y **no**
   elimina el azul; queda como defensa en profundidad.
4. **CDC-ACM** (`net_serial.sh`): clase modem (`02/02/01`), sin `netdev`, sin
   `u_ether`. **Prueba ACM = sin pantalla azul** → el AVP reacciona al *network
   gadget*, no a cualquier gadget. Shell vía `/dev/ttyGS0` + PuTTY.
5. **v15 — FIX POR DTS (hipótesis raíz)**: el AVP monitorea el USB controller 0
   (`0x18844000`) mediante su nodo `/hcrtos/usb0` (`dr_mode="host"`). Al activarse
   un gadget CDC-network en peripheral, el AVP aplica el overlay. Fix:
   `scripts/make_board_dts.sh` hace `sed` post-generación para dejar
   `status="disabled"` en `usb0` del `/hcrtos/` (allowlist del gate NOR-DTB).
   DTB de fábrica-only difference documentada. Commit `2fe467e`.

## Estado actual (al corte de esta iteración)

- **Desplegado en SD:** kernel `fd4f0d0e` (v15) + `dtb.bin` `116ddf26`
  (`usb0 status=disabled` verificado por decompilación). **Sin PHYSICAL PASS
  documentado.**
- **Compilado, sin desplegar:** build #42 (2026-09-24 12:19) → `vmlinux.uImage`
  `7d87d15c97ba966e1fc0a61b6867aa3f44e14f7619484ea775fad53ce7f89cb4` (6.887.103 B)
  con `ECM=y NCM=y ACM=y RNDIS=y` + `usb0 disabled`. Artefacto:
  `~/work/r36sx-hclinux/build/r36sx-v26-k512/images/vmlinux.uImage`.
- **Estrategia ECM:** CDC-ECM (subclass `06`) es la misma familia que ACM
  (probada sin azul) pero con `netdev`. `net_mode.sh` pasa a **default = ECM**
  (`ncm.mode` → NCM). Los scripts viven en el fork TreeFrogUI
  (`apps/net_mode/`, branch `net-mode-app`, commit `d9ef355`).

## Evidencia

- fb de diagnóstico en vivo (`BLUE_DIAG.log`): patrón `06 f2` uniforme;
  AVP reporta `rgb: ff0000ff`.
- ACM sin azul / NCM-RNDIS azul (prueba diferencial).
- GE reset, `drcoff`, fb keepalive, interrupt-EP-PIO (9105): **todos sin efecto**.
- amprpc: sin comandos de display durante el azul.
- DTB desplegado: `usb0` `status="disabled"` (decompilado).

## RESULTADO TEST FÍSICO v15+NCM (2026-09-24)

Procedimiento: SD con flags `net.mode` + `ncm.mode`, kernel desplegado `fd4f0d0e`
(v15, DTS `usb0 status=disabled`) + `dtb.bin` `116ddf26`. Entrada USB MODE →
`net_ncm.sh`.

- PC reconoce el **adaptador de red** (CDC-NCM) y `telnet 192.168.137.2` da shell
  root en la consola.
- **A los ~30 s aparece la pantalla azul.** → **Hipótesis v15 REFUTADA**:
  deshabilitar `status` del nodo `/hcrtos/usb0` **NO** evita el overlay.
- Tras pulsar **B** (salida de net mode) vuelve al menú, pero **persiste una capa
  azul tipo filtro** sobre toda la UI (el estado de display del AVP queda pegado;
  no se limpia al desbindear el gadget).
- Evidencia `NET_MODE_DEBUG.log` (SD): gadget creado 00:00:12, `usb0 UP`,
  `telnetd OK`, B exit 00:01:45, `restore done rc=0`.

**Conclusión:** el disparador correlaciona con la **presencia del network gadget
(`netdev`/`u_ether`)**, no con la subclase CDC ni con el nodo DTS `usb0`. ACM
(sin netdev) no lo dispara. El efecto es **stateful en el AVP**.

## Próximos pasos

1. Desplegar `7d87d15c` (kernel ECM) en `cubegm/vmlinux.uImage` — **autorización
   clase F requerida**.
2. ~Test físico v15+NCM ya ejecutado: NEGATIVO (azul persiste)~ — ver resultado
   arriba. Siguiente: experimento de una variable (ver CURRENT.md NEXT ACTION).
3. Si ECM no dispara azul: promover a transporte por defecto y validar
   navegación/exit limpios (CURRENT.md + CHANGELOG + PHYSICAL PASS).
4. Si ECM dispara azul: el discriminante es la presencia de `netdev`/u_ether, no
   la subclase CDC → volver a ACM serial como transporte de producción y documentar
   el límite.

## Artefactos / commits relacionados

- `2fe467e` v15 (DTS usb0 disabled) · `3098886` v13 (ACM) · `eacecb4` (revocación
  DMA) · `fd0f840` v9 (9106, dead code) · `5a0e6c7` v8 (9105)
- Fork TreeFrogUI `net-mode-app` `d9ef355` (apps/net_mode + dispatcher)

## ADDENDUM 2026-09-24 (noche) — refutación PPP: el disparador es networking ACTIVO, no el gadget

Test adicional (una variable): PPP sobre CDC-ACM (kernel `e07844bd` con
`CONFIG_PPP/SLIP=y` + pppd embebido + `net_ppp.sh` del fork). El gadget es clase
modem — sin descriptor de red, sin netdev de u_ether. pppd corrió sobre
`/dev/ttyGS0` con LCP enviado ×10 **sin respuesta del PC** (dial-up no
configurado; ver `PPP_DEBUG.log`) — **y el overlay azul apareció igual**
(reporte físico del usuario).

- La "Conclusión" de arriba queda **corregida**: el disparador NO es la
  presencia del network gadget (`netdev`/`u_ether`) — es **networking activo en
  cualquiera de sus formas** (gadget CDC-network o pppd sobre ACM). El ACM puro
  (shell, sin pppd) sigue sin dispararlo.
- Matiz: no se excluye del log una contaminación stateful de la sesión NCM
  previa del mismo día; la observación en vivo del usuario manda (EVIDENCE > MEMORY).
- Los "Próximos pasos" 1–4 de arriba quedan **muertos**: ECM no se despliega
  (premisa refutada); producción = NCM. Ver **ADR-015** y
  `docs/experiments/2026-09-24_9-6e-ppp-slip.md`.
