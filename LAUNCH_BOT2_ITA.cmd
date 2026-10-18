@echo off
chcp 65001 > nul
cd /d "C:\Users\Pc\OneDrive\Bot\2 - Bot Cripto ITA"
start "" powershell.exe -NoExit -Command "& { Write-Host '🤖 BOT AZIONI ITA AVVIATO'; Write-Host ''; dotnet run -c Release }"
