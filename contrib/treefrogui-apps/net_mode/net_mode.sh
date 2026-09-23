#!/bin/sh
# TreeFrogUI Network Mode — entry point for network connection management.
# Dispatches by transport flags on the SD root:
#   /mnt/sdcard/rndis.mode  -> USB RNDIS networking (default transport today)
#   (future) wifi.mode      -> WiFi client bring-up
LOG=/mnt/sdcard/NET_MODE_DEBUG.log
echo "$(date '+%H:%M:%S' 2>/dev/null) net_mode invoked" >> "$LOG" 2>/dev/null
if [ -f /mnt/sdcard/wifi.mode ]; then
    exec "$(dirname "$0")/net_wifi.sh"
fi
exec "$(dirname "$0")/net_rndis.sh"
