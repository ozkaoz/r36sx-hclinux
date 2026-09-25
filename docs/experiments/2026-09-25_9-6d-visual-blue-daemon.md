# Experimento 9-6d-visual: overlay azul durante red activa — daemon + video-clear

**Fecha:** 2026-09-25 (tarde)
**Clase:** B (stack fork) + experimentos físicos de observación
**Requisito del usuario:** internet activo + pantalla normal + navegación del menú.

## E0 — reversibilidad del overlay (netdev down)

Script autónomo: `ifconfig usb0 0.0.0.0 down` 60 s → re-up. Observación del
usuario durante la fase down: **el azul NO cambió** (opaco estable). El
re-up del script falló (script murió — em-dash en busybox sh), pero el
resultado es válido: **el overlay es one-shot/stateful — no depende del
estado L3 del netdev.** (La sesión del menú siguió viva; el B del usuario
restauró limpio — `restore done rc=0`.)

## Modo daemon (fork `7508c71`) — PASS funcional

`net_mode.sh` → toggle daemon: red arriba en background (gadget + usb0 +
gw + DNS + telnetd) y vuelve al menú en 3-5 s. Físicamente validado:
menú navegable + **internet vivo bajo daemon** (ping 8.8.8.8 2/2 ~10 ms por
telnet durante la navegación). **PERO a los ~30 s el AVP dispara el overlay
opaco** → el menú queda invisible (el usuario no puede usar la UI).

## Video-clear con red VIVA — NEGATIVO (hallazgo decisivo)

Lanzamiento remoto de `video_player` (Big Buck Bunny, path VIDDEC por
hardware — `start viddec` en logs) con la red del daemon viva:

- El video se ve **con filtro azulado** (no limpio) — el overlay del AVP
  está POR ENCIMA incluso del path de video.
- Al matar el video: **vuelve el azul opaco** inmediatamente.

**Contraste con el hallazgo previo del usuario** (video que limpió la
pantalla): ese caso fue con la red MUERTA (tras B de la sesión clásica →
restore/desbind) → velo RESIDUAL → el video lo limpia (recomposición de
capas sin estado azul activo).

## Modelo del comportamiento del AVP (consolidado)

| Estado del sistema | Overlay | ¿Reversible por software? |
|---|---|---|
| Gadget de red VIVO (bind + peripheral) | Azul opaco continuo (dispara ~30 s tras activación) | **NO** — netdev down no quita; video con tinte encima; one-shot por boot |
| Gadget DESBINDEADO (restore/desbind) | Velo residual | SÍ — reproducir video 1-2 s lo limpia |

**Disparador raíz confirmado:** la existencia de un gadget de red activo en
el bus USB (L3 irrelevante — PPP/ACM también disparó; netdev down no apaga).
El overlay es una capa de composición ACTIVA del firmware AVP de fábrica
mientras dura el networking.

## Conclusión y camino

- **Ineludible por software** (kernel/DTS/stack): agotado (DTS ✗, subclase
  CDC ✗, serial-ACM ✗, netdev-down ✗, video-clear ✗ con red viva).
- **Única vía para pantalla normal + red viva: firmware AVP propio** (fase D)
  — compilar el AVP del SDK sin el trigger del overlay y desplegar a
  `cubegm/avp.uImage`. **Riesgo de brick ≈ 0** (el AVP vive en la SD;
  rollback = copiar el golden `a9788995` de vuelta). Riesgo técnico real:
  ABI/funcionalidad del AVP del SDK (Jul-2024) vs userspace de fábrica
  (Dic-2025) — misma familia de drifts que ADR-012 (9l/9m).
- El daemon queda útil para internet headless (telnet/wget sin mirar la
  pantalla) y para la futura fase AVP (el stack no requiere cambios).
