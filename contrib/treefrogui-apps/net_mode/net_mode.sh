#!/bin/sh
# TreeFrogUI Network Mode. Dispatcher de transport.
# net.mode en la raiz SD = activa el modo red (lo chequea usb_mtp.sh).
# Dentro: rndis.mode = RNDIS (fallback); default = NCM (Windows nativo).
LOG=/mnt/sdcard/NET_MODE_DEBUG.log
echo "$(date '+%H:%M:%S' 2>/dev/null) net_mode invoked" >> "$LOG" 2>/dev/null
if [ -f /mnt/sdcard/rndis.mode ]; then
    exec "$(dirname "$0")/net_rndis.sh"
fi
exec "$(dirname "$0")/net_ncm.sh"
