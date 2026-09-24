#!/bin/bash
# Despliega la app net_mode a una SD TreeFrogUI.
set -e
MNT="${1:?uso: deploy_net_mode.sh /mnt/sd-root}"
DEST="$MNT/treefrog"
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$DEST/zhijack.sh" ] || { echo "no es una SD TreeFrogUI"; exit 1; }
install -m 0755 "$HERE/net_mode.sh"   "$DEST/net_mode.sh"
install -m 0755 "$HERE/net_ncm.sh"   "$DEST/net_ncm.sh"
install -m 0755 "$HERE/net_rndis.sh" "$DEST/net_rndis.sh"
install -m 0755 "$HERE/net_wifi.sh"  "$DEST/net_wifi.sh"
cat > "$DEST/usb_mtp.sh" << 'SHIM'
#!/bin/sh
# TreeFrogUI USB Mode entry. Flag net.mode en la raiz SD -> modo red (apps/net_mode);
# sin flag -> MTP clasico (upstream verbatim). Dentro de net_mode: rndis.mode selecciona
# RNDIS como transport (fallback); default = NCM (Windows 7+ nativo).
[ -f /mnt/sdcard/log.txt ] && echo "usb_mtp mode=$( [ -f /mnt/sdcard/net.mode ] && echo net || echo mtp)" >> /mnt/sdcard/USB_MODE_INVOKE.log 2>/dev/null
if [ -f /mnt/sdcard/net.mode ]; then
    exec "$(dirname "$0")/net_mode.sh"
fi
exec "$(dirname "$0")/usb_mode.sh" mtp
SHIM
chmod +x "$DEST/usb_mtp.sh"
echo "net_mode desplegado en $DEST"
