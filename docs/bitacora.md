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


## 2026-11-05 · Identificado propietario de TCP/6000

Prueba en `root@TinaLinux:~#`:

- En `/proc/net/tcp` se buscó el puerto `0x1770` = **6000** en estado `0A` (LISTEN); apareció el **inodo 897**.
- El enlace de descriptor `socket:[897]` fue localizado bajo el proceso `everest-server`, **PID 553**.

**Confirmado:** `everest-server` era el proceso que escuchaba en TCP/6000 en ese instante. **No confirmado:** que ese puerto exponga una consulta de batería.

### Precaución tras reexaminar el binario offline

`everest-server` contiene símbolos `CEntityTcp::tcpServerThread`, `tcpReceiveThread`, `tcpSendThread`, `sendSensorData`, `handleTCPMessage`, `setRemoteVelocity` y `autoCleanTest`. También aparecen textos **`EM_DEBUG_SIMULATE_BATTERY`**, **`EI_MANUAL_CONTROL_MODE`**, órdenes de limpieza y calibración. Por tanto, el interfaz TCP podría manejar **acciones activas**; no enviar ninguna trama o comando de prueba sin descifrar el protocolo.

**Experimento propuesto** (todavía no ejecutado en este momento): abrir un túnel ADB a TCP/6000 y leer durante ~2,5 segundos sin enviar datos de aplicación, para comprobar si `everest-server` emite información espontánea. Archivo: [`scripts/sondeo-pasivo-tcp6000.ps1`](../scripts/sondeo-pasivo-tcp6000.ps1). La mera conexión puede modificar el estado de sesión del servicio: realizarla con el robot detenido y cerrar después. **Un paquete recibido no sería, sin decodificación, una medición validada de batería.**

## 2026-11-05 · Flujo pasivo en TCP/6000 y transición a Wi-Fi

**Experimento realizado por el usuario:** `adb forward tcp:16692 tcp:6000`, conexión local de solo lectura, sin transmitir órdenes. Se recibieron **256 bytes** en la primera lectura. Inicio hexadecimal: `4D-52-50-54-4D-65-73-73-61-67-65-65`; entre las cadenas ASCII aparecieron `MRPTMessage` y `COccupancyGridMap2D`, una clase MRPT de mapa de ocupación. Se trata **probablemente** de una trama de mapa, no de un porcentaje de batería. El conjunto completo no se almacenó ni publicó para proteger datos del domicilio.

**Nueva prioridad solicitada:** identificar la IPv4 de `wlan0` y verificar conexión Wi-Fi desde Windows sin depender del túnel USB. Luego investigar la consulta real de batería y el control **individual** del cepillo lateral delantero.

**Estado del control de motores:** en `everest-server` existen símbolos `CEntityHwdriver::setSideBrushPwm` y `CControllerInterface::setBrushSpeed`, pero **todavía no se ha reconstruido ni validado ninguna petición de red que active y detenga exclusivamente ese cepillo**. No usar llamadas directas ni tramas desconocidas.

### Próximo protocolo de prueba

1. En consola Linux interactiva: `ifconfig wlan0` y `route -n` (solo lectura). Registrar **solo IPv4 privada y alcance**, no MAC/SSID.
2. Desde **Windows PowerShell** en la misma red: ejecutar [`scripts/verificar-wifi.ps1`](../scripts/verificar-wifi.ps1), que lee el banner SSH por el puerto 22 sin autenticarse ni enviar órdenes. Esta prueba puede fallar si la Conga está en modo punto de acceso, en otra red o la LAN aísla dispositivos.
3. Si funciona, estudiar un cliente SSH sobre LAN para diagnóstico y el mecanismo real de `get_status` / `handleGetBattaryReq`. **No interpretar** valores `battary` de protocolos de terceros como porcentajes sin conocer su escala.
4. Para el cepillo, identificar semántica de las órdenes ON/OFF, interbloqueos y parada de emergencia antes de mover el actuador.


## 2026-11-05 · Wi-Fi local: SSH confirmado

El usuario comprobó desde Windows PowerShell, **sin túnel ADB**, una conexión directa a la IPv4 asignada a su Conga en la LAN, puerto TCP/22. Respuesta observada:

```text
Respuesta: SSH-2.0-dropbear_2015.71
CONEXION WIFI VERIFICADA
```

**Confirmado:** el equipo que respondió es un servicio SSH Dropbear accesible por la LAN y coincide en versión con el servicio previamente alcanzado por USB. **Todavía no se ha verificado una sesión SSH autenticada** ni una consulta real de batería por Wi-Fi.

**Privacidad:** la dirección IP concreta se conserva en la sesión de laboratorio, no se incorpora a la documentación pública. En el siguiente paso se comprobará el acceso interactivo por SSH con verificación normal de clave de host. No incrustar la contraseña en scripts o URI.

**Cepillo lateral delantero:** objetivo pendiente. Aún no hay una orden de inicio/parada individual verificada. No enviar comandos arbitrarios a motores; investigar primero el protocolo y las condiciones de parada.

**Nota sobre el flujo TCP/6000:** el encabezado recibido contenía `MRPTMessage` y `COccupancyGridMap2D`, indicativos de un mapa de ocupación, no de la batería. No publicar capturas completas de tramas de mapa.
