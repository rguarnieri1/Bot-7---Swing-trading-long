# 🤖 Bot Cripto - Trading Automatico

Bot di trading automatico in .NET 8 C# che monitora i mercati delle criptovalute e identifica opportunità di trading utilizzando strategie tecniche avanzate.

## 📋 Caratteristiche

- **Monitoraggio Continuo**: Controlla il mercato ogni 5 minuti
- **Strategie Tecniche Implementate**:
  - **EMA Ribbon Trend Following**: Allineamento dei 4 EMA con conferma candle e volume
- **Notifiche Desktop**: Avvisi in tempo reale per ogni segnale rilevato
- **Report Settimanale**: Riepilogo automatico delle performance ogni lunedì
- **Tracking Operazioni**: Monitora tutte le operazioni (entry/exit) con profitti

## 🚀 Avvio

### Prerequisiti
- .NET 8 SDK installato
- Connessione a internet per accedere alle API di Crypto.com

### Esecuzione

```bash
cd "1 - Bot Cripto"
dotnet run
```

Il bot si avvierà e inizierà a monitorare il mercato ogni 5 minuti.

## 📊 Struttura del Progetto

```
├── Models/
│   └── Cryptocurrency.cs          # Modelli dati
├── Services/
│   ├── CryptoDataService.cs        # Recupero dati da Crypto.com
│   ├── NotificationService.cs      # Notifiche desktop
│   ├── ReportingService.cs         # Tracking operazioni e reporting
│   └── BotSchedulerService.cs      # Orchestrazione del bot
├── Strategies/
│   ├── TechnicalIndicators.cs           # Indicatori tecnici (RSI, MACD, EMA, SMA)
│   └── EmaRibbonTrendFollowingStrategy.cs # Strategia principale EMA Ribbon
├── Data/
│   ├── trades.json                 # Registro operazioni
│   └── Reports/
│       └── Weekly_Report_*.txt      # Report settimanali
├── Logs/
│   └── signals_*.log                # Log dei segnali
└── Program.cs                       # Entry point

```

## 📈 Strategie di Trading

### EMA Ribbon Trend Following + Candle Confirmation
Strategia trend-following principale che utilizza l'allineamento di 4 EMA (5, 10, 20, 50) per identificare trend forti, con conferma mediante:
- **Candle Body Strength**: Il corpo della candela deve rappresentare >60% dell'altezza totale
- **Volume Confirmation**: Volume deve essere 1.2x superiore alla media
- **Filtro RSI**: RSI deve trovarsi fuori dalle zone di ipercomprato/ipervenduto (30-70)

**Parametri**:
- EMA Periods: 5, 10, 20, 50
- Candle Body Threshold: 0.6 (60%)
- Volume Multiplier: 1.2x
- Win Rate Atteso: 60-62%

## 📁 Output

### Trading Record
Tutte le operazioni sono salvate in `Data/trades.json`:
```json
{
  "Id": "uuid",
  "Symbol": "BTC",
  "OpenTime": "2026-08-31T10:30:00Z",
  "EntryPrice": 42500.50,
  "Strategy": "EMA Ribbon Trend Following (Primary)",
  "Status": "Open"
}
```

### Report Settimanale
Ogni lunedì viene generato un report in `Data/Reports/Weekly_Report_YYYY-MM-DD.txt` con:
- Statistiche generali (operazioni totali, aperte, chiuse)
- Performance (profitto totale, ROI medio, win rate)
- Dettagli di ogni operazione chiusa

### Log Segnali
Ogni segnale è registrato in `Logs/signals_YYYY-MM-DD.log`

## 🔔 Notifiche Desktop

Il bot invia notifiche Windows Toast per:
- Segnali di ACQUISTO 🚀
- Segnali di VENDITA ⛔

Inoltre emette un beep sonoro per catturare l'attenzione.

## ⚙️ Configurazione

Per modificare i parametri di monitoraggio, editare `BotSchedulerService.cs`:

```csharp
// Cambiar l'intervallo di controllo (in minuti)
TimeSpan.FromMinutes(5)  // Cambia il numero per l'intervallo desiderato

// Limitare il numero di criptovalute analizzate
cryptos.Take(50)  // Aumenta o diminuisce il numero
```

## 📚 Indicatori Tecnici Disponibili

Il bot implementa i seguenti indicatori:
- **RSI** (Relative Strength Index)
- **MACD** (Moving Average Convergence Divergence)
- **EMA** (Exponential Moving Average)
- **SMA** (Simple Moving Average)
- **Bollinger Bands**

## 🛡️ Note Importanti

- Questo bot è per **scopi educativi e di monitoraggio**
- **NON esegue transazioni reali** - solo identifica segnali
- Testare sempre le strategie in ambienti di test prima di usarle in produzione
- Le performance passate non garantiscono risultati futuri

## 📝 Log e Debug

Per troubleshooting, controllare:
- `Logs/signals_*.log` - Record di tutti i segnali
- Console output - Informazioni di runtime
- `Data/trades.json` - Stato delle operazioni

## 🔗 Fonti Dati

I dati sono recuperati da **Crypto.com Exchange API** tramite:
- Ticker attuali
- Candele OHLCV (4h per default)
- Order book e trade history

## 📦 Dipendenze

- Newtonsoft.Json - Parsing JSON
- System.Net.Http - Richieste HTTP
- System.Runtime.InteropServices - Interop Windows

## 📄 Licenza

Uso personale - Modificare come necessario

---

**Sviluppato con**: .NET 8 C# | **Data**: Agosto 2026
