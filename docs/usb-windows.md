# USB desde Windows 11

## Requisitos

- Robot Conga 3890 encendido y sin limpieza activa.
- Cable USB **de datos** y Android SDK Platform-Tools (`adb`) disponibles en el PC.
- No es necesario utilizar Wi-Fi para estas pruebas.

## 1. Detectar el dispositivo

Ejecutar en **Windows PowerShell**, identificado por un prompt similar a `PS C:\Users\...>`:

```powershell
& {
    $ErrorActionPreference = "Stop"
    $adb = (Get-Command adb -ErrorAction Stop).Source
    & $adb devices -l
}
```

Resultado esperado: un dispositivo en estado `device`. Su número de serie puede variar; no publicarlo.

## 2. Abrir shell interactiva

En el mismo PowerShell:

```powershell
& {
    $ErrorActionPreference = "Stop"
    $adb = (Get-Command adb -ErrorAction Stop).Source
    & $adb -d shell
}
```

El robot puede mostrar `TinaLinux login:`. Autenticarse manualmente con credenciales propias; **no registrarlas** en scripts ni repositorios. Si aparece `root@TinaLinux:~#`, se está ejecutando **Linux dentro de la Conga**, no PowerShell. Salir escribiendo `exit`.

> En este firmware, `adb shell "comando"` no funciona: `/bin/login` rechaza la opción `-c`. Utilizar shell interactiva para las consultas Linux.

Consultas únicamente informativas dentro de Linux: `id`, `uname -a`, `ps -ef`, `netstat -ln`.

## 3. Prueba de datos bidireccionales en el túnel USB

El equipo examinado tiene un servidor SSH Dropbear en TCP/22. La prueba **no autentica** ni ejecuta comandos SSH: solo lee la primera línea del saludo.

Ejecutar en **Windows PowerShell**:

```powershell
& {
    $ErrorActionPreference = "Stop"
    $adb = (Get-Command adb -ErrorAction Stop).Source
    $puerto = 16691
    $cliente = $null
    $tunelCreado = $false

    try {
        & $adb -d forward --no-rebind "tcp:$puerto" "tcp:22"
        if ($LASTEXITCODE -ne 0) {
            throw "No se pudo crear el tunel USB."
        }
        $tunelCreado = $true

        $cliente = [System.Net.Sockets.TcpClient]::new()
        $resultado = $cliente.BeginConnect("127.0.0.1", $puerto, $null, $null)
        try {
            if (-not $resultado.AsyncWaitHandle.WaitOne(3000)) {
                throw "Tiempo de conexion agotado."
            }
            $cliente.EndConnect($resultado)
        }
        finally {
            $resultado.AsyncWaitHandle.Dispose()
        }

        $flujo = $cliente.GetStream()
        $flujo.ReadTimeout = 3000
        $lector = [System.IO.StreamReader]::new(
            $flujo, [System.Text.Encoding]::ASCII
        )
        $saludo = $lector.ReadLine()

        if ($saludo -match '^SSH-2\.0-') {
            Write-Host "Tunel USB verificado: $saludo" -ForegroundColor Green
        }
        else {
            Write-Warning "Sin banner SSH reconocible."
        }
    }
    finally {
        if ($cliente) { $cliente.Dispose() }
        if ($tunelCreado) {
            & $adb -d forward --remove "tcp:$puerto" | Out-Null
        }
    }
}
```

**Observación real de laboratorio:** `SSH-2.0-dropbear_2015.71`, por tanto la conexión bidireccional vía USB funciona.

## 4. CLI interna

`/tmp/cliManager.sock` es un socket UNIX observado. Una conexión sin transmitir datos a través de `adb forward` se cerró inmediatamente. **No enviar comandos exploratorios** ni suponer que el túnel garantiza un protocolo de aplicación válido. Se necesita comprender antes su negociación.

## 5. Evitar

- Ejecutar código PowerShell en la shell Linux.
- Iniciar manualmente `Monitor`, `RobotApp`, `AuxCtrl` o `everest-server`.
- Escribir sobre `/dev/ttyS*`, sockets internos o archivos de configuración.
- Publicar capturas de contraseñas, números de serie, identificadores del robot, Wi-Fi, mapas o registros completos.
