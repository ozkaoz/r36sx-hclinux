#!/bin/sh
# diag_stick.sh (Fase 7b) — Detectar canal ADC del stick derecho.
# Ejecutar en FrogShell: sh /mnt/sdcard/diag_stick.sh
# Mueve el stick derecho mientras corre el script.
echo "=== DIAG STICK — mueve el stick derecho 15 segundos ==="
echo "leyendo canales ADC e input cada 1s durante 15 iteraciones"
echo

i=0
while [ $i -lt 15 ]; do
    echo "--- t=${i}s ---"
    for adc in /dev/queryadc0 /dev/queryadc1 /dev/queryadc5 /dev/check_adc0 /dev/check_adc1 /dev/check_adc2 /dev/check_adc3 /dev/check_adc4 /dev/check_adc5; do
        if [ -e "$adc" ]; then
            val=$(cat "$adc" 2>/dev/null)
            echo "  $adc = $val"
        fi
    done
    echo "  input events: $(ls /dev/input/ 2>/dev/null | head -5)"
    echo "  joy_key shm: $(ls -la /tmp/joy_key 2>/dev/null)"
    sleep 1
    i=$((i+1))
done
echo
echo "=== RESULTADO: ¿qué canales cambiaron de valor al mover el stick? ==="
echo "Si queryadc0 o check_adc0/2/3/4 cambiaron, ese canal es el stick."
echo "=== FIN DIAG STICK ==="
