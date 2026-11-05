# Experimento pasivo por USB: prueba de lectura de TCP/6000 de everest-server.
# Esta prueba NO ENVIA DATOS DE APLICACION al robot.
# Aviso: abrir una sesion TCP puede cambiar el estado de conexion del demonio.
# Ejecutar solo con el robot detenido, preferiblemente en la base, desde Windows PowerShell.
# No pegar este script en la consola Linux root@TinaLinux.
# Requiere un unico dispositivo ADB conectado por USB.

& {
    $ErrorActionPreference = "Stop"
    $adb = (Get-Command adb -ErrorAction Stop).Source
    $puertoLocal = 16692
    $cliente = $null
    $tunelCreado = $false

    try {
        Write-Host "=== TUNEL USB A TCP/6000 ===" -ForegroundColor Cyan
        & $adb -d forward --no-rebind "tcp:$puertoLocal" "tcp:6000"
        if ($LASTEXITCODE -ne 0) {
            throw "No se pudo crear el tunel USB."
        }
        $tunelCreado = $true

        $cliente = [System.Net.Sockets.TcpClient]::new()
        $resultado = $cliente.BeginConnect(
            "127.0.0.1", $puertoLocal, $null, $null
        )
        try {
            if (-not $resultado.AsyncWaitHandle.WaitOne(3000)) {
                throw "Tiempo de conexion agotado."
            }
            $cliente.EndConnect($resultado)
        }
        finally {
            $resultado.AsyncWaitHandle.Dispose()
        }

        Write-Host "Conexion local establecida." -ForegroundColor Green
        Write-Host "NO SE ENVIARAN COMANDOS."

        $flujo = $cliente.GetStream()
        $flujo.ReadTimeout = 2500
        $bytes = New-Object byte[] 256

        try {
            $n = $flujo.Read($bytes, 0, $bytes.Length)
            if ($n -eq 0) {
                Write-Host "El servidor cerro la conexion sin enviar datos."
            }
            else {
                $muestra = [Math]::Min($n, 64)
                Write-Host "Bytes recibidos: $n"
                Write-Host "Primeros $muestra bytes (hexadecimal):"
                Write-Host ([BitConverter]::ToString($bytes, 0, $muestra))
                Write-Host "No interpretar estos bytes como porcentaje de bateria."
            }
        }
        catch [System.IO.IOException] {
            Write-Host "Sin datos espontaneos dentro del tiempo de lectura."
        }
    }
    finally {
        if ($cliente) {
            $cliente.Dispose()
        }
        if ($tunelCreado) {
            & $adb -d forward --remove "tcp:$puertoLocal" | Out-Null
        }
        Write-Host "=== TUNEL CERRADO ==="
    }
}
