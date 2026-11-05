# Conga 3890 - preparar laboratorio LOCAL y SIMULADO de Clean Assistant
# NO redirige DNS, NO toca el robot ni abre puertos en la LAN.
# Requisitos: Git para Windows, Python >=3.10 (comando py -3) e Internet para dependencias.
# Version del upstream fijada a commit publico del 2026-11-05.

& {
    $ErrorActionPreference = "Stop"
    $commit = "0cf13b370bbb708c429a64be0270210e8426d0ca"
    $url = "https://github.com/miguelsg29/clean-assistant.git"
    $base = Join-Path $env:USERPROFILE "Conga3890-LAB"
    $src = Join-Path $base "clean-assistant"
    $venv = Join-Path $base ".venv"
    $python = Join-Path $venv "Scripts\python.exe"
    $envFile = Join-Path $src ".env"

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Falta Git para Windows."
    }
    if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
        throw "Falta Python (comando py)."
    }

    & py -3 -c "import sys; print(sys.version); sys.exit(0 if sys.version_info >= (3,10) else 1)"
    if ($LASTEXITCODE -ne 0) { throw "Se necesita Python 3.10 o superior." }

    New-Item -ItemType Directory -Path $base -Force | Out-Null

    if (-not (Test-Path -LiteralPath $src)) {
        Write-Host "Descargando version fijada de Clean Assistant..." -ForegroundColor Cyan
        & git init -q $src
        if ($LASTEXITCODE -ne 0) { throw "Error inicializando el repositorio local." }
        & git -C $src remote add origin $url
        if ($LASTEXITCODE -ne 0) { throw "Error configurando el origen." }
    }
    elseif (-not (Test-Path -LiteralPath (Join-Path $src ".git"))) {
        throw "Existe la carpeta de trabajo, pero no es un repositorio Git. No se modificara."
    }

    $dirty = & git -C $src status --porcelain
    if ($LASTEXITCODE -ne 0) { throw "No se puede comprobar el estado de Git." }
    if ($dirty) { throw "Existen cambios locales en Clean Assistant. No se sobrescribiran." }

    $head = & git -C $src rev-parse --verify HEAD 2>$null
    if ($head -ne $commit) {
        & git -C $src fetch --no-tags --depth 1 origin $commit
        if ($LASTEXITCODE -ne 0) { throw "No se pudo descargar el commit fijado." }
        & git -C $src -c advice.detachedHead=false checkout --detach -q FETCH_HEAD
        if ($LASTEXITCODE -ne 0) { throw "No se pudo seleccionar el commit fijado." }
    }

    $head = (& git -C $src rev-parse HEAD).Trim()
    if ($head -ne $commit) { throw "Version upstream no verificada: $head" }
    Write-Host "Version verificada: $head" -ForegroundColor Green

    # El modo mock se fija expresamente. No se copian identidades ni credenciales.
    if (-not (Test-Path -LiteralPath $envFile)) {
        [System.IO.File]::WriteAllText(
            $envFile,
            "CONGA_MODE=mock`nCONGA_BACKEND=new`nMQTT_HOST=`n",
            [System.Text.UTF8Encoding]::new($false)
        )
    }
    else {
        $existing = Get-Content -LiteralPath $envFile -Raw
        if ($existing -notmatch '(?m)^\s*CONGA_MODE=mock\s*$') {
            throw "El archivo .env existente no es mock. No se modificara."
        }
    }

    if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
        Write-Host "Creando entorno virtual independiente..." -ForegroundColor Cyan
        & py -3 -m venv $venv
        if ($LASTEXITCODE -ne 0) { throw "Error creando entorno Python." }
    }

    Write-Host "Instalando dependencias solo en el entorno virtual..." -ForegroundColor Cyan
    & $python -m pip install --disable-pip-version-check -r (Join-Path $src "requirements.txt")
    if ($LASTEXITCODE -ne 0) { throw "Error instalando las dependencias." }

    $env:CONGA_MODE = "mock"
    $env:CONGA_BACKEND = "new"
    $env:MQTT_HOST = ""
    $env:DATA_DIR = Join-Path $base "data-mock"
    New-Item -ItemType Directory -Path $env:DATA_DIR -Force | Out-Null

    Push-Location $src
    try {
        Write-Host "Verificando importacion y modo seguro..." -ForegroundColor Cyan
        & $python -c "from backend.app import MODE, robot; assert MODE == 'mock', MODE; assert type(robot).__name__ == 'MockRobot'; print('PASS: MockRobot confirmado, sin robot fisico')"
        if ($LASTEXITCODE -ne 0) { throw "Fallo la verificacion del modo mock." }
        & $python -c "from conga_core.state import RobotState; a=RobotState().update_from_report({'battary':200, 'chargeStatus':1}); b=RobotState().update_from_report({'battary':150, 'chargeStatus':0}); assert a.battery==100 and b.battery==75; print('PASS: conversion 0-200 a porcentaje validada con datos sinteticos')"
        if ($LASTEXITCODE -ne 0) { throw "Fallo la prueba sintética de conversion de bateria." }
    }
    finally { Pop-Location }

    Write-Host "=== LABORATORIO PREPARADO ===" -ForegroundColor Green
    Write-Host "Ruta: $src"
    Write-Host "NO se ha accedido a la Conga ni cambiado el DNS."
}