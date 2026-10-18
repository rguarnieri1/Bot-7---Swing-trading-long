@echo off
chcp 65001 > nul
cls

echo.
echo ╔════════════════════════════════════════════════════════╗
echo ║     🤖 BOT AZIONI ITA - VERSIONE 1.0                   ║
echo ║     Interactive Brokers + Azioni Italiane              ║
echo ║        Backtest + Live Trading                         ║
echo ╚════════════════════════════════════════════════════════╝
echo.

cd /d "C:\Users\Pc\OneDrive\Bot\2 - Bot Cripto ITA" || exit /b 1

echo Compilazione in corso...
dotnet build -c Release > nul 2>&1

if errorlevel 1 (
    echo ❌ Errore nella compilazione!
    pause
    exit /b 1
)

echo ✅ Compilazione completata!
echo.
echo 🚀 Avvio bot in corso...
echo.
echo Strategie Attive:
echo   * Bullish Divergence V2 (Optimized)
echo   * Zero-Line Crossover V2 (Optimized)
echo.
echo Dati:
echo   * Fonte: Interactive Brokers (IBKR)
echo   * Asset Class: Azioni Italiane FTSEMIB
echo   * Numero Azioni: 20 principali blue-chip
echo.

dotnet run -c Release

pause
