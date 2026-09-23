# TreeFrogUI Net Mode: network connection management for R36SX

A TreeFrogUI app that manages network connectivity on the console,
following the same structure as `apps/usb_mode/`. It provides
alternative network transports, selected by mode flags on the SD root.

## Transports

| Flag on SD root | Transport | Status |
|---|---|---|
| `rndis.mode` | USB RNDIS networking — PC link + remote shell | Implemented (kernel 5.12.4 port) |
| (future) `wifi.mode` | WiFi client | Pending (requires kernel module support) |

## How it works today (FrogUI USB Mode integration)

FrogUI's USB MODE screen launches `usb_mtp.sh` (the stack's entry point).
`usb_mtp.sh` dispatches:

```text
usb_mtp.sh
  ├── /mnt/sdcard/rndis.mode exists -> net_mode.sh -> net_rndis.sh
  └── otherwise                     -> usb_mode.sh mtp   (classic MTP, unchanged)
```

The MTP path stays byte-identical to the upstream flow: no regression
surface. RNDIS activates only when the user opts in by dropping an
empty `rndis.mode` file on the SD root (from the PC, over MTP itself).

## USB RNDIS mode (net_rndis.sh)

- Creates a **single-function gadget** (`rndis.usb0`, 3 endpoints —
  fits the MUSB controller's 4-EP budget; a combined MTP+RNDIS gadget
  needs 5 EPs and corrupts memory, see the platform notes).
- Classic CDC device class `0x02/0x02/0xFF` + VID:PID `0525:a4a2`
  so Windows auto-installs the RNDIS driver (`usb8023.sys`).
- Console: `usb0` at `192.168.137.2/24`, `telnetd -l /bin/sh`.
- PC side: set the new adapter to `192.168.137.1/24`, then
  `telnet 192.168.137.2` gets a root shell on the console.
- Blocking like `usb_mode.sh run`: unplugging the cable restores the
  gadget teardown, USB role, and kills `telnetd`.

## Future: FrogUI menu entry

The core could gain a "NETWORK" menu item calling `net_mode.sh`
directly (same wiring as USB MODE -> `usb_mtp.sh`), rendering the
transport selection UI and status (IP address, telnet hint). The
dispatch design above keeps that migration trivial: `net_mode.sh`
becomes the first-class entry and `usb_mtp.sh` returns to upstream
verbatim.

## Platform notes (r36sx-hclinux specifics)

- Kernel: all gadget functions are BUILT-IN (the on-device module
  loader is unreliable on this port; see the r36sx-hclinux docs on
  the configfs order fix and the `resolve_symbol` OOPS).
- `usb_f_rndis` registers its configfs function type at boot; the
  gadget is created at session time via configfs.
- Requires `S90configfs` (configfs mountpoint) on the initramfs —
  already part of the platform overlay.

## Files

- `net_mode.sh` — app entry point (transport dispatch)
- `net_rndis.sh` — USB RNDIS runtime
- `net_wifi.sh` — placeholder for the WiFi transport (pending)
- `deploy_net_mode.sh` — SD deployment helper
