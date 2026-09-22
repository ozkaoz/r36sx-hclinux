# docs/ROADMAP.md — Fases, gates y formato de iteración

## Visión

BootROM → bootloader (stock) → AVP/HCRTOS (stock, preservado) → **kernel propio (4.4.186)** → **DTB propio** → **rootfs propio (Buildroot)** → picoarch → **TreeFrogUI como shell principal**.

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
| **9. Kernel 5.12.4** | Upgrade con 4.4.186 known-good | DIFERIDO |
