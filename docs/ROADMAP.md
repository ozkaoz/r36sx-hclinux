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
| **9-6a** | **Port MUSB/USB** | hcusb.c timeval→ktime (port 9102) + DUAL_ROLE + stack gadget completo (ports 9103/9104: f_mtp/f_ptp/AOA/audio_source + f_iap/f_ium API-5.12) + S90configfs + kmod. **USB HOST: PHYSICAL PASS** (stick OK) | ✅ DONE (host) |
| **9-6b** | **USB Mode (MTP gadget)** | 14 tests fisicos. PHYSICAL PASS: Windows detecta TreeFrogUI MTP + transferencia OK. Fixes: DUAL_ROLE, S90configfs, modulos visibles via bind, kmod standalone, gadget stack BUILT-IN (workaround al OOPS del module loader), orden config_group_init ANTES de prepare_interf_dir en f_mtp (EL bug raiz del reboot — port 9103) | ✅ DONE (2026-09-23) |
| **9-6c** | **Kernel module loader** | **CAUSA RAÍZ CAZADA (2026-09-25)**: gcc Codescape 6.3.0 miscompila la división constante /12 (`sra>>2`+`mul` low-32 sin `mfhi`); los hcdrivers vendor inyectan ksymtab entries legacy de 8 B → `__ksymtab` % 12 == 8 → nmemb=0x55556348 (verificación matemática vs registros del OOPS) → bsearch fuera del array → OOPS determinista en cmp_name. Fix **0005/9005** (punteros como enteros + `divu` tras asm-barrier). Kernel #44 `e9d95de9` BUILD PASS + gates — **deploy+PHYSICAL TEST pendiente** | ✅ DONE (2026-09-25 PHYSICAL PASS: gf128mul Live, insmod rc=0) |
| **9-6b** | Reconciliación DTB | build DTB (b9b800c8, nodos uart@1/pinmux del D-2b factory-derived) vs SD-proven 1258f1eb — validar físicamente o reconciliar | PENDIENTE |
| **9-6c** | Latencia de display | t2: display init lento en 5.12 (posible timeout AVP-side HDMI PHY); boot 4.4=8s vs 5.12~10s+; investigar y pulir | PENDIENTE |
| **9-6d** | Wi-Fi | drivers en-tree 5.12 (rtlwifi/rtl8xxxu ya compilados como módulos) + módulos vendor (ssv6x5x?); levantar wlan en hardware (si la consola tiene antena/USB dongle) | PENDIENTE |
| **9-6e** | Red USB + overlay AVP | **DONE — PRODUCTION PHYSICAL PASS (2026-09-25)**: NCM = transporte de producción (adaptador de red Windows + telnet root; ADR-015). Overlay azul del AVP = limitación aceptada display-only (lo dispara networking activo en general: gadget CDC-network o PPP sobre ACM; refutados DTS `usb0 disabled`, subclase CDC, serial-ACM networking). Eliminación = firmware AVP propio (clase D, aparcado). Stack en fork `net-mode-app` `66a3cbe` | ✅ DONE |
| **9-6f** | ADB | Android Debug Bridge via USB FunctionFS (adbd userspace + CONFIG_USB_FUNCTIONFS) — shell/debug sin cable serial | PENDIENTE (depende 9-6a) |

## **Punto de decisión (post 9-6): kernel 5.12.4 a máximo desarrollo**

Cuando 9-6 complete, decidir:

1. **Migración 5.15 LTS (o posterior)** — pró: horizonte de mantenimiento (5.12.4 es EOL); drift mínimo desde 5.12 (los 21 parches vendor aplicarían con fuzz menor); contra: repetir validación física completa. Feasibility audit read-only recomendada antes de comprometerse.
2. **Reestructuración boot de raíz (eliminar cubegm/)** — ⚠️ CONTEXTO: el bootloader PROPIO está CERRADO por post-mortem (2 bricks, ADR; NOR de fábrica = contrato). Con bootloader de fábrica, cubegm/ es el path de boot FIJO. Eliminarlo requeriría re-abrir trabajo de bootloader = riesgo de brick documentado. Cualquier exploración aquí REQUIERE autorización explícita + revisión del post-mortem (docs/experiments/2026-09-20_postmortem-brickeo-bootloader.md).
