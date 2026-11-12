# Esegue crea-tabelle-bot7.sql su (localdb)\MSSQLLocalDB e scrive l'esito in crea-tabelle-bot7-log.txt
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$log = Join-Path $dir 'crea-tabelle-bot7-log.txt'
"=== CREA TABELLE BOT 7 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File $log -Encoding utf8
try {
    $sql = Get-Content (Join-Path $dir 'crea-tabelle-bot7.sql') -Raw -Encoding utf8
    $batches = [regex]::Split($sql, '(?m)^\s*GO\s*$') | Where-Object { $_.Trim() -ne '' }
    $conn = New-Object System.Data.SqlClient.SqlConnection 'Server=(localdb)\MSSQLLocalDB;Database=master;Integrated Security=True'
    $conn.add_InfoMessage({ param($s, $e) $e.Message | Out-File $log -Append -Encoding utf8 })
    $conn.Open()
    foreach ($b in $batches) {
        $cmd = $conn.CreateCommand(); $cmd.CommandText = $b; [void]$cmd.ExecuteNonQuery()
    }
    foreach ($t in 'bot7_trades', 'bot7_signals', 'bot7_cycles') {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT c.name + ' ' + t.name FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id WHERE c.object_id = OBJECT_ID(N'bot7.$t') ORDER BY c.column_id"
        $r = $cmd.ExecuteReader(); "Colonne bot7.${t}:" | Out-File $log -Append -Encoding utf8
        while ($r.Read()) { "  " + $r.GetString(0) | Out-File $log -Append -Encoding utf8 }
        $r.Close()
    }
    $conn.Close()
    "OK" | Out-File $log -Append -Encoding utf8
} catch {
    "ERRORE: $($_.Exception.Message)" | Out-File $log -Append -Encoding utf8
}
