# Conga 3890 - verificar la API SIMULADA en localhost:18000.
# El campo /api/info.mode indica tipo de enlace (local/cloud), NO CONGA_MODE.
# Se inspecciona la huella sintetica conocida del MockRobot.
# No es prueba de bateria real ni de conexion con la Conga.

& {
    $ErrorActionPreference = "Stop"
    $base = "http://127.0.0.1:18000"

    $info = Invoke-RestMethod -Method Get -Uri ($base + "/api/info") -TimeoutSec 5
    $estado = Invoke-RestMethod -Method Get -Uri ($base + "/api/state") -TimeoutSec 5

    if ($info.backend -ne "new") {
        throw "Backend inesperado ($($info.backend)); se esperaba 'new'."
    }

    # Huella determinista de MockRobot en la version 0.36.1 fijada.
    # No usar online=true ni battery=99 como prueba: ambos pueden existir en un robot real.
    # La bateria simulada cambia con el tiempo, pero el mapa y consumibles iniciales no.
    $mapaCorrecto = ([string]$estado.map_name -ceq "Interior") -and
                    ([string]$estado.map_head_id -eq "1700000000")
    $consumiblesCorrectos = ($null -ne $estado.consumables) -and
                            ([string]$estado.consumables.main_brush -eq "74") -and
                            ([string]$estado.consumables.side_brush -eq "68") -and
                            ([string]$estado.consumables.filter -eq "22") -and
                            ([string]$estado.consumables.dishcloth -eq "81")

    if (-not ($mapaCorrecto -and $consumiblesCorrectos)) {
        throw "La respuesta no coincide con MockRobot v0.36.1. No se interpreta como simulacion."
    }

    Write-Host "PASS: API de Clean Assistant accesible." -ForegroundColor Green
    Write-Host "PASS: huella del robot simulado MockRobot v0.36.1." -ForegroundColor Green
    Write-Host ("Enlace de servidor: {0} (NO indica CONGA_MODE)" -f $info.mode)
    Write-Host "SOLO SIMULACION. NO ES LA BATERIA DE LA CONGA REAL." -ForegroundColor Yellow
    Write-Host ("Bateria simulada: {0} %" -f $estado.battery)
    Write-Host ("Estado simulado: {0}" -f $estado.state)
    Write-Host ("Cargando (simulado): {0}" -f $estado.charging)
}