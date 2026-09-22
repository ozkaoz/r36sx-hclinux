#!/usr/bin/env bash
# audit_toolchain.sh — KERNEL PROVENANCE GATE (AGENTS.md §14)
# Demuestra el cross-compiler REALMENTE invocado en un output Buildroot del proyecto.
# Read-only sobre el output; WSL-only; idempotente; emite TOOLCHAIN PROVENANCE: PASS/FAIL.
# Uso: ./scripts/audit_toolchain.sh [output-dir]   (default: ~/work/r36sx-hclinux/build/d3100-v20-baseline)
set -uo pipefail

O="${1:-$HOME/work/r36sx-hclinux/build/d3100-v20-baseline}"
FAIL=0
bad() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
ok()  { echo "  [PASS] $1"; }

echo "=== TOOLCHAIN PROVENANCE AUDIT — $O ==="

# 1. host
echo "-- host --"
UNAME_M="$(uname -m)"
echo "  host arch: $UNAME_M ($(grep PRETTY /etc/os-release | cut -d'"' -f2))"
[ "$UNAME_M" = "x86_64" ] && ok "host x86_64" || bad "host inesperado: $UNAME_M"

# 2. target config
echo "-- target (Buildroot .config) --"
CFG="$O/.config"
[ -f "$CFG" ] || { bad "no existe $CFG"; echo "TOOLCHAIN PROVENANCE: FAIL"; exit 1; }
KVER=$(sed -n 's/^BR2_LINUX_KERNEL_VERSION="\([^"]*\)"/\1/p' "$O/.config" 2>/dev/null)
KVER="${KVER:-4.4.186}"
for kv in 'BR2_ARCH="mipsel"' 'BR2_ENDIAN="LITTLE"' 'BR2_TOOLCHAIN_EXTERNAL_PREFIX="mips-mti-linux-gnu"' "BR2_LINUX_KERNEL_VERSION=\"$KVER\""; do
  grep -q "^$kv$" "$CFG" && ok "$kv" || bad "falta $kv"
done

# 3. cross compiler real (.cmd de kbuild — presence != use)
echo "-- cross compiler invocado (kbuild .cmd) --"
KB="$O/build/linux-$KVER"
[ -d "$KB" ] || { bad "no existe kernel build dir $KB"; echo "TOOLCHAIN PROVENANCE: FAIL"; exit 1; }
NCMD=$(find "$KB" -name '*.cmd' -type f 2>/dev/null | wc -l)
[ "$NCMD" -gt 100 ] && ok "$NCMD .cmd files presentes" || bad "solo $NCMD .cmd files"
MIPSGCC=$(grep -rhoE '[^ ;"]*mips[^ ;"]*-gcc' "$KB" --include='*.cmd' 2>/dev/null | sort -u | head -3)
echo "  compiladores en .cmd: $(echo "$MIPSGCC" | tr '\n' ' ')"
echo "$MIPSGCC" | grep -q "mips-mti-linux-gnu-gcc" && ok "mips-mti-linux-gnu-gcc INVOCADO (evidencia .cmd)" || bad "gcc MIPS no aparece en .cmd"
# muestra multi-subsystem (>=3 dirs distintos)
SUBS=$(find "$KB" -name '*.cmd' -path '*mips-mti-linux-gnu-gcc*' 2>/dev/null | sed 's|/\.|/|' | awk -F/ '{print $(NF-2)}' | sort -u | head -5)
SUBN=$(grep -rl "mips-mti-linux-gnu-gcc" "$KB" --include='*.cmd' 2>/dev/null | awk -F/ '{print $(NF-1)}' | sort -u | wc -l)
[ "$SUBN" -ge 3 ] && ok "invocado en $SUBN subsistemas distintos (>=3)" || bad "solo $SUBN subsistemas"

# 4. triplet/sysroot del gcc del output
echo "-- toolchain identity --"
GCC="$O/host/opt/ext-toolchain/bin/mips-mti-linux-gnu-gcc"
if [ -x "$GCC" ]; then
  V="$("$GCC" --version | head -1)"; T="$("$GCC" -dumpmachine)"; SR="$("$GCC" -print-sysroot)"
  echo "  version: $V"; echo "  triplet: $T"; echo "  sysroot: $SR"
  echo "$V" | grep -q "Codescape GNU Tools 2018.09-02" && ok "Codescape 2018.09-02" || bad "versión inesperada"
  [ "$T" = "mips-mti-linux-gnu" ] && ok "triplet correcto" || bad "triplet: $T"
else
  bad "no existe $GCC"
fi

# 5. ELF resultantes MIPS (kernel + userspace + módulo)
echo "-- ELF resultantes --"
readelf_check() {
  local f="$1" what="$2"
  if [ -f "$f" ]; then
    M=$(readelf -h "$f" 2>/dev/null | grep "Machine:" | awk '{print $NF, $(NF-1)}')
    C=$(readelf -h "$f" 2>/dev/null | grep "Class:" | awk '{print $NF}')
    E=$(readelf -h "$f" 2>/dev/null | grep "Data:" | grep -o "little" || true)
    if echo "$M" | grep -q "MIPS" && [ "$C" = "ELF32" ]; then
      ok "$what: ELF32 MIPS $( [ -n "$E" ] && echo LE ) — $f"
    else bad "$what no es ELF32 MIPS: $M $C — $f"; fi
  else bad "ausente: $f"; fi
}
readelf_check "$KB/vmlinux" "kernel vmlinux"
BB=$(find "$O/build/busybox-"* -maxdepth 1 -name busybox -type f 2>/dev/null | head -1)
readelf_check "$BB" "busybox userspace"
KO=$(find "$O/build" -name '*.ko' -type f 2>/dev/null | head -1)
[ -n "$KO" ] && readelf_check "$KO" "módulo .ko" || echo "  [INFO] sin módulos .ko en output"

# 6. vermagic corrección (informativo, no gate)
echo "-- vermagic (informativo; user@host NO prueba toolchain) --"
strings "$KB/vmlinux" 2>/dev/null | grep -m1 "Linux version" | sed 's/^/  /'
CM=$(readelf -p .comment "$KB/vmlinux" 2>/dev/null | grep -m1 "GCC:")
echo "  .comment: $CM"

echo "=== RESULT: FAIL=$FAIL ==="
if [ "$FAIL" -eq 0 ]; then echo "TOOLCHAIN PROVENANCE: PASS"; else echo "TOOLCHAIN PROVENANCE: FAIL"; exit 1; fi
