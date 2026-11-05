# Conga 3890 — comprobar acceso Wi-Fi directo por SSH (sin autenticarse).
# Prueba pasiva. No se envia ningun comando ni se cambia el firmware.
# Ejecutar en Windows PowerShell, NO en la consola de Tina Linux.

& {
    $ErrorActionPreference = "Stop"

    $ip = (Read-Host "Introduce la IPv4 de wlan0 de la Conga").Trim()
    $direccion = $null

    if (-not [System.Net.IPAddress]::TryParse($ip, [ref] $direccion) -or
        $direccion.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        throw "La direccion debe ser una IPv4 valida."
    }

    $octetos = $direccion.GetAddressBytes()
    $privada = ($octetos[0] -eq 10) -or
               ($octetos[0] -eq 172 -and $octetos[1] -ge 16 -and $octetos[1] -le 31) -or
               ($octetos[0] -eq 192 -and $octetos[1] -eq 168)

    if (-not $privada) {
        throw "Por seguridad esta prueba solo acepta direcciones privadas de la red local."
    }

    $cliente = $null
    try {
        Write-Host "=== CONEXION DIRECTA Wi-Fi / TCP 22 ===" -ForegroundColor Cyan
        $cliente = [System.Net.Sockets.TcpClient]::new()
        $conexion = $cliente.BeginConnect($ip, 22, $null, $null)
        try {
            if (-not $conexion.AsyncWaitHandle.WaitOne(3000)) {
                throw "Sin respuesta por Wi-Fi (timeout 3 segundos)."
            }
            $cliente.EndConnect($conexion)
        }
        finally {
            $conexion.AsyncWaitHandle.Dispose()
        }

        Write-Host "Conexion TCP establecida por la LAN." -ForegroundColor Green
        $flujo = $cliente.GetStream()
        $flujo.ReadTimeout = 3000
        $bytes = New-Object byte[] 256
        try {
            $n = $flujo.Read($bytes, 0, $bytes.Length)
            if ($n -eq 0) {
                Write-Host "El servidor cerro sin enviar saludo."
            }
            else {
                $linea = [System.Text.Encoding]::ASCII.GetString($bytes, 0, $n).Split([char]10)[0].Trim()
                Write-Host "Saludo: $linea"
                if ($linea -like "SSH-*") {
                    Write-Host "RESULTADO: SSH del robot accesible directamente por Wi-Fi." -ForegroundColor Green
                }
                else {
                    Write-Warning "No se identifica un saludo SSH."
                }
            }
        }
        catch [System.IO.IOException] {
            Write-Warning "Conectado, pero no se recibio el saludo SSH a tiempo."
        }
    }
    finally {
        if ($cliente) { $cliente.Dispose() }
        Write-Host "=== CONEXION CERRADA ==="
    }
}
