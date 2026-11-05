# Conga 3890 - Clean Assistant SIMULADO en 127.0.0.1:18000.
# No publica el servicio en LAN. NO son datos reales.
# Ejecutar desde Windows PowerShell. Detener con Ctrl+C.

& {
    $ErrorActionPreference = "Stop"
    $base = Join-Path $env:USERPROFILE "Conga3890-LAB"
    $src = Join-Path $base "clean-assistant"
    $python = Join-Path $base ".venv\Scripts\python.exe"

    if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
        throw "Antes ejecuta preparar-clean-assistant-mock.ps1."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $src "backend\app.py") -PathType Leaf)) {
        throw "Falta el codigo del proyecto upstream."
    }

    $env:DATA_DIR = Join-Path $base "data-mock"
    $env:CONGA_MODE = "mock"
    $env:CONGA_BACKEND = "new"
    $env:MQTT_HOST = ""
    New-Item -ItemType Directory -Path $env:DATA_DIR -Force | Out-Null

    Write-Host "MODO MOCK: bateria y mapa SIMULADOS." -ForegroundColor Yellow
    Write-Host "Web: http://127.0.0.1:18000" -ForegroundColor Cyan
    Write-Host "Detener: Ctrl+C."

    Push-Location $src
    try {
        & $python -m uvicorn backend.app:app --host 127.0.0.1 --port 18000
        if ($LASTEXITCODE -ne 0) { throw "Error al iniciar el servidor." }
    }
    finally { Pop-Location }
}