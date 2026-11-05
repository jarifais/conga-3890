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


### 2026-11-05 · Intento SSH autenticado por Wi-Fi: clave de host heredada

Con TCP/22 ya verificado por LAN, el primer intento de `ssh root@<ip-local>` desde Windows falló **antes de pedir credenciales**:

```text
Unable to negotiate ... no matching host key type found. Their offer: ssh-rsa
```

**Diagnóstico:** Dropbear 2015.71 ofrece el algoritmo de firma de host `ssh-rsa` (RSA/SHA-1), deshabilitado por defecto por las versiones modernas de OpenSSH. **No es un error de red ni contraseña.**

**Mitigación puntual solo para la IP del robot, sin cambiar configuraciones ni firmware:**

```powershell
& {
    $ip = "<IPv4-local-de-la-Conga>"
    & ssh -o HostKeyAlgorithms=+ssh-rsa -o ConnectTimeout=5 "root@$ip"
}
```

**Advertencia:** `ssh-rsa` usa SHA-1; mantener su uso limitado a laboratorio y validar la huella de la clave de host por un canal independiente (USB) antes de aceptar la primera conexión. Este ajuste habilita **la clave del servidor**, no necesariamente autenticación por clave RSA del usuario (que no se ha utilizado).

**Estado:** conexión SSH autenticada pendiente de resultado. Referencia: https://www.openssh.org/legacy.html


### 2026-11-05 · Segundo obstáculo SSH: MAC heredado

Después de habilitar `HostKeyAlgorithms=+ssh-rsa` **solo en la conexión**, el cliente OpenSSH de Windows avanzó en la negociación, pero devolvió:

```text
Unable to negotiate ... no matching MAC found. Their offer: hmac-sha1,hmac-md5
```

**Diagnóstico:** el servidor Dropbear 2015.71 anuncia algoritmos de autenticación de mensajes (MAC) heredados; este cliente OpenSSH los tiene deshabilitados de forma predeterminada.

**Ajuste puntual propuesto** (pendiente de resultado), sin modificaciones globales:

```powershell
& {
    $ip = "<IPv4-local-de-la-Conga>"
    & ssh -o HostKeyAlgorithms=+ssh-rsa -o MACs=+hmac-sha1 -o ConnectTimeout=5 "root@$ip"
}
```

La adición utiliza SHA-1 para los algoritmos indicados, con las limitaciones criptográficas correspondientes. **No** desactivar la verificación de clave del servidor ni aceptar una huella desconocida sin compararla por USB. Tras conseguir la sesión SSH, comprobar la lectura real de batería; **ningún control de motor está validado**.


### 2026-11-05 · Negociación SSH por Wi-Fi llega a verificación de identidad

Después de limitar por conexión `HostKeyAlgorithms=+ssh-rsa` y `MACs=+hmac-sha1`, el cliente OpenSSH de Windows alcanzó el aviso de primera conexión: `The authenticity of host ... can't be established` y presentó una huella **RSA SHA256** del host. La huella concreta y la IP local no se publican en este repositorio. **Todavía no se ha aceptado ni validado independientemente la clave** ni se ha autenticado la sesión. El siguiente paso es comparar la huella del mismo servicio SSH a través del túnel USB `adb forward tcp:<puerto-local> tcp:22`; solo si coincide se autorizará la aceptación por Wi-Fi. Mantener los algoritmos SSH heredados limitados a conexiones expresas con la Conga.


### 2026-11-05 · Identidad SSH confirmada por dos canales independientes

El usuario obtuvo una huella de clave de host **RSA SHA256 idéntica** por conexión directa Wi-Fi y mediante túnel USB `adb forward tcp:16693 tcp:22` usando OpenSSH con opciones puntuales `HostKeyAlgorithms=+ssh-rsa` y `MACs=+hmac-sha1`. **Se confirma que los dos accesos presentan la misma clave SSH**. Por prudencia, no se publica en el repositorio la huella completa ni la IP privada del dispositivo.

Siguiente paso: responder `no` a la conexión de prueba por USB; volver a conectar por Wi-Fi y aceptar la clave verificada. **La autenticación SSH por Wi-Fi aún no ha sido constatada**. No hay nueva telemetría de batería ni comando de cepillo validado.


### 2026-11-05 · Sesión SSH por Wi-Fi autenticada

El usuario confirmó que **ya está dentro de la Conga por SSH**, después de aceptar la huella del servidor previamente verificada mediante USB y autenticarse como administrador. Por tanto, la administración interactiva por LAN funciona; no depende del túnel USB.

**Siguiente prueba propuesta, todavía sin resultado:** buscar trazas de batería, carga y voltaje en `logread` y archivos `/mnt/UDISK/log/*.temp`, mediante búsquedas de solo lectura. El objetivo inmediato sigue siendo **mostrar un porcentaje real**, no el `capacity=0` no validado del kernel. El ensayo del cepillo lateral se pospone hasta verificar el protocolo de encendido/parada.


### 2026-11-05 · Sin coincidencias de batería en `logread` por SSH

Desde una sesión SSH por Wi-Fi autenticada, el usuario ejecutó `logread | grep -iE 'battery|battary|charge|voltage|percent' | tail -n 20`. **No devolvió ninguna línea**. Esto significa únicamente que el búfer de `logread` no contiene coincidencias con esos términos en el momento de la comprobación; no implica que los sensores no estén activos. Próximo paso: comprobar los archivos de registro propios de `RobotApp` y `everest-server` y, si tampoco hay datos, abandonar la vía de registros y reconstruir la consulta de estado mediante análisis estático de los ejecutables ya obtenidos. No afirmar porcentaje sin lectura validada.


### 2026-11-05 · Búsqueda en tres ficheros `*.temp` sin resultados

La instrucción condicional `for f in ...; do if [ -r "$f" ]; then echo "=== $f ==="; grep ...; fi; done` acabó sin imprimir ningún encabezado `=== fichero ===`. **Interpretación correcta:** ninguno de los tres archivos especificados era legible en esas rutas durante el experimento (puede que no existieran). **No** se ha demostrado una búsqueda negativa en su contenido. No se seguirá insistiendo en esos registros.

Hay evidencia externa específica de Conga 3890 de respuestas `get_status` con los campos `battary` y `chargeStatus`, pero se trata de un protocolo de aplicación/nube, no de valores de `sysfs`. Referencia: https://github.com/miguelsg29/clean-assistant/issues/14 . No inferir porcentaje para la unidad actual.

**Experimento siguiente propuesto:** `scripts/inspeccionar-stream-tcp6000-wifi.ps1`. Lee, sin emitir comandos, como máximo 4 MiB en ~6 segundos de TCP/6000 por Wi-Fi; solo informa la aparición de una lista fija de marcadores técnicos (`CObservationBattery`, `COccupancyGridMap2D`, `MRPTMessage`, etc.). Descarta el contenido leído y no publica mapas. Este experimento aún no ha sido ejecutado por el usuario y **no garantiza obtener batería**. Si la transmisión solo contiene mapas, investigar `get_status` mediante un cliente de protocolo comprobado, no enviar tramas arbitrarias.


### 2026-11-05 · Muestreo pasivo completo de TCP/6000 por Wi-Fi

**Prueba realizada:** lectura de hasta 4 MiB durante aproximadamente seis segundos por TCP/6000, sin transmitir órdenes, desde el PC por Wi-Fi. Resultado:

~~~text
Bytes examinados: 644486
MRPTMessage
COccupancyGridMap2D
~~~

**Hechos:** el servidor entregó 644.486 bytes y los únicos marcadores reconocidos por el buscador fueron los de MRPT y `COccupancyGridMap2D`. El flujo puede incluir datos binarios adicionales no reconocibles por búsqueda de texto, pero **no proporcionó una lectura de porcentaje de batería identificable**. No se conservaron datos del mapa.

**Corrección metodológica:** no volver a sondear TCP/6000 a la espera de que aparezcan espontáneamente datos de batería: por ahora demuestra transmisión de mapas, no la API `get_status`.

### Pista concreta confirmada en implementación de tercero

Se inspeccionaron `conga_core/state.py` y `backend/app.py` del proyecto **Clean Assistant** (fuentes externas):

- `RobotState.update_from_report(data)` lee `data["battary"]` y asigna `battery = int(battary / 2)` (escala nativa 0..200 a porcentaje 0..100).
- Hay trazas públicas de una **Conga 3890** donde `get_status` incluye `battary: 200`; equivale a 100% **en ese equipo, no en el nuestro**.
- El porcentaje expuesto por Clean Assistant está en **`GET /api/state`**, campo `battery` con `online`, `charging`, `state`.
- **`GET /api/battery` NO da el porcentaje actual**: devuelve la analítica de salud (ciclos/consumo/velocidad de carga). No confundir los dos endpoints.
- El puerto HTTP típico del servicio independiente Clean Assistant es 8000; **esa API no existe actualmente en el robot ni en TCP/6000**.
- Clean Assistant soporta la 3890 según un usuario (issue 14), pero redirigir el robot al servicio requiere preparación de servidor y DNS y potencialmente reinicio; todavía no se ha hecho en nuestro laboratorio.

Fuentes:
- https://github.com/miguelsg29/clean-assistant/blob/main/conga_core/state.py
- https://github.com/miguelsg29/clean-assistant/blob/main/backend/app.py
- https://github.com/miguelsg29/clean-assistant/issues/14
- https://github.com/miguelsg29/clean-assistant

**Artefacto preparado**: `scripts/mostrar-bateria-clean-assistant.ps1`, PowerShell de solo lectura para cuando un servidor real de Clean Assistant esté conectado; no es ejecutable útil en nuestro entorno actual hasta instalar y configurar ese servicio. La alternativa es reconstruir nuestra propia consulta de estado de `RobotApp` (trabajo de protocolo pendiente).

**Cepillo lateral:** todavía no existe control individual y parada validado. Se mantiene bloqueado cualquier ensayo activo.


## 2026-11-05 · Conexión saliente real de control (puerto 9090)

Desde SSH Wi-Fi el usuario leyó (sin cambiar configuración):

- En **ambas** rutas, `/etc/sysconf/sysConfig.ini` y `/mnt/UDISK/config/sysConfig.ini`: `server_cmd_address=cecotec-ota.3irobotix.net`, `server_ota_address=cecotec-ota.3irobotix.net`, `server_ssl_cmd_port=8001`, `server_ssl_enable=1` y `server_cmd_port=4010`.
- `netstat -tn` mostró dos conexiones `ESTABLISHED`: una sesión SSH de administración en TCP/22 desde el PC y **una conexión saliente del robot a un servidor externo TCP/9090**. No publicamos IPs de la sesión para evitar vincular la unidad con el entorno privado.

**Interpretación:** los valores en archivos de configuración no implican que 4010/8001 sean los canales en uso para toda comunicación: en vivo vemos TCP/9090. La IP externa por sí sola no identifica con certeza el proveedor.

**Evidencia externa relevante y más específica**: la ingeniería inversa de la app de Conga 3890 descrita en Clean Assistant caracteriza esta generación como **híbrida**: control vía WebSocket/JSON y mapas por JNI/TLS; la generación más nueva utiliza WebSocket en 9090. Fuente: https://github.com/miguelsg29/clean-assistant/issues/12 (comentario de investigación del 27 de octubre de 2026). Nuestro `RobotApp` extraído incorpora además símbolos `CManagerWebsocket`, lo que respalda esa línea de investigación. **Pendiente:** comprobar que la conexión observada de 9090 corresponde realmente a `RobotApp` y confirmar la negociación/protocolo.

**Siguiente comprobación, pasiva y sin tocar firmware:** [`scripts/identificar-cliente-9090.sh`](../scripts/identificar-cliente-9090.sh) consulta `/proc/net/tcp` para localizar los inodos de conexiones `ESTABLISHED` al puerto remoto 9090 y relaciona sus descriptores con el PID/ejecutable de Linux. El usuario aún no ha ejecutado esta prueba.

**Batería:** no se ha obtenido todavía un porcentaje real. Una vez identificada la sesión, estudiar offline el formato de consulta `get_status` y el campo `battary` (escala 0..200) antes de evaluar un método no destructivo. La conexión TCP remota cifrada no debe interceptarse ni redirigirse a ciegas. Cepillo lateral individual: ninguna orden de arranque/parada validada; no moverlo por conjetura.


### 2026-11-05 · Propietario del socket remoto TCP/9090 confirmado

La búsqueda de la conexión `ESTABLISHED` al puerto remoto TCP/9090 en `/proc/net/tcp` devolvió **inodo 4211**. La inspección de descriptores Linux mostró:

~~~text
Inodo: 4211
PID: 483
/usr/sbin/RobotApp
~~~

**Confirmado:** el proceso `RobotApp`, PID 483, mantiene la conexión saliente al servidor de control en TCP/9090. Se trata de una **conexión saliente**, no de un puerto 9090 abierto en la IP local del robot. Por sí solo este dato no confirma la semántica de las tramas ni garantiza que la carga útil sea legible (podría utilizar TLS/WSS).

**Análisis offline adicional:** el binario `RobotApp` contiene los métodos `get_status`, `get_status_Handler_Callbak`, `CManagerWebsocket::handleGetStatusReq`, las cadenas `battary`, `battery_percent`, y `CManagerWebsocket::sendMsgToServer`. Estas son evidencias de la ruta lógica de consulta, no una interfaz local directamente invocable.

**Estrategia:** no dirigir peticiones arbitrarias a TCP/6000 (flujo MRPT de mapas) ni a la sesión saliente cifrada. Para obtener una respuesta `get_status` funcional se necesita **o bien** reconstruir y validar el protocolo de petición de estado, **o bien** montar un backend local compatible como Clean Assistant (proyecto que reporta soporte para 3890) y configurar que el robot se conecte allí. Esta segunda vía supone cambios DNS/red y posiblemente reinicio, no es una prueba de solo lectura ni un cambio trivial.

**Objetivos pendientes:** mostrar porcentaje real de batería en consola y, después, estudiar inicio/parada segura del cepillo lateral. No existe todavía ninguna orden individual de cepillo validada.


## 2026-11-05 · Clean Assistant: preparación aislada, sin cambios en la Conga

A petición del usuario, se revisó el README y código upstream de Clean Assistant y se preparó una fase de pruebas **simuladas**. **Esto NO es todavía una lectura de batería ni una comprobación funcional de la 3890 real.**

**Fuente fijada:** commit `0cf13b370bbb708c429a64be0270210e8426d0ca` (v0.36.1), 2026-11-05.
- `CONGA_MODE=mock` carga `MockRobot`; `CONGA_BACKEND=new` corresponde a la familia 3890 en Clean Assistant.
- `GET /api/state` contiene el porcentaje; `GET /api/battery` devuelve métricas de salud, no el porcentaje.
- En `conga_core/state.py`: `battary` se convierte a `int(battary / 2)`.
- El modo simulado empieza con `battery=99`, lo cual **no debe confundirse** con un valor real.
- La instalación mock escucha solo en `127.0.0.1:18000`, sin redirección DNS ni puertos públicos de control.

**Archivos añadidos:**
- [Guía](laboratorio-clean-assistant.md).
- [Preparación entorno y pruebas offline](../scripts/preparar-clean-assistant-mock.ps1).
- [Servidor mock local](../scripts/ejecutar-clean-assistant-mock.ps1).
- [Verificador de API mock](../scripts/verificar-clean-assistant-mock.ps1).

**Corrección:** `scripts/mostrar-bateria-clean-assistant.ps1` ahora verifica `GET /api/info`, exige `mode=real` y aborta ante `mock` para no informar batería ficticia como real.

**Evaluación crítica:** el Compose upstream publica 9090 y puertos legacy, pero omite el mapeo de 8001/8002/8006, requeridos para OTA/historial en modo real según su README. **No usar tal cual para migrar nuestra 3890.**

**Ejecución real en Windows:** pendiente; no se dispone aquí del entorno Windows del usuario para confirmar instalación y funcionamiento. Antes de cualquier cambio DNS o reinicio debe pasar el test mock. Después se preparará, de forma separada y reversible, la integración real.


## 2026-11-05 · Incidencia real al preparar Clean Assistant en Windows

**Entorno del usuario:** Windows PowerShell clásico y Python `3.14.3`, `git clone` del repositorio `jarifais/conga-3890` completado correctamente. Primer intento de `scripts/preparar-clean-assistant-mock.ps1`:

~~~text
Descargando version fijada de Clean Assistant...
git.exe : fatal: Needed a single revision
... rev-parse --verify HEAD 2>$null
La preparacion del laboratorio ha fallado.
~~~

**Causa raíz:** tras `git init` de un repositorio vacío, `HEAD` no apunta todavía a ningún commit. `git rev-parse --verify HEAD 2>$null` emite error de Git por stderr, que PowerShell 5.1 con `$ErrorActionPreference="Stop"` convierte en excepción terminante.

**Corrección aplicada:** `git rev-parse --verify --quiet HEAD` seguido de tratamiento explícito de `$LASTEXITCODE`: si el repositorio aún no tiene `HEAD` válido, `$head = $null` y se pasa a `git fetch` del commit fijado. `--quiet` suprime el mensaje de error en repositorios sin commits. Cambio: https://github.com/jarifais/conga-3890/commit/9fa70479b274fb2ed8a06c30019489aeb9470d61

**Recuperación sin borrar carpetas:** desde PowerShell ejecutar `git -C "$env:USERPROFILE\\Conga3890-TOOLS" pull --ff-only` y volver a lanzar `scripts/preparar-clean-assistant-mock.ps1`. Antes de reintentar, no hacer `git reset --hard`, `git clean` ni eliminar `Conga3890-LAB`. Se conservan la carpeta de herramientas y el repositorio upstream parcialmente creado.

**Estado:** corrección publicada; segunda ejecución y compatibilidad efectiva de dependencias con Python 3.14 **pendientes de comprobar por el usuario**. No se ha conectado el robot al simulador ni se ha leído su batería real.


## 2026-11-05 17:35 (Europe/Madrid) · Primer éxito del laboratorio Clean Assistant mock en Windows

El usuario ejecutó la versión corregida de `preparar-clean-assistant-mock.ps1` tras `git pull --ff-only`. **Resultado confirmado por salida completa: PASS.**

- Python: `3.14.3` en Windows 11; las dependencias Python se instalaron satisfactoriamente en el entorno virtual privado.
- Código upstream: `0cf13b370bbb708c429a64be0270210e8426d0ca` (Clean Assistant v0.36.1), hash Git verificado.
- `PASS: MockRobot confirmado, sin robot fisico`.
- `PASS: conversion 0-200 a porcentaje validada con datos sinteticos`.
- `=== LABORATORIO PREPARADO ===` y `=== PREPARACION COMPLETADA ===`.
- Ubicación local: `%USERPROFILE%\\Conga3890-LAB\\clean-assistant` (sin datos de identidad del robot publicados).

El mensaje de importación `[firstrun] instalación nueva: se aplicarán OTA off + vaciado tras cada limpieza` pertenece a **preferencias iniciales de Clean Assistant mock** y **no significa que se haya enviado comando alguno a la Conga**, pues `MockRobot` se confirmó por aserción.

**Pendientes inmediatos:** arrancar servidor mock limitado a `127.0.0.1:18000`; comprobar que `/api/info` informa `mode=mock` y `/api/state` presenta un estado simulado. **Sin** configurar servidor real, DNS, firmware ni cepillo hasta superar la prueba. La lectura de batería física sigue pendiente.
