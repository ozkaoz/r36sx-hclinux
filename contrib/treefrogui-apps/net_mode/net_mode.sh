#!/bin/sh
# TreeFrogUI Network Mode — entry point.
# Transport por defecto: CDC-NCM (Windows 7+ nativo, sin RNDIS deprecation).
# Flag /mnt/sdcard/rndis.mode -> RNDIS (fallback si NCM no funciona en tu PC).
LOG=/mnt/sdcard/NET_MODE_DEBUG.log
echo "$(date '+%H:%M:%S' 2>/dev/null) net_mode invoked" >> "$LOG" 2>/dev/null
if [ -f /mnt/sdcard/rndis.mode ]; then
    exec "$(dirname "$0")/net_rndis.sh"
fi
exec "$(dirname "$0")/net_ncm.sh"
