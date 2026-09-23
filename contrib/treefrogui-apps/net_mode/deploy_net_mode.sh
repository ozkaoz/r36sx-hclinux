#!/bin/bash
# Despliega la app net_mode a una SD TreeFrogUI (stack en treefrog/ bind-cubegm/).
# Uso: ./deploy_net_mode.sh /mnt/<sd-root>
set -e
MNT="${1:?uso: deploy_net_mode.sh /mnt/sd-root}"
DEST="$MNT/treefrog"
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$DEST/zhijack.sh" ] || { echo "no es una SD TreeFrogUI: falta $DEST/zhijack.sh"; exit 1; }
install -m 0755 "$HERE/net_mode.sh"   "$DEST/net_mode.sh"
install -m 0755 "$HERE/net_rndis.sh"  "$DEST/net_rndis.sh"
install -m 0755 "$HERE/net_wifi.sh"   "$DEST/net_wifi.sh"
cat > "$DEST/usb_mtp.sh" << 'SHIM'
#!/bin/sh
# TreeFrogUI's user-facing USB mode entry point. MTP keeps the SD mounted.
# Net Mode dispatch: con /mnt/sdcard/rndis.mode en la raiz de la SD, entra al
# modo de red (apps/net_mode); sin el flag, el MTP clasico (upstream verbatim).
[ -f /mnt/sdcard/log.txt ] && echo "usb_mtp invoked mode=$( [ -f /mnt/sdcard/rndis.mode ] && echo rndis || echo mtp)" >> /mnt/sdcard/USB_MODE_INVOKE.log 2>/dev/null
if [ -f /mnt/sdcard/rndis.mode ]; then
    exec "$(dirname "$0")/net_mode.sh"
fi
exec "$(dirname "$0")/usb_mode.sh" mtp
SHIM
chmod +x "$DEST/usb_mtp.sh"
echo "net_mode desplegado en $DEST"
