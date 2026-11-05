#!/bin/sh
# Conga 3890. Identificar de forma pasiva el proceso que mantiene una
# conexion TCP saliente ESTABLISHED al puerto remoto 9090.
# Ejecutar en la shell Linux del robot. Solo lee /proc, no envia trafico.

echo "=== PROCESO CONECTADO AL PUERTO REMOTO 9090 ==="
inodos=$(awk '$3 ~ /:2382$/ && $4 == "01" {print $10}' /proc/net/tcp)

if [ -z "$inodos" ]; then
    echo "No hay conexiones TCP ESTABLISHED hacia 9090 en este instante."
else
    for inodo in $inodos; do
        echo "Inodo del socket: $inodo"
        encontrado=0
        for p in /proc/[0-9]*; do
            [ -d "$p/fd" ] || continue
            if ls -l "$p/fd" 2>/dev/null | grep -F "socket:[$inodo]" >/dev/null; then
                encontrado=1
                pid=${p#/proc/}
                printf 'PID: %s  Ejecutable: ' "$pid"
                readlink "$p/exe" 2>/dev/null
            fi
        done
        [ "$encontrado" -eq 1 ] || echo "No se pudo asociar el inodo a un proceso (puede haber cerrado la conexion)."
    done
fi

echo "=== FIN ==="
