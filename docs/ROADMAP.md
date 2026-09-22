# docs/ROADMAP.md — Fases, gates y formato de iteración

## Visión

BootROM → bootloader (stock) → AVP/HCRTOS (stock, preservado) → **kernel propio (5.12.4 = known-good)** → **DTB propio** → **rootfs propio (Buildroot, embed determinista)** → picoarch → **TreeFrogUI como shell principal** → ecosistema multi-consola.

## Fases

| Fase | Objetivo | Estado |
|---|---|---|
| **0. Bootstrap** | Repo + contexto + agentes + GitHub | ✅ DONE |
| **1. Auditoría SDK** | Extraer y auditar SDK completo | ✅ DONE |
| **2. Baseline vendor** | Reproducir build vendor | ✅ DONE |
| **2.5 Provenance** | Cross-compile + patch provenance | ✅ DONE |
| **3. Hardware R36SX** | Documentar hardware real | ✅ DONE |
| **4. Board propia** | r36sx-v26 derivada por evidencia | ✅ DONE (ADR-010) |
| **5. Kernel propio** | Reemplazar kernel/DTB → PHYSICAL PASS | ✅ DONE (iteración 6x) |
| **6. Contrato TreeFrogUI** | Matriz de dependencias + ABI fix | ✅ DONE (ADR-012) |
| **7. Optimizaciones** | Boot rápido + dieta kernel + rendimiento | ✅ CLOSED (sin optimizaciones por decisión del usuario) |
| **8. Rootfs propio** | Buildroot + clean install | ✅ DONE (SHIM cubegm/treefrog activo) |
| **9. Kernel 5.12.4** | Upgrade desde 4.4.186 known-good | ✅ DONE — CLEAN PHYSICAL PASS (menú+audio+input+emuladores; kernel-5-only SD; boot ~10s; uImage 9731d6a5) |

## **9-6. Optimización máxima del kernel 5.12.4** (EN CURSO — decisión del usuario 2026-09-22)

Llevar el kernel 5.12.4 a su punto de desarrollo máximo antes de cualquier migración. Todo lo aprendido (gates, fragment versionado 910X, metodología gap-audit) es capital reutilizable para la migración futura.

| Sub | Ítem | Alcance técnico | Estado |
|---|---|---|---|
| **9-6a** | **Port MUSB/USB** | hcusb.c: struct timeval/do_gettimeofday (removidas 5.0) → ktime API; activar HC_MUSB+USB_MUSB_HDRC; verificar gadget/host | ⏳ EN CURSO |
| **9-6b** | Reconciliación DTB | build DTB (b9b800c8, nodos uart@1/pinmux del D-2b factory-derived) vs SD-proven 1258f1eb — validar físicamente o reconciliar | PENDIENTE |
| **9-6c** | Latencia de display | t2: display init lento en 5.12 (posible timeout AVP-side HDMI PHY); boot 4.4=8s vs 5.12~10s+; investigar y pulir | PENDIENTE |
| **9-6d** | Wi-Fi | drivers en-tree 5.12 (rtlwifi/rtl8xxxu ya compilados como módulos) + módulos vendor (ssv6x5x?); levantar wlan en hardware (si la consola tiene antena/USB dongle) | PENDIENTE |
| **9-6e** | RNDIS | USB gadget RNDIS (CDC Ethernet) — networking por USB: CONFIG_USB_GADGET + f_rndis + bridge/DHCP | PENDIENTE (depende 9-6a) |
| **9-6f** | ADB | Android Debug Bridge via USB FunctionFS (adbd userspace + CONFIG_USB_FUNCTIONFS) — shell/debug sin cable serial | PENDIENTE (depende 9-6a) |

## **Punto de decisión (post 9-6): kernel 5.12.4 a máximo desarrollo**

Cuando 9-6 complete, decidir:

1. **Migración 5.15 LTS (o posterior)** — pró: horizonte de mantenimiento (5.12.4 es EOL); drift mínimo desde 5.12 (los 21 parches vendor aplicarían con fuzz menor); contra: repetir validación física completa. Feasibility audit read-only recomendada antes de comprometerse.
2. **Reestructuración boot de raíz (eliminar cubegm/)** — ⚠️ CONTEXTO: el bootloader PROPIO está CERRADO por post-mortem (2 bricks, ADR; NOR de fábrica = contrato). Con bootloader de fábrica, cubegm/ es el path de boot FIJO. Eliminarlo requeriría re-abrir trabajo de bootloader = riesgo de brick documentado. Cualquier exploración aquí REQUIERE autorización explícita + revisión del post-mortem (docs/experiments/2026-09-20_postmortem-brickeo-bootloader.md).
