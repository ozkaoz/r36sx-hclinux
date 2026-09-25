#!/usr/bin/env python3
# strip_vendor_ksymtab_8B.py — normalizar .o vendor con ksymtab entries legacy de 8 bytes
#
# 9-6c: el SDK vendor inyecta objetos PRECOMPILADOS (sin fuente) cuyos
# EXPORT_SYMBOL usan el layout pre-5.12 (entries de 8 bytes: value+name, sin
# namespace). get_adc_default_val_for_check se linkea al vmlinux y deja
# __ksymtab con un entry de 8B en mitad de la tabla (posicion alfabetica
# ~1310): desalinea ~2260 entries posteriores para el bsearch de paso-12
# (simbolos NOT-GPL invisibles), y ademas deja size % 12 == 8 (disparador
# del gcc magic-div bug, fixed por 0005).
# Fix: RENOMBRAR esas secciones ___ksymtab+<sym> a ___ksymtab+zzz_legacy_<sym>
# para que el SORT del vmlinux.lds las deje al FINAL de la tabla: los entries
# 12B quedan contiguos y alineados, y el bsearch (nmemb = floor(size/12), fix
# 0005) nunca lee el tail legacy. objcopy --remove-section no funciona: el
# simbolo __ksymtab_<sym> vive en la seccion y objcopy lo rechaza.
# Idempotente: solo toca .o con secciones ___ksymtab* de tamano % 12 != 0.
import os, re, subprocess, sys

KB = sys.argv[1] if len(sys.argv) > 1 else None
if not KB:
    print("uso: strip_vendor_ksymtab_8B.py <kernel-build-dir>")
    sys.exit(1)
TC = os.path.join(os.path.dirname(os.path.abspath(KB)), "..", "host", "bin",
                  "mips-mti-linux-gnu-objcopy")
TC = os.path.abspath(TC)

pat = re.compile(r"\s*\[\s*\d+\]\s+(\S+)\s+(\S+)\s+([0-9a-f]{8})\s+([0-9a-f]+)\s+([0-9a-f]+)")
fixed = 0
scanned = 0
for root, dirs, files in os.walk(KB):
    if "/.git" in root:
        continue
    only_vmlinux_o = ("vmlinux.o" in files) and "hcdrivers" not in root
    for f in files:
        if not f.endswith(".o") or f == "vmlinux.o":
            continue
        p = os.path.join(root, f)
        out = subprocess.run(["readelf", "-S", "-W", p], capture_output=True, text=True).stdout
        bad = []
        for line in out.splitlines():
            m = pat.match(line)
            if m and m.group(1).startswith("___ksymtab"):
                size = int(m.group(5), 16)
                if size > 0 and size % 12 != 0:
                    bad.append(m.group(1))
        if bad:
            args = [TC]
            for s in bad:
                sym = s[len("___ksymtab+"):]
                args += ["--rename-section", f"{s}=___ksymtab+zzz_legacy_{sym}"]
            args.append(p)
            r = subprocess.run(args, capture_output=True, text=True)
            if r.returncode != 0:
                print(f"ERROR {p}: {r.stderr.strip()}")
            else:
                fixed += 1
                print(f"rename: {p} -> {', '.join(bad)}")
        scanned += 1
print(f"escaneados: {scanned}, normalizados: {fixed}")

