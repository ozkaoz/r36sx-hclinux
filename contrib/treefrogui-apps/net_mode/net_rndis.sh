#!/bin/sh
# TreeFrogUI Net Mode — USB RNDIS transport.
# Gadget UNA sola funcion rndis.usb0 (3 EPs: 2 bulk + 1 int) — cabe en los 4 EPs
# del musb. (El multifuncion MTP+RNDIS = 5 EPs = la causa de la pantalla azul.)
# Clase CDC clasica (dev 0x02/0x02/0xFF + VID 0525:a4a2) -> Windows auto-instala
# usb8023. Consola: usb0 192.168.137.2 | PC: 192.168.137.1 -> telnet 192.168.137.2.
LOG=/mnt/sdcard/NET_MODE_DEBUG.log
ROLE_PATH=/sys/devices/platform/soc/18844000.usb/musb-hdrc.0.auto/mode
ROLE_FALLBACK=$(find /sys/devices -path '*musb-hdrc.0.auto/mode' -print -quit 2>/dev/null)
[ -n "$ROLE_FALLBACK" ] && [ -e "$ROLE_FALLBACK" ] && ROLE_PATH="$ROLE_FALLBACK"
UDC_NAME=musb-hdrc.0.auto
G=/sys/kernel/config/usb_gadget/rndis_net

log() { echo "$(date '+%H:%M:%S' 2>/dev/null || echo t) $*" >> "$LOG"; }

restore() {
    rc=$?
    trap - EXIT INT TERM
    killall telnetd 2>/dev/null
    ifconfig usb0 down 2>/dev/null
    if [ -d "$G" ]; then
        printf '\n' > "$G/UDC" 2>/dev/null
        sleep 1
        rm -f "$G/configs/c.1/rndis.usb0" 2>/dev/null
        rmdir "$G/configs/c.1/strings/0x409" "$G/configs/c.1" 2>/dev/null
        rmdir "$G/functions/rndis.usb0" "$G/strings/0x409" "$G" 2>/dev/null
    fi
    printf 'host\n' > "$ROLE_PATH" 2>/dev/null || printf 'b_idle\n' > "$ROLE_PATH" 2>/dev/null
    log "restore completo rc=$rc"
    sync
    exit "$rc"
}
trap restore EXIT INT TERM

: >> "$LOG"
log "=== RNDIS session uptime=$(cut -d' ' -f1 /proc/uptime) role=$(cat "$ROLE_PATH" 2>/dev/null) ==="

# configfs (S90configfs normalmente ya lo monto — fallback igual)
mkdir -p /sys/kernel/config 2>/dev/null
mount -t configfs none /sys/kernel/config 2>/dev/null || true
[ -d /sys/kernel/config/usb_gadget ] || { log "FAIL: no usb_gadget en configfs"; exit 1; }

# gadget limpio
[ -d "$G" ] && { log "stale gadget — limpiando"; restore 2>/dev/null; }
mkdir "$G" 2>>"$LOG" || { log "FAIL mkdir gadget"; exit 1; }

# Clase CDC a nivel DISPOSITIVO (0x02/0x00/0x00 = g_rndis clasico). El MATCH
# real lo hace la INTERFAZ de f_rndis (0x02/0x02/0xFF) con usb8023.sys. (v2:
# 0x02/0x02/0xFF a nivel dispositivo = Windows lo tomo como modem CDC-ACM -> COM7!)
printf '0x02\n' > "$G/bDeviceClass"
printf '0x00\n' > "$G/bDeviceSubClass"
printf '0x00\n' > "$G/bDeviceProtocol"
printf '0x0525\n' > "$G/idVendor"
printf '0xa4a2\n' > "$G/idProduct"
printf '0x0200\n' > "$G/bcdUSB"
mkdir -p "$G/strings/0x409" "$G/configs/c.1/strings/0x409" 2>/dev/null
printf 'R36SX\n' > "$G/strings/0x409/manufacturer"
printf 'R36SX RNDIS Net\n' > "$G/strings/0x409/product"
printf 'rndis\n' > "$G/configs/c.1/strings/0x409/configuration"
printf '250\n' > "$G/configs/c.1/MaxPower" 2>/dev/null

mkdir "$G/functions/rndis.usb0" 2>>"$LOG" || log "rndis.usb0 ya existia"
ln -s "$G/functions/rndis.usb0" "$G/configs/c.1/rndis.usb0" 2>>"$LOG" || { log "FAIL link"; exit 1; }

# MS OS Descriptors — EL fix del COM7: el compatible ID "RNDIS" hace que Windows
# cargue netrndis.inf/usb8023 (adaptador de red) con prioridad sobre el serial.
# El f_rndis registra su os_desc interface como "rndis" (minuscula, ver f_rndis.c:946).
if [ -d "$G/functions/rndis.usb0/os_desc/interface.rndis" ]; then
    printf 'RNDIS\n' > "$G/functions/rndis.usb0/os_desc/interface.rndis/compatible_id" 2>>"$LOG"
    log "os_desc fn: RNDIS compatible_id OK"
elif [ -d "$G/functions/rndis.usb0/os_desc/interface.RNDIS" ]; then
    printf 'RNDIS\n' > "$G/functions/rndis.usb0/os_desc/interface.RNDIS/compatible_id" 2>>"$LOG"
    log "os_desc fn: RNDIS compatible_id OK (mayuscula)"
else
    log "AVISO: no os_desc interface.rndis en la funcion — compatible ID no seteado"
fi
mkdir -p "$G/os_desc" 2>>"$LOG" || true
printf '1\n' > "$G/os_desc/b_vendor_code"
printf 'MSFT100\n' > "$G/os_desc/qw_sign"
ln -s "$G/configs/c.1" "$G/os_desc/c.1" 2>>"$LOG" || { log "FAIL os_desc link"; }
printf '1\n' > "$G/os_desc/use" && log "os_desc gadget: use=1 (MSFT100)" || log "FAIL os_desc use"
log "gadget creado"

# role switch (patron probado del stack)
ORIG_ROLE=$(cat "$ROLE_PATH" 2>/dev/null)
printf 'peripheral\n' > "$ROLE_PATH" 2>>"$LOG" || printf 'b_peripheral\n' > "$ROLE_PATH" 2>>"$LOG" || { log "FAIL role switch"; exit 1; }
log "role: $ORIG_ROLE -> peripheral"
n=0; while [ "$n" -lt 20 ] && [ ! -e "/sys/class/udc/$UDC_NAME" ]; do sleep 0.5; n=$((n+1)); done
[ -e "/sys/class/udc/$UDC_NAME" ] || { log "FAIL: UDC no aparecio"; exit 1; }

printf '%s\n' "$UDC_NAME" > "$G/UDC" 2>>"$LOG" || { log "FAIL UDC bind"; exit 1; }
log "UDC bound"

# la red
n=0; while [ "$n" -lt 20 ] && [ ! -e /sys/class/net/usb0 ]; do sleep 0.5; n=$((n+1)); done
if [ -e /sys/class/net/usb0 ]; then
    ifconfig usb0 192.168.137.2 netmask 255.255.255.0 up 2>>"$LOG" && log "usb0 192.168.137.2 UP" || log "FAIL ifconfig usb0"
else
    log "FAIL: usb0 no aparecio"
fi
telnetd -l /bin/sh 2>>"$LOG" && log "telnetd OK" || log "telnetd FAIL"
log "RNDIS READY — PC: adaptador -> 192.168.137.1/24, telnet 192.168.137.2"
sync

# bloquear hasta desconectar (patron del stack: cable unplug = detached)
configured=0
while :; do
    state=$(cat "/sys/class/udc/$UDC_NAME/state" 2>/dev/null || echo detached)
    [ "$state" = "configured" ] && configured=1
    if [ "$configured" = 1 ] && [ "$state" = "not attached" ]; then
        log "PC desconecto — saliendo"
        break
    fi
    sleep 1
done
