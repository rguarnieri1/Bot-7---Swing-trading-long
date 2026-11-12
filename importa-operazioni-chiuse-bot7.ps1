# Importa nel database "bot" le operazioni chiuse del Bot 7 gia presenti su file:
#   Logs\Operazioni_chiuse.log -> bot7.bot7_operazioni_chiuse
# Il log riporta i valori arrotondati: quando l'operazione esiste in bot7.bot7_trades (stesso ID) vengono
# usati i valori esatti del trade, altrimenti quelli del log.
# Si puo rieseguire: le righe gia presenti (stesso ID e stesso orario di chiusura) non vengono duplicate.
# L'esito viene scritto in importa-operazioni-chiuse-bot7-log.txt.
param([string]$BinDir)

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $BinDir) { $BinDir = Join-Path $dir 'bin\Release\net11.0' }
$log = Join-Path $dir 'importa-operazioni-chiuse-bot7-log.txt'
$inv = [Globalization.CultureInfo]::InvariantCulture
function Log($m) { $m | Out-File $log -Append -Encoding utf8; $m }
"=== IMPORTA OPERAZIONI CHIUSE BOT 7 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File $log -Encoding utf8

function ToDec($s) { if ([string]::IsNullOrWhiteSpace($s)) { return $null }; [decimal]::Parse(($s.Trim() -replace ',', '.'), $inv) }
function ToTime($s) { if ([string]::IsNullOrWhiteSpace($s)) { return $null }; [datetime]::ParseExact($s.Trim(), 'yyyy-MM-dd HH:mm:ss', $inv) }
function AddParam($cmd, $name, $type, $value) {
    $p = $cmd.Parameters.Add($name, $type)
    if ($type -eq [Data.SqlDbType]::Decimal) { $p.Precision = 38; $p.Scale = 18 }
    if ($null -eq $value) { $p.Value = [DBNull]::Value } else { $p.Value = $value }
}

$T = [Data.SqlDbType]
try {
    # ---------- Lettura del log: un blocco per ogni "OPERAZIONE CHIUSA" ----------
    $ops = New-Object System.Collections.ArrayList
    $o = $null
    $file = Join-Path $BinDir 'Logs\Operazioni_chiuse.log'
    if (Test-Path $file) {
        foreach ($line in Get-Content $file -Encoding utf8) {
            if ($line -match 'OPERAZIONE CHIUSA - (\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)') {
                $o = @{ Id = $null; Symbol = $null; Strategy = $null; IsLong = $true; Stop = $null; Target = $null; Reason = $null
                        Entry = $null; Exit = $null; Profit = $null; Pct = $null; Status = $null; Open = $null; Close = (ToTime $Matches[1]) }
                [void]$ops.Add($o); continue
            }
            if ($null -eq $o) { continue }
            if     ($line -match '^Simbolo: (.+)$')        { $o.Symbol = $Matches[1].Trim() }
            elseif ($line -match '^Strategia: (.+)$')      { $o.Strategy = $Matches[1].Trim() }
            elseif ($line -match '^Direzione: (\w+)')      { $o.IsLong = ($Matches[1] -ne 'SHORT') }
            elseif ($line -match '^Stop Loss: \$(\S+) \| Target: \$(\S+)') { $o.Stop = ToDec $Matches[1]; $o.Target = ToDec $Matches[2] }
            elseif ($line -match '^Motivo uscita: (.*)$')  { $o.Reason = $Matches[1].Trim() }
            elseif ($line -match '^Prezzo Entrata: \$(.*)$') { $o.Entry = ToDec $Matches[1] }
            elseif ($line -match '^Prezzo Uscita: \$(.*)$')  { $o.Exit = ToDec $Matches[1] }
            elseif ($line -match '^Profitto: (.*)$')       { $o.Profit = ToDec $Matches[1] }
            elseif ($line -match '^Percentuale: (.*)%')    { $o.Pct = ToDec $Matches[1] }
            elseif ($line -match '^Stato: (.*)$')          { $o.Status = $Matches[1].Trim() }
            elseif ($line -match '^Apertura: (.*)$')       { $o.Open = ToTime $Matches[1] }
            elseif ($line -match '^Chiusura: (.*)$')       { $c = ToTime $Matches[1]; if ($c) { $o.Close = $c } }
            elseif ($line -match '^ID: (\S+)')             { $o.Id = $Matches[1] }
        }
    }

    $conn = New-Object System.Data.SqlClient.SqlConnection 'Server=(localdb)\MSSQLLocalDB;Database=bot;Integrated Security=True'
    $conn.Open()
    $tx = $conn.BeginTransaction()
    $n = 0; $skipped = 0
    foreach ($o in $ops) {
        if (-not $o.Id -or $null -eq $o.Entry -or $null -eq $o.Open) { $skipped++; continue }
        $cmd = $conn.CreateCommand(); $cmd.Transaction = $tx
        $cmd.CommandText = @"
IF NOT EXISTS (SELECT 1 FROM bot7.bot7_operazioni_chiuse WHERE TradeId = @Id AND CloseTime >= @Close AND CloseTime < DATEADD(second, 1, @Close))
INSERT INTO bot7.bot7_operazioni_chiuse (TradeId, Symbol, Strategy, IsLong, StopLoss, TargetPrice, ExitReason, EntryPrice, ExitPrice,
                                         Profit, ProfitPercentage, Status, OpenTime, CloseTime, Bot)
SELECT @Id, @Symbol, @Strategy, @IsLong, COALESCE(t.StopLoss, @Stop), COALESCE(t.TargetPrice, @Target), @Reason,
       COALESCE(t.EntryPrice, @Entry), COALESCE(t.ExitPrice, @Exit), COALESCE(t.Profit, @Profit), COALESCE(t.ProfitPercentage, @Pct),
       @Status, COALESCE(t.OpenTime, @Open), COALESCE(t.CloseTime, @Close), N'Bot 7'
FROM (SELECT 1 AS x) d
LEFT JOIN bot7.bot7_trades t ON t.Id = @Id AND t.CloseTime >= @Close AND t.CloseTime < DATEADD(second, 1, @Close)
"@
        AddParam $cmd '@Id' $T::NVarChar $o.Id; AddParam $cmd '@Symbol' $T::NVarChar $o.Symbol; AddParam $cmd '@Strategy' $T::NVarChar $o.Strategy
        AddParam $cmd '@IsLong' $T::Bit $o.IsLong; AddParam $cmd '@Stop' $T::Decimal $o.Stop; AddParam $cmd '@Target' $T::Decimal $o.Target
        AddParam $cmd '@Reason' $T::NVarChar $o.Reason; AddParam $cmd '@Entry' $T::Decimal $o.Entry; AddParam $cmd '@Exit' $T::Decimal $o.Exit
        AddParam $cmd '@Profit' $T::Decimal $o.Profit; AddParam $cmd '@Pct' $T::Decimal $o.Pct; AddParam $cmd '@Status' $T::NVarChar $o.Status
        AddParam $cmd '@Open' $T::DateTime2 $o.Open; AddParam $cmd '@Close' $T::DateTime2 $o.Close
        $n += [Math]::Max(0, $cmd.ExecuteNonQuery())
    }
    Log "Operazioni chiuse: $($ops.Count) nel log, $n inserite, $skipped scartate perche incomplete"

    $tx.Commit()
    $conn.Close()
    Log "OK"
} catch {
    if ($tx) { try { $tx.Rollback() } catch {} }
    Log "ERRORE: $($_.Exception.Message) (riga $($_.InvocationInfo.ScriptLineNumber))"
}
