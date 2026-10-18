@echo off
chcp 65001 > nul
cls

echo.
echo ╔════════════════════════════════════════════════════════╗
echo ║       🤖 AVVIO SIMULTANEO - 3 BOT TRADING              ║
echo ╚════════════════════════════════════════════════════════╝
echo.

echo 📂 Navigo alle cartelle bot...
echo.

REM Bot 1 - Cripto
echo ╔════════════════════════════════════════════════════════╗
echo ║  🚀 AVVIO BOT 1 - CRIPTO                               ║
echo ╚════════════════════════════════════════════════════════╝
start "Bot Cripto" cmd /k "cd /d C:\Users\Pc\OneDrive\Bot\1 - Bot Cripto && run.bat"

timeout /t 3 /nobreak

REM Bot 2 - SMA Crypto
echo ╔════════════════════════════════════════════════════════╗
echo ║  🚀 AVVIO BOT 2 - SMA CRYPTO                           ║
echo ╚════════════════════════════════════════════════════════╝
start "Bot SMA Crypto" cmd /k "cd /d C:\Users\Pc\OneDrive\Bot\2 - Bot Sma - Crypto && run.bat"

timeout /t 3 /nobreak

REM Bot 3 - ERTF Ita (Interactive Brokers)
echo ╔════════════════════════════════════════════════════════╗
echo ║  🚀 AVVIO BOT 3 - ERTF ITA (AZIONI ITALIANE)           ║
echo ║  ✅ TWS è stato avviato                                ║
echo ╚════════════════════════════════════════════════════════╝
start "Bot ERTF Ita" cmd /k "cd /d C:\Users\Pc\OneDrive\Bot\3 - ERTF Ita && run.bat"

echo.
echo ═══════════════════════════════════════════════════════════
echo ✅ I 3 BOT SONO STATI AVVIATI!
echo ═══════════════════════════════════════════════════════════
echo.
echo 📊 Finestre aperte:
echo   1. Bot Cripto - Criptovalute (Crypto.com API)
echo   2. Bot SMA Crypto - Strategia SMA (Crypto.com API)
echo   3. Bot ERTF Ita - Azioni Italiane (Interactive Brokers TWS)
echo.
echo 📈 Monitoraggio:
echo   • Bot Cripto: ogni 15 minuti
echo   • Bot SMA Crypto: ogni 15 minuti
echo   • Bot ERTF Ita: ogni 5 minuti
echo.
echo 💾 Log files:
echo   Logs/ directory di ogni bot
echo.
echo 🔔 Notifiche:
echo   Desktop notifications abilitate
echo.
echo Puoi chiudere questa finestra - i bot continueranno a girare!
echo.
pause
