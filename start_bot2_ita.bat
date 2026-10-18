@echo off
chcp 65001 > nul
cls

echo.
echo ╔════════════════════════════════════════════════════════╗
echo ║      🤖 BOT AZIONI ITA - AVVIO                         ║
echo ║    Interactive Brokers TWS + Azioni Italiane           ║
echo ╚════════════════════════════════════════════════════════╝
echo.

REM Verifica TWS
echo 🔌 Verifica connessione TWS...
powershell -Command "try { $response = Invoke-WebRequest -Uri 'http://localhost:7497' -TimeoutSec 2 -ErrorAction SilentlyContinue; Write-Host '✅ TWS raggiungibile' -ForegroundColor Green } catch { Write-Host '⚠️ TWS non raggiungibile. Verificare che sia avviato con API abilitata.' -ForegroundColor Yellow }"

echo.
echo Navigo in cartella bot...
cd /d "C:\Users\Pc\OneDrive\Bot\2 - Bot Cripto ITA" || (
    echo ❌ Cartella non trovata!
    pause
    exit /b 1
)

echo.
echo Compilazione in corso...
dotnet build -c Release > nul 2>&1

if errorlevel 1 (
    echo ❌ Errore nella compilazione!
    echo.
    dotnet build -c Release
    pause
    exit /b 1
)

echo ✅ Compilazione completata!
echo.
echo ═══════════════════════════════════════════════════════
echo 🚀 AVVIO BOT AZIONI ITA
echo ═══════════════════════════════════════════════════════
echo.
echo Informazioni:
echo   • Fonte Dati: Interactive Brokers TWS (REALI)
echo   • Connessione: localhost:7497
echo   • Asset: Azioni Italiane FTSEMIB (20 titoli)
echo   • Intervallo: Ogni 5 minuti
echo   • Strategie: Bullish Divergence V2 + Zero-Line Crossover V2
echo   • Risk Management: 1%% per trade
echo.
echo Azioni: EOAN, G, ISP, UCG, STM, TIT, LDO, ENI, BMW, SAP...
echo.
echo Log: Logs/
echo Dati: Data/
echo.
echo Premi CTRL+C per fermare il bot
echo ═══════════════════════════════════════════════════════
echo.

dotnet run -c Release

pause
