#!/bin/sh
# TreeFrogUI Network Mode. Dispatcher.
# ncm.mode = NCM networking; default = serial shell (sin netdev, sin azul).
LOG=/mnt/sdcard/NET_MODE_DEBUG.log
echo "$(date '+%H:%M:%S' 2>/dev/null) net_mode invoked" >> "$LOG" 2>/dev/null
if [ -f /mnt/sdcard/ncm.mode ]; then
    exec "$(dirname "$0")/net_ncm.sh"
fi
exec "$(dirname "$0")/net_serial.sh"
