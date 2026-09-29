# 0006 — SOLO con el avp-own

La traduccion ABI (632/664 -> 608/644) es para el avp-own (prebuilts
Jul-2024 del SDK). Con el AVP GOLDEN de fabrica (que espera 632/664) es
INCOMPATIBLE y rompe el init de audio/video (regla del addendum F1c+F2).
Este directorio NO entra en el sync de build_kernel.sh (solo se aplica
manualmente al pairing avp-own, ver el experiment doc F1).
