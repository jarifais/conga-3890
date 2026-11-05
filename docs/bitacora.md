# Bitácora técnica — Conga 3890

## 2026-11-05 · Sesión inicial USB (Windows 11)

**Fuentes**: resultados capturados desde PowerShell, consola Tina Linux y análisis estático de los archivos extraídos. Se han omitido deliberadamente identificadores únicos, credenciales y contenidos de mapas.

### Pruebas completadas

1. Windows detectó un dispositivo USB con descripción `Android` y VID/PID `18D1:D002`; `adb devices -l` confirmó estado `device`.
2. `adb shell "uname -a"` falló con `/bin/login: unrecognized option: c`. Causa observada: el shell ADB ejecuta `/bin/login`, incompatible con la opción `-c` que utiliza el modo no interactivo.
3. `adb shell`, en modo interactivo, presentó `TinaLinux login:` y permitió autenticación administrativa. No documentar credenciales en el repositorio.
4. `id` devolvió `uid=0(root)`. `uname -a` identificó kernel `3.4.39`, ARMv7. `/proc/cpuinfo` mostró cuatro núcleos Cortex-A7, plataforma `sun8i`; `/proc/meminfo`, `524288 kB`.
5. `/etc/openwrt_release` identificó `tina.robotix.20200831.194440`, `Neptune`, revisión `57513AA3`, `2.0.0`.
6. Se comprobaron procesos `Monitor`, `RobotApp`, `AuxCtrl` y `everest-server`, activos bajo el supervisor. `Monitor` aparece en el script `/etc/init.d/robotManager`.
7. `netstat -ln` mostró TCP/22 (SSH), TCP/6000, TCP/5037 solo loopback y UDP/8899; sockets UNIX `/tmp/everest_sock`, `/tmp/AuxEverest_Sock` y `/tmp/cliManager.sock`.
8. Se extrajeron cuatro ejecutables desde `/usr/sbin` con `adb pull` y la biblioteca `/usr/lib/libcli.so`. Se calcularon hashes y se analizaron offline. **No se redistribuyen**.
9. La biblioteca `libcli.so` incluye un subsistema CLI con prompt `Robot>`, registro de comandos y socket `/tmp/cliManager.sock`. No hay un comando de batería validado.
10. `adb forward tcp:16690 localfilesystem:/tmp/cliManager.sock` permitió abrir la conexión local, pero se cerró sin entregar bytes. **No prueba el protocolo de la CLI**, ni confirma por sí solo que el extremo remoto aceptara una sesión útil.
11. Prueba de control: `adb forward tcp:16691 tcp:22`; la conexión local devolvió el banner **`SSH-2.0-dropbear_2015.71`**. **Queda confirmada la comunicación de datos a través del túnel USB**.

### Incidencias y lecciones

- Se pegó accidentalmente un script de PowerShell dentro de `ash` (consola de la Conga), provocando errores de sintaxis. Separar siempre `PS C:\...>` (PC) y `root@TinaLinux:~#` (robot).
- Los registros mostraron actividad de `Monitor` y reinicios de servicios después de una ejecución accidental. Se detuvo la acción y se verificó que quedaba **una instancia** de cada servicio principal. El PID de `AuxCtrl` cambió, compatible con un reinicio. No iniciar demonios manualmente.
- Las cadenas sobre batería, IMU, LiDAR y mapas **solo prueban la presencia de código**, no la disponibilidad de telemetría en vivo.

### Estado de los hitos

| Hito | Estado |
| --- | --- |
| ADB USB | Confirmado |
| Consola Tina Linux | Confirmada |
| Verificación del túnel USB TCP | Confirmada (banner SSH) |
| Localización de procesos y sockets | Confirmada |
| Análisis estático inicial de ejecutables y `libcli.so` | Completado |
| Decodificar el protocolo de `cliManager.sock` | Pendiente |
| Lectura real de batería por USB | Pendiente |
| Lectura real de sensores / LiDAR | Pendiente |
| Acceso y control por Wi-Fi | Pospuesto |

### Próximos experimentos (orden de prioridad)

1. Analizar offline las funciones de establecimiento de sesión de la CLI (cliente/servidor) y el motivo posible del cierre; no enviar comandos a ciegas.
2. Buscar comandos de **solo lectura** registrados dinámicamente por `RobotApp`, distinguiendo consola CLI de protocolo de aplicación.
3. Documentar el formato exacto de solicitudes `DEVICE_STATUS_GETTING_REQ` / respuestas `DEVICE_STATUS_GETTING_RSP`, sin probarlas en el robot hasta verificar los efectos.
4. Si existe una consulta inocua validada, ensayar bajo supervisión con el robot detenido y registrar únicamente la telemetría anonimizada.


## 2026-11-05 · Primer diagnóstico de batería por `sysfs`

**Prueba de solo lectura ejecutada realmente en la shell de la Conga**:

- `ls /sys/class/power_supply` devolvió `ac`, `battery` y `usb`.
- `/sys/class/power_supply/battery/capacity` existe y devolvió **`0`**.
- `logread` filtrado por `battery percent actual` y `handleGetBattaryReq battery_percent` no mostró coincidencias.
- La copia de múltiples comandos a la terminal interactiva produjo eco intercalado; las órdenes básicas finalizaron.

**Interpretación:** ese cero todavía **no es una medición verificada** del nivel de la batería principal. Puede ser una interfaz del controlador de alimentación del SoC sin datos útiles para el robot. Tampoco la ausencia de coincidencias en `logread` demuestra que la telemetría no exista.

**Próxima comprobación (sin modificaciones):** consultar `type`, `present`, `status`, `capacity`, `voltage_now`, `current_now` y `charge_now` de `/sys/class/power_supply/battery` para identificar si el indicador responde a hardware real.


### Segunda comprobación de sysfs (misma sesión)

Se consultaron atributos de `/sys/class/power_supply/battery` y el robot respondió:

```text
type: Battery
present: 1
status: Charging
capacity: 0
voltage_now: 0
current_now: 0
```

**Conclusión restringida**: el subsistema de alimentación del kernel informa un objeto `Battery` presente/cargando, pero los ceros simultáneos de capacidad, voltaje y corriente **no permiten interpretar `capacity=0` como batería principal agotada**. No se ha observado una lectura real de porcentaje. Posible driver con valores ficticios, no demostrado.

**Próxima comprobación, solo lectura:** buscar en registros disponibles las cadenas verificadas en el binario `everest-server`: `Get battery percent actual`, `battery_level` y `handleGetBattaryReq battery_percent`, evaluando antigüedad de los registros. Si no hay trazas, reconstruir offline el protocolo real.


### Tercera comprobación: registros del robot y estado físico

En la sesión interactiva Tina Linux se listó `/mnt/UDISK/log` y se buscó `Get battery percent actual|handleGetBattaryReq battery_percent|battery_level` en archivos normales del directorio. **No se obtuvieron coincidencias**; los numerosos archivos `.gz` no se descomprimieron para la búsqueda, así que esto **no demuestra ausencia de telemetría**. El log muestra que el terminal puede entremezclar el eco de comandos pegados a la vez.

**Hipótesis en estudio:** algún controlador del robot podría permanecer en reposo aunque Linux y los servicios principales estén activos. La interfaz `/sys/class/power_supply/battery` ya mostró `present=1`, `Charging`, `capacity=0`, `voltage_now=0` y `current_now=0`, valores sin validación como porcentaje real.

**Próxima prueba segura:** observar si el robot indica luz azul (encendido) o naranja (cargando). Solo si realmente estuviera apagado, seguir el manual Conga 3890 para encenderlo (pulsación mantenida ~3 segundos); evitar pulsaciones cortas que podrían arrancar limpieza. Volver a leer atributos de `sysfs` y, si es posible, comparar con el porcentaje de la app oficial. Si los ceros persisten, pasar a reconstruir un método de consulta en `RobotApp`/`everest-server`; no inyectar órdenes a sensores ni motores.

**Referencia:** https://manualzz.com/doc/73806038/cecotec-conga-3890-instruction-manual


### Cuarta comprobación: batería Linux tras revisar encendido

Se repitió la lectura `present status capacity voltage_now current_now` desde la shell interactiva y el resultado **no cambió**:

```text
present: 1
status: Charging
capacity: 0
voltage_now: 0
current_now: 0
```

**Decisión técnica:** suspender los intentos de medir batería por `/sys/class/power_supply/battery`; el porcentaje `0` no está validado, aun cuando `present=1` y `Charging`. No se ha recibido una lectura real. El siguiente paso es identificar una ruta de consulta de `RobotApp` o sus trazas; no ejecutar comandos de motores, firmware ni sockets no documentados.

**Precedente adicional:** un usuario de 3890 compartió trazas `get_status` de un servidor alternativo con el campo `battary` (ver https://github.com/miguelsg29/clean-assistant/issues/14). Este dato acredita que **existe telemetría en ese protocolo**, pero no permite inferir el nivel actual de nuestra unidad ni confirma escalado a porcentaje sin estudiar el código.
