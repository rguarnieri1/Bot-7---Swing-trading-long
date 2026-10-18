# Auto-log each bot cycle every 15 minutes with success/ko status
$logPath = "C:\Users\Pc\OneDrive\Bot\1 - Bot Cripto\bin\Release\net8.0\Logs\log_cicli.log"
$signalsDir = "C:\Users\Pc\OneDrive\Bot\1 - Bot Cripto\bin\Release\net8.0\Logs"

try {
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"

  # Check bot process - REQUIRED for success
  $proc = Get-Process -Id 2356 -ErrorAction SilentlyContinue
  if (-not $proc) {
    $proc = Get-Process | Where-Object {$_.ProcessName -match "Bot|Cripto"} | Select-Object -First 1
  }

  # Verify log file exists
  if (-not (Test-Path $logPath)) {
    throw "Log file not found: $logPath"
  }

  # Verify signals directory exists
  if (-not (Test-Path $signalsDir)) {
    throw "Signals directory not found: $signalsDir"
  }

  $memory = if ($proc) { [math]::Round($proc.WorkingSet/1MB, 2) } else { "N/A" }
  $procStatus = if ($proc) { "Attivo" } else { "Inattivo" }

  # Check for signals
  $signalFiles = Get-ChildItem -Path $signalsDir -Filter "signals_*.log" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
  $latestSignal = if ($signalFiles) { $signalFiles[0] } else { $null }

  if ($latestSignal) {
    $lastSignalTime = $latestSignal.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    $signalStatus = "Si (ultima: $lastSignalTime)"
  } else {
    $signalStatus = "No"
  }

  # Determine cycle status - success only if all checks pass
  if ($proc -and (Test-Path $logPath) -and (Test-Path $signalsDir)) {
    $cycleStatus = "success"
    $resultSymbol = "OK"
  } else {
    $cycleStatus = "ko"
    $resultSymbol = "ERROR"
  }

  $logEntry = @"
[$timestamp] [CYCLE] Ciclo automatico eseguito - STATUS: $cycleStatus
   - Tipo: AUTOMATIC - Ciclo ogni 15 minuti
   - Bot: Bot 1 - Cripto
   - PID: $(if ($proc) { $proc.Id } else { "N/A" })
   - Memoria: $memory MB
   - Processo Status: $procStatus
   - Segnali nel file: $signalStatus
   - Crypto monitorate: 25 (BTC, ETH, SOL, XRP, ADA, ecc.)
   - File Log: $(if (Test-Path $logPath) { "OK" } else { "ERROR" })
   - Dir Signals: $(if (Test-Path $signalsDir) { "OK" } else { "ERROR" })
   - Risultato: [$cycleStatus] $resultSymbol

"@

  Add-Content -Path $logPath -Value $logEntry -Encoding UTF8
  Write-Host "[$timestamp] [$cycleStatus] Ciclo registrato"

} catch {
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
  $errorMsg = $_.Exception.Message

  $errorEntry = @"
[$timestamp] [CYCLE] Ciclo automatico - STATUS: ko
   - Tipo: AUTOMATIC - Ciclo ogni 15 minuti
   - Bot: Bot 1 - Cripto
   - Errore: $errorMsg
   - Risultato: [ko] ERROR

"@

  try {
    Add-Content -Path $logPath -Value $errorEntry -Encoding UTF8
  } catch {}

  Write-Host "[$timestamp] [ko] Errore nel ciclo: $errorMsg"
}
