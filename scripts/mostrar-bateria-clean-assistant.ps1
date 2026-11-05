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

    # ATENCION: GET /api/info.mode significa ENLACE (local/cloud), no CONGA_MODE.
    # Esta API no anuncia el modo runtime "real/mock". Hay que confirmar en la
    # configuracion y logs del servidor que CONGA_MODE=real y que existe LOGIN real.
    $infoUrl = "http://" + $ipServidor + ":" + $puerto + "/api/info"
    try {
        $info = Invoke-RestMethod -Method Get -Uri $infoUrl -TimeoutSec 5
    }
    catch { throw "No se pudo consultar /api/info del servidor Clean Assistant." }
    if ($info.backend -ne "new") {
        throw "Backend inesperado ($($info.backend)). Para nuestra Conga 3890 debe ser 'new'."
    }

    try {
        $estado = Invoke-RestMethod -Method Get -Uri $url -TimeoutSec 5
    }
    catch {
        throw "No se ha podido consultar Clean Assistant en $url. Comprueba que el servidor esta instalado, en modo real y accesible."
    }

    # Rechazar la huella publica del MockRobot de la version fijada.
    # No basta con "online=true", porque el simulador tambien esta online.
    if (([string]$estado.map_name -ceq "Interior") -and
        ([string]$estado.map_head_id -eq "1700000000") -and
        ([string]$estado.consumables.main_brush -eq "74")) {
        throw "ABORTADO: la respuesta coincide con MockRobot. Bateria simulada."
    }

    Write-Warning "/api/info.mode=$($info.mode) indica enlace, no certifica modo real."
    Write-Warning "Verifica antes de continuar que el servidor tiene CONGA_MODE=real y que sus logs muestran LOGIN de TU Conga."
    $confirmacion = (Read-Host "Escribe CONEXION_REAL_VERIFICADA si has comprobado ambos hechos").Trim()
    if ($confirmacion -cne "CONEXION_REAL_VERIFICADA") {
        throw "No se ha confirmado que el servidor este conectado al robot fisico."
    }

    # Validar el porcentaje comunicado por Clean Assistant, sin asumir actualidad
    # mas alla de su campo online; la frescura depende de los informes de robot.
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
