# Conga 3890 - diagnostico previo a preparar Clean Assistant REAL en Windows.
# SOLO LECTURA: no crea archivos, no instala paquetes, no cambia DNS ni cortafuegos,
# no abre sockets, no reinicia ni interroga la Conga. No requiere permisos admin.
# Ejecutar en WINDOWS PowerShell, no en la shell SSH del robot.

& {
    $ErrorActionPreference = "Stop"

    $base = Join-Path $env:USERPROFILE "Conga3890-LAB"
    $src = Join-Path $base "clean-assistant"
    $python = Join-Path $base ".venv\Scripts\python.exe"
    $commit = "0cf13b370bbb708c429a64be0270210e8426d0ca"
    $puertos = @(9090, 8001, 8002, 8006, 8000)
    $problemas = [System.Collections.Generic.List[string]]::new()

    Write-Host "=== PREFLIGHT CLEAN ASSISTANT REAL (SOLO LECTURA) ===" -ForegroundColor Cyan

    if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
        $problemas.Add("Falta Python del laboratorio: $python")
    }
    else {
        & $python --version
        if ($LASTEXITCODE -ne 0) { $problemas.Add("Python virtual no responde") }
    }

    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($null -eq $git -or -not (Test-Path -LiteralPath (Join-Path $src ".git"))) {
        $problemas.Add("No se encuentra el repositorio upstream local")
    }
    else {
        $actual = (& git -C $src rev-parse HEAD).Trim()
        if ($LASTEXITCODE -ne 0 -or $actual -ne $commit) {
            $problemas.Add("El hash upstream difiere de la version fijada")
        }
        else {
            Write-Host "PASS: codigo upstream fijado y verificado" -ForegroundColor Green
        }
    }

    # El puerto 8000 se incluye porque es el HTTP de produccion.
    # El simulador utiliza 18000 y puede seguir en marcha.
    Write-Host "`n=== PUERTOS DE ESCUCHA QUE NECESITARA EL SERVIDOR ==="
    $listeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue)
    foreach ($port in $puertos) {
        $ocupados = @($listeners | Where-Object { $_.LocalPort -eq $port })
        if ($ocupados.Count) {
            $procesos = ($ocupados | Select-Object -ExpandProperty OwningProcess -Unique) -join ", "
            Write-Host ("OCUPADO TCP/{0} (PID: {1})" -f $port, $procesos) -ForegroundColor Yellow
            $problemas.Add("TCP/$port ocupado: revisar conflicto antes de arrancar servidor real")
        }
        else {
            Write-Host ("LIBRE TCP/{0} (en este instante)" -f $port) -ForegroundColor Green
        }
    }

    Write-Host "`n=== OPENSSL PARA CERTIFICADOS TLS ==="
    $openssl = Get-Command openssl.exe -ErrorAction SilentlyContinue
    $opensslPath = if ($null -ne $openssl) { $openssl.Source } else { $null }

    if (-not $opensslPath -and $null -ne $git -and $git.Source) {
        $gitRoot = Split-Path -Parent (Split-Path -Parent $git.Source)
        $alternativas = @(
            (Join-Path $gitRoot "usr\bin\openssl.exe"),
            (Join-Path $gitRoot "mingw64\bin\openssl.exe")
        )
        foreach ($candidate in $alternativas) {
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $opensslPath = $candidate
                break
            }
        }
    }

    if ($opensslPath) {
        & $opensslPath version
        if ($LASTEXITCODE -eq 0) {
            Write-Host "PASS: OpenSSL localizado en $opensslPath" -ForegroundColor Green
            if (-not $openssl) {
                Write-Host "AVISO: no esta en PATH; el arranque real debe agregar su carpeta al PATH del proceso." -ForegroundColor Yellow
            }
        }
        else { $problemas.Add("OpenSSL no se pudo ejecutar") }
    }
    else {
        $problemas.Add("OpenSSL no encontrado: Clean Assistant lo requiere para generar TLS")
    }

    Write-Host "`n=== INTERFACES IPV4 LOCALES (SOLO INFORMACION) ==="
    $ips = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -ne "127.0.0.1" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.AddressState -eq "Preferred"
        })
    if ($ips.Count -eq 0) {
        $problemas.Add("No se identifico una IPv4 local util para el servidor")
    }
    else {
        $ips | ForEach-Object {
            Write-Host ("Interfaz: {0}; IP: {1}" -f $_.InterfaceAlias, $_.IPAddress)
        }
    }

    Write-Host "`n=== RIESGO DE CONFIGURACION AUTOMATICA ==="
    Write-Host "AVISO: Upstream v0.36.1 envia comandos OTA off y frecuencia de vaciado" -ForegroundColor Yellow
    Write-Host "al conectar por primera vez, si faltan marcas de inicializacion."
    Write-Host "Antes de conectar la Conga real se preparara un directorio real SEPARADO"
    Write-Host "y una marca firstrun.json con done=true para NO alterar esos ajustes."
    Write-Host "NO se hara ninguna redireccion DNS en esta fase."

    Write-Host "`n=== RESUMEN ==="
    if ($problemas.Count -eq 0) {
        Write-Host "PASS: requisitos principales presentes. AUN NO se ha conectado ningun robot." -ForegroundColor Green
    }
    else {
        foreach ($p in $problemas) {
            Write-Warning $p
        }
        Write-Host "PREPARACION REAL BLOQUEADA HASTA RESOLVER LOS AVISOS." -ForegroundColor Yellow
    }
    Write-Host "RESULTADO: SOLO PRECHECK. BATERIA REAL NO CONSULTADA."
