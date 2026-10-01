#!/usr/bin/env bash
# kernel_switch_lib.sh — Fase E (E3): librería común del kernel switcher stock↔propio.
# Se CARGA con source; no se ejecuta directo. Usuarios:
#   kernel_to_own.sh (E1) · kernel_to_stock.sh (E2) · kernel_switch_status.sh
#
# Contrato AGENTS §5: identificar dispositivo → mostrar info → confirmar → autorizar → escribir.
# Este módulo SOLO copia archivos dentro de la SD (nunca dd/mkfs/flash/NOR).
# La SD stock del usuario es golden: solo se tocan vmlinux.uImage + dtb.bin
# (y avp.uImage únicamente con --avp explícito).
#
# Estado del switcher en la SD:  <sd>/kernel-switch/
#   state                    KEY=VALUE (STATE, LAYOUT, ORIG_BACKUP, UPDATED, VERSION)
#   orig/                    recovery point del PRIMER uso (en consola stock = SU kernel stock)
#   orig/manifest.sha256     formato sha256sum -c (paths relativos al dir del manifest)
#   sets/<UTC>/              snapshot del par saliente en CADA switch (rotación: últimos 3)
#   sets/<UTC>/manifest.sha256
#
# Bases canónicas (directiva del usuario, 2026-09-30):
#   STOCK  = "R36SX V2.6 (0712) Minimal Backup" (Desktop) — SO stock completo (cubegm/),
#            verificado byte-idéntico a los goldens (kernel 53b3e0b3 · dtb 1258f1eb · avp a9788995).
#   PROPIO = SD viva de la consola (/mnt/g/boot) — copia offline: Desktop "SO PROPIO" (kernel c6e3cc70).

KS_VERSION="1.0"
KS_PAIR=(vmlinux.uImage dtb.bin)
KS_STATE_DIR="kernel-switch"
KS_SETS_KEEP=3
KS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KS_REPO_ROOT="$(cd "$KS_LIB_DIR/.." && pwd)"
KS_GOLDEN_MANIFEST="${KS_GOLDEN_MANIFEST:-$KS_REPO_ROOT/manifests/GOLDEN_STOCK.sha256}"
# Override por env (tests) — defaults = bases canónicas del usuario
KS_STOCK_BASE_DEFAULT="${KS_STOCK_BASE_DEFAULT:-/mnt/c/Users/DaFunkNoise/Desktop/Instalación Base TREEFROG/R36SX V2.6 (0712) Minimal Backup/cubegm}"
KS_STOCK_BASE_FALLBACK="${KS_STOCK_BASE_FALLBACK:-/mnt/d/R36SX/goldens-stock}"
KS_OWN_BASE_DEFAULT="${KS_OWN_BASE_DEFAULT:-/mnt/g/boot}"

ks_die() { echo "ERROR: $*" >&2; exit 1; }
ks_log() { echo "[kernel-switch] $*"; }

ks_sha256() { sha256sum "$1" | cut -d' ' -f1; }

# ---------- SD / layout ----------

ks_require_sd() { # $1=dir — valida y devuelve ruta sin barra final
  local sd="${1:-}"
  if [ -z "$sd" ]; then ks_die "falta --sd <ruta de la SD>"; fi
  sd="${sd%/}"
  if [ ! -d "$sd" ]; then ks_die "SD no accesible: $sd"; fi
  case "$sd" in
    "/"|"/mnt"|"/mnt/"|"/home"|"/home/"|"$HOME"|"$HOME/") ks_die "objetivo rechazado (raíz del sistema): $sd" ;;
  esac
  printf '%s\n' "$sd"
}

ks_detect_layout() { # $1=sd → boot | cubegm — boot/ TIENE PRIORIDAD.
  # En el modo carpeta v2 (SO stock completo) AMBAS carpetas coexisten POR DISEÑO:
  # boot/ = par que carga el bootloader propio (Fase D); cubegm/ = sistema stock
  # (payload del kernel de fábrica). El bootloader propio lee boot/ → boot/ manda.
  # Una consola con NOR de fábrica nunca tiene boot/ en su SD → cubegm/.
  local sd="$1"
  if [ -f "$sd/boot/vmlinux.uImage" ]; then
    printf 'boot\n'
    return 0
  fi
  if [ -f "$sd/cubegm/vmlinux.uImage" ]; then
    printf 'cubegm\n'
    return 0
  fi
  ks_die "no se detectó layout de boot: se espera <sd>/boot/vmlinux.uImage (NOR propio, Fase D) o <sd>/cubegm/vmlinux.uImage (bootloader stock)"
}

ks_state_dir() { printf '%s/%s\n' "$1" "$KS_STATE_DIR"; }

ks_state_read() { # $1=sd → setea KS_STATE / KS_STATE_LAYOUT / KS_ORIG_BACKUP / KS_STATE_MODE
  local sf v
  sf="$(ks_state_dir "$1")/state"
  KS_STATE="unknown"; KS_STATE_LAYOUT="-"; KS_ORIG_BACKUP="no"; KS_STATE_MODE="file"
  if [ -f "$sf" ]; then
    v="$(sed -n 's/^STATE=//p' "$sf" | tail -n1)"; if [ -n "$v" ]; then KS_STATE="$v"; fi
    v="$(sed -n 's/^LAYOUT=//p' "$sf" | tail -n1)"; if [ -n "$v" ]; then KS_STATE_LAYOUT="$v"; fi
    v="$(sed -n 's/^MODE=//p' "$sf" | tail -n1)"; if [ -n "$v" ]; then KS_STATE_MODE="$v"; fi
    v="$(sed -n 's/^ORIG_BACKUP=//p' "$sf" | tail -n1)"; if [ -n "$v" ]; then KS_ORIG_BACKUP="$v"; fi
  fi
  return 0
}

ks_state_write() { # $1=sd $2=STATE $3=MODE(file|folder — default file)
  local d
  d="$(ks_state_dir "$1")"
  mkdir -p "$d"
  {
    printf 'STATE=%s\n' "$2"
    printf 'LAYOUT=%s\n' "$(ks_detect_layout "$1")"
    printf 'MODE=%s\n' "${3:-file}"
    printf 'ORIG_BACKUP=%s\n' "$(if [ -d "$d/orig" ]; then echo yes; else echo no; fi)"
    printf 'UPDATED=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'VERSION=%s\n' "$KS_VERSION"
  } > "$d/state"
}

# ---------- goldens (informativo: ¿es stock conocido?) ----------

ks_golden_hash() { # $1=nombre de archivo → hash documentado (hex-64 válido) o vacío
  if [ ! -f "$KS_GOLDEN_MANIFEST" ]; then return 0; fi
  awk -v n="$1" '$0 !~ /^#/ && $2==n && $1 ~ /^[0-9a-f]{64}$/ {print $1; exit}' "$KS_GOLDEN_MANIFEST"
  return 0
}

ks_manifest_hashes() { # $1=dir $2=filename → hash del manifest (hex-64 válido) o vacío.
  # NOTA (evidencia selftest T8): sha256sum -c IGNORA líneas con formato inválido
  # (improperly formatted) — exit 0 aunque la línea del archivo crítico esté corrompida.
  # Por eso la verificación exige línea válida para CADA archivo del par ANTES de -c.
  local dir="$1" name="$2" mf=""
  if [ -f "$dir/manifest.sha256" ]; then mf="manifest.sha256"; fi
  if [ -z "$mf" ] && [ -f "$dir/SHA256SUMS" ]; then mf="SHA256SUMS"; fi
  if [ -z "$mf" ]; then return 0; fi
  awk -v n="$name" '$0 !~ /^#/ && $2==n && $1 ~ /^[0-9a-f]{64}$/ {print $1; exit}' "$dir/$mf" 2>/dev/null
  return 0
}

ks_describe_file() { # $1=archivo → imprime "hash [etiqueta]"
  local h g
  if [ ! -f "$1" ]; then printf '(ausente)\n'; return 0; fi
  h="$(ks_sha256 "$1")"
  g="$(ks_golden_hash "$(basename "$1")")"
  if [ -n "$g" ]; then
    if [ "$h" = "$g" ]; then
      printf '%s [STOCK GOLDEN]\n' "$h"
    else
      printf '%s (distinto del golden stock %s)\n' "$h" "${g:0:8}"
    fi
  else
    printf '%s\n' "$h"
  fi
}

# ---------- backup / restore / rotación (E3) ----------

ks_backup_pair() { # $1=sd $2=layout $3=dest_dir $4=avp(1|0)
  local sd="$1" layout="$2" dest="$3" avp="${4:-0}" f src
  mkdir -p "$dest"
  : > "$dest/manifest.sha256"
  for f in "${KS_PAIR[@]}"; do
    src="$sd/$layout/$f"
    if [ ! -f "$src" ]; then ks_die "falta archivo de boot: $src"; fi
    cp "$src" "$dest/$f" || ks_die "backup falló: $src"
    printf '%s  %s\n' "$(ks_sha256 "$dest/$f")" "$f" >> "$dest/manifest.sha256"
  done
  if [ "$avp" = "1" ]; then
    src="$sd/$layout/avp.uImage"
    if [ ! -f "$src" ]; then ks_die "falta avp.uImage (—avp): $src"; fi
    cp "$src" "$dest/avp.uImage" || ks_die "backup falló: $src"
    printf '%s  %s\n' "$(ks_sha256 "$dest/avp.uImage")" "avp.uImage" >> "$dest/manifest.sha256"
  fi
  ( cd "$dest" && sha256sum -c manifest.sha256 ) >/dev/null || ks_die "verificación del backup falló: $dest"
}

ks_backup_ok() { # $1=dir → 0 solo si TODOS los archivos del par tienen línea válida Y -c pasa
  local dir="$1" mf="" f h
  if [ ! -d "$dir" ]; then return 1; fi
  if [ -f "$dir/manifest.sha256" ]; then mf="manifest.sha256"; fi
  if [ -z "$mf" ] && [ -f "$dir/SHA256SUMS" ]; then mf="SHA256SUMS"; fi
  if [ -z "$mf" ]; then return 1; fi
  for f in "${KS_PAIR[@]}"; do
    h="$(ks_manifest_hashes "$dir" "$f")"
    if [ -z "$h" ]; then return 1; fi
  done
  ( cd "$dir" && sha256sum -c "$mf" ) >/dev/null 2>&1
}

ks_verify_backup() { # $1=dir — muere si el backup está corrupto
  local dir="$1"
  if [ ! -d "$dir" ]; then ks_die "backup inexistente: $dir"; fi
  if ks_backup_ok "$dir"; then :; else
    ks_die "BACKUP CORRUPTO o sin manifest (sha256 FAIL): $dir — NO se toca la SD"
  fi
}

ks_stock_base_dir() { # → primera base stock canónica disponible (vacío si ninguna)
  if [ -f "$KS_STOCK_BASE_DEFAULT/vmlinux.uImage" ] && [ -f "$KS_STOCK_BASE_DEFAULT/dtb.bin" ]; then
    printf '%s\n' "$KS_STOCK_BASE_DEFAULT"; return 0
  fi
  if [ -f "$KS_STOCK_BASE_FALLBACK/vmlinux.uImage" ] && [ -f "$KS_STOCK_BASE_FALLBACK/dtb.bin" ]; then
    printf '%s\n' "$KS_STOCK_BASE_FALLBACK"; return 0
  fi
  return 0
}

ks_check_golden_dir() { # $1=golden_dir $2=avp(1|0) — verifica hashes contra el manifiesto del repo; muere si mismatch
  local dir="$1" avp="${2:-0}" f h g
  if [ ! -f "$KS_GOLDEN_MANIFEST" ]; then
    ks_die "manifiesto golden del repo inexistente: $KS_GOLDEN_MANIFEST — no se puede verificar un restore golden"
  fi
  for f in "${KS_PAIR[@]}"; do
    if [ ! -f "$dir/$f" ]; then ks_die "falta $f en la base golden: $dir"; fi
    h="$(ks_sha256 "$dir/$f")"
    g="$(ks_golden_hash "$f")"
    if [ -z "$g" ] || [ "$h" != "$g" ]; then
      ks_die "hash de $dir/$f NO coincide con el golden del repo (${h:0:8}) — restore golden RECHAZADO"
    fi
  done
  if [ "$avp" = "1" ]; then
    if [ ! -f "$dir/avp.uImage" ]; then ks_die "falta avp.uImage en la base golden: $dir"; fi
    h="$(ks_sha256 "$dir/avp.uImage")"
    g="$(ks_golden_hash avp.uImage)"
    if [ -z "$g" ] || [ "$h" != "$g" ]; then
      ks_die "hash de avp.uImage NO coincide con el golden del repo — restore golden RECHAZADO"
    fi
  fi
}

ks_restore_golden() { # $1=sd $2=layout $3=golden_dir $4=avp(1|0) — cada archivo verificado
  # contra manifests/GOLDEN_STOCK.sha256 ANTES de escribir; cualquier mismatch = rechazo.
  local sd="$1" layout="$2" dir="$3" avp="${4:-0}" f
  ks_check_golden_dir "$dir" "$avp"
  for f in "${KS_PAIR[@]}"; do
    ks_install_file "$dir/$f" "$sd/$layout/$f"
  done
  if [ "$avp" = "1" ]; then
    ks_install_file "$dir/avp.uImage" "$sd/$layout/avp.uImage"
  fi
}

ks_snapshot_current() { # $1=sd $2=layout $3=avp(1|0) → sets/<ts>/ + rotación KS_SETS_KEEP
  local sd="$1" layout="$2" avp="${3:-0}" sets ts old
  sets="$(ks_state_dir "$sd")/sets"
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  ks_backup_pair "$sd" "$layout" "$sets/$ts" "$avp"
  ks_log "snapshot saliente: kernel-switch/sets/$ts"
  ls -1 "$sets" | sort -r | tail -n +"$((KS_SETS_KEEP + 1))" | while IFS= read -r old; do
    if [ -n "$old" ]; then
      rm -rf "${sets:?}/$old"
      ks_log "rotación: sets/$old eliminado (se conservan $KS_SETS_KEEP)"
    fi
  done
  return 0
}

# ---------- escritura segura ----------

ks_install_file() { # $1=src $2=dest — copia a .tmp + verificación hash + rename atómico
  local src="$1" dest="$2" hs ht tmp
  if [ ! -f "$src" ]; then ks_die "fuente inexistente: $src"; fi
  hs="$(ks_sha256 "$src")"
  tmp="$dest.tmp.$$"
  cp "$src" "$tmp" || ks_die "copia falló: $src -> $tmp"
  ht="$(ks_sha256 "$tmp")"
  if [ "$hs" != "$ht" ]; then
    rm -f "$tmp"
    ks_die "hash post-copia difiere (medio inestable): $src"
  fi
  mv -f "$tmp" "$dest" || ks_die "rename falló: $dest"
  sync "$dest" 2>/dev/null || sync
  ks_log "instalado: $dest (${hs:0:8})"
}

ks_restore_from() { # $1=sd $2=layout $3=backup_dir $4=avp(1|0)
  # Pre-check de TODOS los archivos ANTES de escribir (sin switches parciales).
  local sd="$1" layout="$2" dir="$3" avp="${4:-0}" f
  ks_verify_backup "$dir"
  for f in "${KS_PAIR[@]}"; do
    if [ ! -f "$dir/$f" ]; then ks_die "falta $f en $dir (pre-check)"; fi
  done
  if [ "$avp" = "1" ] && [ ! -f "$dir/avp.uImage" ]; then
    ks_die "falta avp.uImage en $dir (pre-check con --avp)"
  fi
  for f in "${KS_PAIR[@]}"; do
    ks_install_file "$dir/$f" "$sd/$layout/$f"
  done
  if [ "$avp" = "1" ]; then
    ks_install_file "$dir/avp.uImage" "$sd/$layout/avp.uImage"
  fi
}

# ---------- info / confirmación ----------

ks_show_info() { # $1=sd $2=layout
  local sd="$1" layout="$2" dev f
  ks_state_read "$sd"
  echo "--- SD: $sd ---"
  dev="$(findmnt -T "$sd" -no SOURCE 2>/dev/null | head -n1)"
  echo "dispositivo: ${dev:-(sin info de mount)} | layout: $layout/ | estado switcher: $KS_STATE (modo $KS_STATE_MODE, backup original: $KS_ORIG_BACKUP)"
  for f in vmlinux.uImage dtb.bin avp.uImage; do
    printf '  %s: %s\n' "$f" "$(ks_describe_file "$sd/$layout/$f")"
  done
}

# ---------- modo CARPETA (boot/ ↔ cubegm/ — consola NOR propio ↔ NOR fábrica) ----------
# Evidencia Fase D (boot-2): el bootloader del NOR lee SU path-prefix EXCLUSIVAMENTE
# (propio: "boot"; fábrica: "cubegm") — sin fallback. El swap de carpeta REQUIERE el
# flash NOR correspondiente (kits HCProgrammer probados) — los scripts lo dejan
# preparado e imprimen los pasos; el flash es físico (GUI Windows + ventana BootROM).

ks_confirm() { # $1=prompt — KS_YES=1 salta la pregunta
  local a
  if [ "${KS_YES:-0}" = "1" ]; then return 0; fi
  read -r -p "$1 [y/N]: " a || { echo; echo "Cancelado."; exit 1; }
  case "$a" in
    y|Y|yes|YES|s|S|si|SI) return 0 ;;
    *) echo "Cancelado."; exit 1 ;;
  esac
}

ks_folders_dir() { printf '%s/folders\n' "$(ks_state_dir "$1")"; }

ks_folder_manifest_to() { # $1=dir $2=dest_manifest_file — manifiesto de TODOS los archivos (relativo a dir)
  ( cd "$1" && find . -type f -print0 | sort -z | xargs -0 sha256sum ) > "$2"
}

ks_folder_ok() { # $1=dir → 0 si $1.manifest.sha256 (al lado) verifica
  local dir="$1"
  if [ ! -d "$dir" ]; then return 1; fi
  if [ ! -f "$dir.manifest.sha256" ]; then return 1; fi
  ( cd "$dir" && sha256sum -c "$dir.manifest.sha256" ) >/dev/null 2>&1
}

ks_folder_backup() { # $1=carpeta $2=dest_dir — MUEVE (rename mismo volumen) + manifest al lado
  local src="$1" dest="$2"
  if [ ! -d "$src" ]; then ks_die "carpeta a respaldar inexistente: $src"; fi
  if [ -e "$dest" ]; then ks_die "destino de backup ya existe: $dest"; fi
  mkdir -p "$(dirname "$dest")"
  mv "$src" "$dest" || ks_die "fallo moviendo $src -> $dest"
  ks_folder_manifest_to "$dest" "$dest.manifest.sha256" || ks_die "manifest del backup falló: $dest"
  sync
  ks_log "carpeta respaldada (move+manifest): $src -> $dest"
}

ks_folder_install() { # $1=src_folder $2=dest_folder — cp -a + rename + verificación TOTAL contra el origen
  local src="$1" dest="$2" tmp mf
  if [ ! -d "$src" ]; then ks_die "carpeta fuente inexistente: $src"; fi
  if [ -e "$dest" ]; then ks_die "el destino ya existe: $dest (respaldar primero)"; fi
  tmp="$dest.tmp.$$"
  mf="$dest.manifest.sha256.tmp.$$"
  ks_log "copiando carpeta: $src -> $dest (verificación total al final — puede tardar)"
  cp -a "$src" "$tmp" || { rm -rf "$tmp"; rm -f "$mf"; ks_die "copia falló: $src"; }
  ks_folder_manifest_to "$tmp" "$mf" || { rm -rf "$tmp"; rm -f "$mf"; ks_die "manifest de la copia falló: $tmp"; }
  if ( cd "$src" && sha256sum -c "$mf" ) >/dev/null 2>&1; then :; else
    rm -rf "$tmp"; rm -f "$mf"
    ks_die "verificación de la copia falló (hashes difieren del origen): $src"
  fi
  mv -f "$tmp" "$dest" || { rm -rf "$tmp"; rm -f "$mf"; ks_die "rename falló: $dest"; }
  mv -f "$mf" "$dest.manifest.sha256" || ks_die "no se pudo situar el manifest: $dest.manifest.sha256"
  sync
  ks_log "carpeta instalada y verificada: $dest"
}
