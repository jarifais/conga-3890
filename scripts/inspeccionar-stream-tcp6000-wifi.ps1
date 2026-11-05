# Conga 3890 - Inspeccion pasiva de clases transmitidas por TCP/6000 (Wi-Fi).
# No transmite comandos, no guarda mapas, no modifica el robot.
# Ejecutar en Windows PowerShell (NO en root@TinaLinux).
# Se limita a 4 MiB y a ~6 s de recepcion.

& {
    $ErrorActionPreference = "Stop"
    $ip = "192.168.18.141"
    $port = 6000
    $maxBytes = 4MB
    $client = $null
    $markers = @(
        "MRPTMessage",
        "COccupancyGridMap2D",
        "CObservationBattery",
        "CObservation2DRangeScan",
        "CObservationIMU",
        "DeviceStatus",
        "battery_percent",
        "battary",
        "battery"
    )
    $found = @{}
    $total = 0
    $tail = ""
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $client = [System.Net.Sockets.TcpClient]::new()
        $connecting = $client.BeginConnect($ip, $port, $null, $null)
        try {
            if (-not $connecting.AsyncWaitHandle.WaitOne(3000)) {
                throw "TCP/6000 no responde por Wi-Fi."
            }
            $client.EndConnect($connecting)
        }
        finally {
            $connecting.AsyncWaitHandle.Dispose()
        }

        Write-Host "TCP/6000 conectado. Modo de solo lectura." -ForegroundColor Green
        $stream = $client.GetStream()
        $stream.ReadTimeout = 1200
        $buffer = New-Object byte[] 32768

        while ($total -lt $maxBytes -and $sw.Elapsed.TotalSeconds -lt 6) {
            try {
                $limit = [Math]::Min($buffer.Length, $maxBytes - $total)
                $n = $stream.Read($buffer, 0, [int]$limit)
                if ($n -le 0) { break }
                $total += $n
                $chunk = $tail + [System.Text.Encoding]::ASCII.GetString($buffer, 0, $n)
                foreach ($marker in $markers) {
                    if ($chunk.Contains($marker)) {
                        $found[$marker] = $true
                    }
                }
                $tail = $chunk.Substring([Math]::Max(0, $chunk.Length - 96))
            }
            catch [System.IO.IOException] {
                break
            }
        }

        Write-Host "Bytes inspeccionados (solo memoria): $total"
        Write-Host "Marcadores reconocidos:"
        $matches = @($markers | Where-Object { $found.ContainsKey($_) })
        if ($matches.Count -eq 0) {
            Write-Host "Ninguno entre los previstos."
        }
        else {
            $matches | ForEach-Object { Write-Host "  $_" }
        }
        Write-Host "No se ha interpretado ni extraido ningun porcentaje."
    }
    finally {
        $sw.Stop()
        if ($client) { $client.Dispose() }
        Write-Host "Conexion cerrada."
    }
}
