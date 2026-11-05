# Conga 3890 - prueba de la API simulada.
# Ejecutar en OTRA consola de Windows PowerShell con el servidor mock funcionando.

& {
    $ErrorActionPreference = "Stop"
    $base = "http://127.0.0.1:18000"
    $info = Invoke-RestMethod -Method Get -Uri ($base + "/api/info") -TimeoutSec 5

    if ($info.mode -ne "mock") {
        throw "El servidor no es simulado (mode=$($info.mode)). Abortado."
    }

    $estado = Invoke-RestMethod -Method Get -Uri ($base + "/api/state") -TimeoutSec 5

    Write-Host "PASS: API de Clean Assistant accesible." -ForegroundColor Green
    Write-Host "SOLO SIMULACION. NO ES LA BATERIA DE LA CONGA REAL." -ForegroundColor Yellow
    Write-Host ("Bateria simulada: {0} %" -f $estado.battery)
    Write-Host ("Estado simulado: {0}" -f $estado.state)
    Write-Host ("Cargando (simulado): {0}" -f $estado.charging)
}