# Conga 3890 - Mostrar el porcentaje REAL de bateria usando Clean Assistant.
# REQUISITO: Clean Assistant en modo REAL conectado a la Conga.
# La direccion que solicita es la del SERVIDOR Clean Assistant, no la IP del robot.
# Solo hace GET /api/state: no controla motores, no modifica firmware.
# No utilizar con modo demo/mock: su bateria es simulada.

& {
    $ErrorActionPreference = "Stop"

    $ipServidor = (Read-Host "IPv4 del servidor Clean Assistant (NO de la Conga)").Trim()
    $direccion = $null
    if (-not [System.Net.IPAddress]::TryParse($ipServidor, [ref]$direccion) -or
        $direccion.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        throw "Introduce una IPv4 valida del servidor."
    }

    $puerto = 8000
    $url = "http://" + $ipServidor + ":" + $puerto + "/api/state"

    Write-Host "=== CONSULTA DE ESTADO (Clean Assistant) ===" -ForegroundColor Cyan

    try {
        $estado = Invoke-RestMethod -Method Get -Uri $url -TimeoutSec 5
    }
    catch {
        throw "No se ha podido consultar Clean Assistant en $url. Comprueba que el servidor esta instalado, en modo real y accesible."
    }

    # No mostrar valores de mock/demo o estado antiguo como lecturas actuales.
    if ($estado.online -ne $true) {
        Write-Warning "El servidor no indica que el robot este conectado. No se muestra porcentaje."
        return
    }

    if ($null -eq $estado.battery) {
        Write-Warning "La respuesta no contiene un porcentaje de bateria validado."
        return
    }

    $valor = 0
    if (-not [int]::TryParse([string]$estado.battery, [ref]$valor) -or
        $valor -lt 0 -or $valor -gt 100) {
        Write-Warning "Valor de bateria fuera del rango 0..100. No se interpreta."
        return
    }

    Write-Host ("Bateria: {0} %" -f $valor) -ForegroundColor Green
    Write-Host ("Cargando: {0}" -f [bool]$estado.charging)
    Write-Host ("Estado: {0}" -f [string]$estado.state)
}
