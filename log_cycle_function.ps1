# Function to log Crypto.com connection cycles
function Log-CryptoCycle {
    param(
        [string]$BotName = "Bot 1 - Cripto",
        [string]$CycleType = "DOWNLOAD",
        [int]$AssetCount = 0,
        [string]$Status = "Successo",
        [string]$Notes = ""
    )
    
    $logPath = "C:\Users\Pc\OneDrive\Bot\1 - Bot Cripto\bin\Release\net8.0\Logs\log_cicli.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    
    $logEntry = @"
[$timestamp] [$CycleType] Ciclo completato - $BotName
   - Timestamp ciclo: $timestamp
   - Tipo ciclo: $CycleType
   - Asset scaricati: $AssetCount
   - Status: $Status
   - Note: $Notes
   
"@
    
    Add-Content -Path $logPath -Value $logEntry -Encoding UTF8
    
    Write-Host "✓ Ciclo registrato nel log"
    return $logEntry
}

# Esporta la funzione
Export-ModuleMember -Function Log-CryptoCycle
