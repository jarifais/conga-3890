#!/bin/sh
# Conga 3890: diagnóstico de batería de SOLO LECTURA.
# Compatible con BusyBox ash. EXPERIMENTAL: aún no validado con una lectura real.
# No ejecuta comandos de control, no escribe archivos ni cambia el firmware.

printf '%s\n' '=== BATERIA: FUENTES DEL KERNEL ==='
hay_fuentes=0
hay_bateria=0

if [ -d /sys/class/power_supply ]; then
    for fuente in /sys/class/power_supply/*; do
        [ -d "$fuente" ] || continue
        hay_fuentes=1

        nombre=${fuente##*/}
        tipo='no disponible'
        [ ! -r "$fuente/type" ] || tipo=$(cat "$fuente/type" 2>/dev/null)

        printf 'Dispositivo: %s (tipo: %s)\n' "$nombre" "$tipo"

        if [ -r "$fuente/capacity" ]; then
            nivel=$(cat "$fuente/capacity" 2>/dev/null)
            case "$nivel" in
                ''|*[!0-9]*)
                    printf '  capacity: valor no numerico\n'
                    ;;
                *)
                    printf '  capacity: %s%%\n' "$nivel"
                    if [ "$tipo" = 'Battery' ]; then
                        hay_bateria=1
                    fi
                    ;;
            esac
        fi

        if [ -r "$fuente/status" ]; then
            printf '  status: '
            cat "$fuente/status"
        fi
        if [ -r "$fuente/voltage_now" ]; then
            printf '  voltage_now: '
            cat "$fuente/voltage_now"
        fi
    done
fi

[ "$hay_fuentes" -ne 0 ] || printf '%s\n' 'No hay fuentes expuestas en /sys/class/power_supply.'
[ "$hay_bateria" -ne 0 ] || printf '%s\n' 'Todavia no hay un porcentaje de bateria del robot confirmado por sysfs.'

printf '\n%s\n' '=== REGISTROS DE PORCENTAJE (PUEDEN SER ANTIGUOS) ==='
patron='Get battery percent actual|handleGetBattaryReq battery_percent|m_status_data[.]battary'

if command -v logread >/dev/null 2>&1; then
    logread 2>/dev/null | grep -iE "$patron" | tail -n 8
fi

for archivo in /mnt/UDISK/log/everest.temp /mnt/UDISK/log/robotapp.temp; do
    [ -r "$archivo" ] || continue
    printf 'Archivo: %s\n' "$archivo"
    grep -iE "$patron" "$archivo" | tail -n 5
done

printf '\n%s\n' '=== FIN DEL DIAGNOSTICO ==='
