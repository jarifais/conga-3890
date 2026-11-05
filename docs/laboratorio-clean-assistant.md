# Laboratorio Clean Assistant — fase aislada (Conga 3890)

Preparado el 2026-11-05. **Estado: scripts escritos y publicados; pendiente de ejecución en el Windows del laboratorio.** Ninguna operación de redirección DNS, cambio de firmware o intervención sobre el robot se ha realizado.

## Objetivo

Verificar el servidor de terceros [Clean Assistant](https://github.com/miguelsg29/clean-assistant), su API REST y la conversión de batería **sin conectar la Conga**. De este modo se comprueba la pila de software antes de cualquier prueba real.

**Upstream fijado:** [commit `0cf13b370bbb708c429a64be0270210e8426d0ca`](https://github.com/miguelsg29/clean-assistant/commit/0cf13b370bbb708c429a64be0270210e8426d0ca), versión `0.36.1`, observado el 2026-11-05.

## Arquitectura y compatibilidad

- La Conga 3890 **está declarada compatible por un usuario** en el README de Clean Assistant. La compatibilidad integral del proyecto se ha validado principalmente con la Conga 8090 Ultra. Aún no está demostrada **en nuestra unidad**.
- Para la 3890 corresponde el backend `CONGA_BACKEND=new`, que utiliza **TLS + WebSocket por TCP/9090**. Está respaldado por la conexión saliente observada en `RobotApp`.
- El backend `legacy` es para otros modelos como 3090/3490/4090 y **no debe seleccionarse** por el mero número de modelo.
- Clean Assistant ofrece `GET /api/state`: campos `battery`, `online`, `charging`, `state`. Los porcentajes proceden de `battary` (rango 0–200) dividido entre 2.
- `GET /api/battery` devuelve un **informe de salud de batería**, no el porcentaje actual.
- **En modo mock, la API simula una batería que inicialmente vale 99 y cambia con el tiempo. No utilizar nunca esa lectura para afirmar nada del robot real.**

## Seguridad de esta fase

- Ningún cambio en DNS, IP ni `/etc/hosts` del robot.
- Sin uso de SSH ni ADB, sin movimiento de motores.
- Sin puertos de los servicios del robot publicados: únicamente el panel de pruebas en **`127.0.0.1:18000`**, inaccesible desde otros equipos.
- El código de un tercero se descarga en una carpeta local y sus dependencias se instalan **solo en un entorno virtual**.
- No se usan los `docker-compose.yml` de upstream para el modo mock porque publican innecesariamente puertos de control de robot.

## Requisitos previos en Windows 11

`git --version` debe funcionar y `py -3 --version` debe devolver Python **3.10 o superior**. Se requiere conexión a Internet para descargar la versión fijada y paquetes Python. No es necesario Docker.

Los scripts de Windows siguen el contrato de bloques `& { ... }`.

## Ejecución en Windows PowerShell

### 1. Clonar herramientas propias (solo si no existen)

~~~powershell
& {
    $ErrorActionPreference = "Stop"
    $tools = Join-Path $env:USERPROFILE "Conga3890-TOOLS"
    if (-not (Test-Path -LiteralPath $tools)) {
        & git clone "https://github.com/jarifais/conga-3890.git" $tools
        if ($LASTEXITCODE -ne 0) { throw "Fallo al descargar herramientas." }
    }
    else {
        Write-Host "Ya existe $tools; no se sobrescribe ni actualiza."
    }
    Write-Host "Herramientas: $tools"
}
~~~

### 2. Preparar entorno Python y probar la conversión de batería

~~~powershell
& {
    $script = Join-Path $env:USERPROFILE "Conga3890-TOOLS\scripts\preparar-clean-assistant-mock.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script
}
~~~

El cambio de política de ejecución se aplica **solo al proceso secundario**. No modifica la configuración persistente de Windows. La preparación verifica el commit upstream, carga `MockRobot` y prueba la conversión con **datos sintéticos**: `battary=200 → 100 %`, `battary=150 → 75 %`.

### 3. Iniciar servidor simulado

En una ventana de Windows PowerShell:

~~~powershell
& {
    $script = Join-Path $env:USERPROFILE "Conga3890-TOOLS\scripts\ejecutar-clean-assistant-mock.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script
}
~~~

Mantener la ventana abierta. Visitar <http://127.0.0.1:18000>. **Todo lo mostrado es simulado.** Detener pulsando `Ctrl+C`.

### 4. Comprobar API en una segunda ventana

~~~powershell
& {
    $script = Join-Path $env:USERPROFILE "Conga3890-TOOLS\scripts\verificar-clean-assistant-mock.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script
}
~~~

La prueba primero verifica `/api/info` y **rechaza cualquier servidor no mock**. Luego muestra la batería simulada de `/api/state`. El resultado correcto aquí **no significa haber leído la Conga real**.

## Fase siguiente (NO ejecutar aún)

Para un ensayo real, pendiente de pruebas en Windows:

1. Planificar dónde correrá Clean Assistant continuamente (servidor Linux / Home Assistant / máquina de laboratorio) y comprobar disponibilidad de puertos `9090`, `8001`, `8002`, `8006` para robot y `8000` para panel. Configurar certificados y LAN, sin habilitar todavía servicios externos.
2. Configurar `CONGA_MODE=real` y `CONGA_BACKEND=new` en una instalación independiente del simulador. **No reutilizar** datos, credenciales ni mapas de otro laboratorio.
3. Revisar el despliegue: el `docker-compose.yml` de upstream publica `9090` y puertos `legacy`, pero **no expone por defecto `8001`, `8002` y `8006`**, necesarios según su README para suplantar OTA/historial. Habrá que preparar un compose corregido o usar instalación nativa con cortafuegos.
4. **Solo cuando el servidor esté verificado**, valorar redirecciones DNS **limitadas al robot** de `tcp-cecotec.3irobotix.net`, `cecotec-ota.3irobotix.net`, `eu-ota.3irobotix.net`, `web-eu.3irobotix.net` y `web-cecotec.3irobotix.net`. Documentar un plan de reversión antes de modificar DNS o reiniciar.
5. Conectar la 3890, observar `/api/info` (modo `real`) y `/api/state` (`online=true`, batería 0–100), contrastar porcentaje con otro indicador válido del robot.
6. **Cepillo lateral**: Clean Assistant no documenta una orden separada de encendido/apagado del motor; no suponer que sus funciones de limpieza permiten controlar exclusivamente el cepillo. Investigar por separado, sin activación hasta verificar parada y límites.

## Estado del proyecto

- Conexión USB ADB y SSH Wi-Fi: verificados en nuestro robot.
- Flujo MRPT de mapas por TCP/6000: verificado.
- Conexión saliente de `RobotApp` a TCP/9090: verificada.
- Preparación de software mock: **lista para ejecutar**, aún no probada en el equipo del usuario.
- Servidor real Clean Assistant conectado a la Conga: **pendiente**.
- Lectura real de porcentaje y prueba de cepillo individual: **pendientes**.
