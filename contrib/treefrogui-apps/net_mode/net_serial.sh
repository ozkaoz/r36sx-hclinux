#!/bin/sh
# USB Serial Mode — shell root via CDC-ACM (COM port en el PC)
# Diferente clase USB que NCM/RNDIS — el AVP no deberia detectar networking.
# Windows: "USB Serial Device" COMx — conectar con PuTTY a ese COM.
# Sin netdev, sin u_ether, sin telnetd. Shell directo via /dev/ttyGS0.
LOG=/mnt/sdcard/NET_MODE_DEBUG.log
ROLE_PATH=/sys/devices/platform/soc/18844000.usb/musb-hdrc.0.auto/mode
UDC_NAME=musb-hdrc.0.auto
G=/sys/kernel/config/usb_gadget/serial_shell

log() { echo "$(date '+%H:%M:%S' 2>/dev/null) $*" >> "$LOG"; }

restore() {
    rc=$?
    trap - EXIT INT TERM
    kill $SHELL_PID $WATCHER_PID 2>/dev/null
    if [ -d "$G" ]; then
        printf '\n' > "$G/UDC" 2>/dev/null
        sleep 1
        rm -f "$G/configs/c.1/acm.usb0" 2>/dev/null
        rmdir "$G/configs/c.1/strings/0x409" "$G/configs/c.1" 2>/dev/null
        rmdir "$G/functions/acm.usb0" "$G/strings/0x409" "$G" 2>/dev/null
    fi
    printf 'host\n' > "$ROLE_PATH" 2>/dev/null
    log "restore completo rc=$rc"
    sync
    exit "$rc"
}
NET_EXIT=0
trap "NET_EXIT=1" TERM
trap restore EXIT INT

: >> "$LOG"
log "=== SERIAL session uptime=$(cut -d' ' -f1 /proc/uptime) ==="

# configfs
mkdir -p /sys/kernel/config 2>/dev/null
mount -t configfs none /sys/kernel/config 2>/dev/null || true
[ -d /sys/kernel/config/usb_gadget ] || { log "FAIL: no configfs"; exit 1; }

# gadget
[ -d "$G" ] && { log "stale — limpiando"; restore 2>/dev/null; }
mkdir "$G" 2>>"$LOG" || { log "FAIL mkdir"; exit 1; }
printf '0x02\n' > "$G/bDeviceClass" 2>/dev/null
printf '0x00\n' > "$G/bDeviceSubClass" 2>/dev/null
printf '0x00\n' > "$G/bDeviceProtocol" 2>/dev/null
printf '0x0525\n' > "$G/idVendor"
printf '0xa4a7\n' > "$G/idProduct"
mkdir -p "$G/strings/0x409" "$G/configs/c.1/strings/0x409" 2>/dev/null
printf 'TreeFrogUI\n' > "$G/strings/0x409/manufacturer"
printf 'TreeFrogUI Serial Shell\n' > "$G/strings/0x409/product"
printf 'serial\n' > "$G/configs/c.1/strings/0x409/configuration"
mkdir "$G/functions/acm.usb0" 2>>"$LOG" || log "acm exists"
ln -s "$G/functions/acm.usb0" "$G/configs/c.1/acm.usb0" 2>>"$LOG" || { log "FAIL link"; exit 1; }
log "gadget serial creado"

# role switch
ORIG_ROLE=$(cat "$ROLE_PATH" 2>/dev/null)
printf 'peripheral\n' > "$ROLE_PATH" 2>>"$LOG" || printf 'b_peripheral\n' > "$ROLE_PATH" 2>>"$LOG" || { log "FAIL role"; exit 1; }
log "role: $ORIG_ROLE -> peripheral"

n=0; while [ "$n" -lt 20 ] && [ ! -e "/sys/class/udc/$UDC_NAME" ]; do sleep 0.5; n=$((n+1)); done
printf '%s\n' "$UDC_NAME" > "$G/UDC" 2>>"$LOG" || { log "FAIL UDC"; exit 1; }
log "UDC bound"

# esperar ttyGS0 y lanzar shell
n=0; while [ "$n" -lt 30 ] && [ ! -e /dev/ttyGS0 ]; do sleep 0.5; n=$((n+1)); done
if [ -e /dev/ttyGS0 ]; then
    stty 115200 < /dev/ttyGS0 2>/dev/null
    log "ttyGS0 ready — shell iniciando"
    while :; do
        sh < /dev/ttyGS0 > /dev/ttyGS0 2>&1
        [ "$NET_EXIT" = 1 ] && break
        sleep 1
    done
    SHELL_PID=
else
    log "FAIL: ttyGS0 no aparecio"
fi

# exit_watcher para B-button
EXIT_WATCHER="/mnt/sdcard/cubegm/usb_exit_watcher"
if [ -x "$EXIT_WATCHER" ]; then
    "$EXIT_WATCHER" $$ >/dev/null 2>&1 &
    WATCHER_PID=$!
fi

# bloquear hasta B o NET_EXIT
while :; do
    [ "$NET_EXIT" = 1 ] && { log "B exit"; break; }
    sleep 1
done
log "saliendo"
