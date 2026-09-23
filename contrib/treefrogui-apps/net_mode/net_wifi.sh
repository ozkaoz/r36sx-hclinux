#!/bin/sh
# TreeFrogUI Net Mode — WiFi transport (PLACEHOLDER).
# Pending: kernel module support on the r36sx platform (module loader fix or
# built-in wifi drivers). This stub documents the future interface:
#   scan -> list APs (FrogUI renders the picker)
#   connect <ssid> <psk> -> wpa_supplicant + udhcpc
#   status -> IP + link quality for the UI
echo "WiFi transport not yet available on this platform" >&2
exit 1
