# Conga 3890 - Validar sintaxis de todos los scripts PowerShell del repositorio.
# Analisis estatico mediante Parser oficial de PowerShell; NO ejecuta ningun script.
# Compatible con Windows PowerShell 5.1 y PowerShell 7+.
# Salida no cero ante cualquier fallo. Ejecutar desde Windows PowerShell.

& {
    $ErrorActionPreference = "Stop"
    $repo = Split-Path -Parent $PSScriptRoot
    $scripts = @(Get-ChildItem -LiteralPath (Join-Path $repo "scripts") -File -Filter "*.ps1")
    if ($scripts.Count -eq 0) { throw "No se encontraron archivos .ps1 para validar." }

    $fallos = 0
    foreach ($file in $scripts) {
        $tokens = $null
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile(
            $file.FullName, [ref]$tokens, [ref]$errors
        )
        if ($null -ne $errors -and $errors.Count -gt 0) {
            $fallos++
            Write-Host ("FAIL: {0}" -f $file.Name) -ForegroundColor Red
            foreach ($err in $errors) {
                Write-Host ("  Linea {0}, columna {1}: {2}" -f
                    $err.Extent.StartLineNumber,
                    $err.Extent.StartColumnNumber,
                    $err.Message
                ) -ForegroundColor Red
            }
        }
        else {
            Write-Host ("PASS: {0}" -f $file.Name) -ForegroundColor Green
        }
    }

    if ($fallos) {
        throw ("Sintaxis invalida en {0} de {1} archivos PowerShell." -f
            $fallos, $scripts.Count)
    }
    Write-Host ("PASS: sintaxis correcta de {0} archivos PowerShell." -f
        $scripts.Count) -ForegroundColor Green
}