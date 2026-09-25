# Experimento 9-6c: fix del kernel module loader (OOPS resolve_symbol) — gcc magic-div bug

**Fecha:** 2026-09-25
**Clase:** C (kernel) + B (herramienta audit)
**Resultado:** causa raíz identificada con evidencia matemática cerrada; fix 0005 compilado y verificado a nivel disasm; **kernel #44 `e9d95de9` BUILD PASS — deploy+test físico PENDIENTE.**

## Síntoma

`insmod` de cualquier `.ko` con símbolos UND mata el loader: SIGSEGV del proceso
+ OOPS del kernel en `resolve_symbol` (module.c:1411) y el `module_mutex` queda
lockeado (histórico 2026-09-22). Workaround previo: gadget functions built-in.

## Experimento de discriminación (2026-09-25)

Dos sondas contra el kernel desplegado `e07844bd` (vermagic idéntico, mismo árbol):

- **A: `hello.ko` con CERO UND symbols** → `insmod` **rc=0** (carga limpia) →
  la infraestructura del loader (layout/alloc/copy/relocs/vermagic) funciona.
- **B: `sha256_generic.ko` (6 UND reales)** → OOPS determinista (2 boots, 2 OOPS
  idénticos byte a byte).

Evidencia: `results.log`, `dmesg-A/B` en la SD (`96c-test/`).

## OOPS y decode (addr2line contra vmlinux con DEBUG_INFO, KALLSYMS off)

```
finit_module → load_module → simplify_symbols:2312 → resolve_symbol_wait:1455
→ resolve_symbol:1411 → find_symbol:527 → find_exported_symbol_in_section:498
→ bsearch → cmp_name:488  ← OOPS (strcmp de ksym->name)
BadVA 0x005ae240 · epc 80087b28 · $5/$16=0x005ae23c · $6=0x55556348 (AMBOS OOPS)
```

## Descartes (evidencia acumulada)

1. `__ksymtab` del vmlinux y del payload (`vmlinux.bin`) **sanos e idénticos**
   (entries de 12 B: value/name/namespace, namespace→string vacío compartido).
2. Ningún patch vendor toca `kernel/module.c` ni `arch/mips/kernel/module.c`.
3. RAM-dumps in-situ (3× /dev/mem por telnet): tabla **sana y estable** en el
   boot de test — la "escritura activa" detectada (PA 0x5DED70) está fuera de
   ksymtab (zona pre-.data; irrelevante para el crash).
4. PHYS_OFFSET=0 (boottrace: mem 0x0-0xaf90fff) → PA(__ksymtab)=VA-0x80000000.
5. `0x005ae23c` = 0x805ae23c & ~0x80000000 = **PA del campo name del entry 105**
   de __ksymtab: el pivot del bsearch cayó FUERA del array.

## CAUSA RAÍZ (cadena completa con verificación matemática)

1. **gcc Codescape 6.3.0 (mips32) miscompila TODA división constante /12**:
   emite `sra 2` + `mul` (LOW-32 bits del producto con magic `0xAAAAAAAB`) en
   vez de `mult`+`mfhi` (HIGH-32). La mitad baja solo coincide con n/12 cuando
   `(n>>2)` es múltiplo de 3. *(disasm de kernel/module.o: secuencia exacta.)*
2. `find_exported_symbol_in_section` divide `(stop-start)` — punteros
   `kernel_symbol*` → ptrdiff **/12** → compilado ROTO.
3. Los **hcdrivers vendor inyectan entries legacy de 8 bytes** (sin namespace:
   `get_adc_default_val_for_check`, `get_adc_default_val` [adc];
   `rtw_radiotap_fixup` [hc-p2p]) → `__ksymtab` = 0xa760 B = 3570×12+8
   (**mod-12 = 8**) → el magic-div produce 0x55556348 en vez de 3570.
4. Verificación cerrada: `((0xa760>>2) * 0xAAAAAAAB) mod 2^32` =
   **0x55556348 = $6 exacto de ambos OOPS** (el nmemb que recibió bsearch).
   `__ksymtab_gpl` (0x8eec, múltiplo exacto) habría dado el valor correcto →
   el bug solo mata búsquedas NOT-GPL (determinista, "cualquier .ko real").
5. bsearch con nmemb gigante: primer pivot fuera del array → iteraciones
   posteriores caen en kuseg (0x005ae23c) → TLB miss → OOPS.

## Fix (0005 → sync 9005, ADR-014): tres iteraciones

- **v1 (variable simple):** gcc 6.3 const-propaga el initializer de `esz` y
  re-emite la secuencia mágica rota + un `divu` del resultado ya corrupto.
- **v2 (asm barrier sobre variable):** la barrier NO basta: el PTRDIFF
  `(stop-start)` de punteros tipados es en sí la división /12 rota.
- **v3 (FINAL):** restar los punteros **como enteros** (`(size_t)stop -
  (size_t)start` = bytes, sin ptrdiff) y dividir por `esz` tras
  `asm("" : "+r"(esz))` (bloquea const-propagation → `divu` real del
  hardware). Mismo tratamiento para `sym - syms->start` (index del
  check_exported_symbol, mismo ptrdiff roto).

Disasm verificado del module.o nuevo: `subu` (bytes) + **2× `divu`** (nmemb e
index), magic `0xaaaa` AUSENTE, `&syms->start[index]` vía `mul` (la
multiplicación no está afectada).

## Artefactos

- Kernel #44: `vmlinux.uImage` **`e9d95de9`** (8.270.741 B, 2026-09-25 11:01)
  — BUILD PASS, gates TOOLCHAIN PASS + PATCH PASS (audit actualizado a 5
  genéricos/6 versionados).
- Parche propio: `patches/buildroot/linux/0005-module-loader-magic-div-fix.patch`
  (canónico a/b, sync SDK `9005-`).
- Probes en SD: `96c-test/{hello.ko, sha256_generic.ko, 96c-test.sh,
  96c-ramdump.sh}` + logs cosechados.
- Logs: `logs/k512-rebuild-96c-0005.log`, `logs/r36sx-v26-k512-build_20260925_*.log`.

## PENDIENTE (clase F, GO requerido)

1. Deploy: `cubegm/vmlinux.uImage` → `e9d95de9` (backup del `e07844bd` en la SD).
2. Test físico: boot → NCM → telnet → `insmod sha256_generic.ko` → **sin OOPS,
   rc=0** + regresión hello.ko + MTP/NET/boot OK → **9-6c PHYSICAL PASS**.
3. Desbloqueado tras PASS: 9-6d Wi-Fi (carga real de módulos) y arquitectura
   sin workaround built-ins.
