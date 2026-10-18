# Documentazione - Bot 1 (BotCripto v1.1)

Documentazione tecnica basata sul codice sorgente attuale del progetto `1 - Bot Cripto` (namespace `BotCripto`, target `.NET 10.0`).

## 1. Panoramica

Bot 1 è un'applicazione console .NET 10 per il trading automatico di criptovalute. Analizza periodicamente un ampio paniere di crypto (filtrato per volume 24h ≥ $2.000.000 tramite CoinGecko), applica una strategia trend-following basata su EMA Ribbon con filtro di regime di mercato su BTC (solo long se BTC è rialzista, solo short se è ribassista) e supporto nativo a posizioni short, valida ogni segnale con un modulo di risk management e notifica l'utente (console + log su file; le notifiche desktop toast ed email sono state rimosse, vedi §9). La modalità live è ora un **paper trading engine completo**: i trade vengono aperti e chiusi automaticamente quando il prezzo tocca lo stop loss o il target calcolati dalla strategia, senza inviare alcun ordine reale (vedi §6). Traccia inoltre i motivi di scarto di ogni ciclo (filtro strategia o RiskManager) per diagnosticare perché non vengono generati segnali. Include anche due modalità di backtest (una "reale" basata su candele storiche con simulazione di portafoglio, e una sintetica basata su distribuzioni statistiche).

Punto di ingresso: `Program.cs`.

## 2. Modalità di esecuzione

L'app legge gli argomenti da riga di comando. Tre costanti in `Program.cs` definiscono i default condivisi da live e backtest reale: `InitialCapital` (€150), `MaxTradeAmount` (€10), `Timeframe` (`"12h"`, il timeframe che ha dato i risultati migliori nei backtest) e `RewardRiskRatio` (`3.0`, take profit a 3 volte la distanza dello stop, anch'esso il valore migliore nei backtest a 12 mesi su candele 12h).

- **Modalità Live (default)**: `dotnet run` → esegue `RunLiveAsync()`, che istanzia `BotSchedulerService(InitialCapital, MaxTradeAmount, Timeframe, RewardRiskRatio)` e avvia il ciclo di monitoraggio continuo in **paper trading** (nessun ordine reale, vedi §6). Il banner iniziale riporta "Capitale Iniziale: €150.00", "Risk per Trade: 2% (€3.00)", "Importo massimo per trade: €10.00", "Take profit: 3x la distanza dello stop" e "Modalità: paper trading (segnali e trade simulati, nessun ordine reale)", coerenti con i valori realmente in uso.
- **Modalità Backtest sintetico**: `dotnet run -- --backtest` → esegue `RunBacktestAsync()`, che istanzia `SyntheticBacktest` (capitale €100) e genera un report su 365 giorni, 20 simboli, win-rate atteso 55%, 8 trade per simbolo. È una simulazione statistica (non usa prezzi storici reali, vedi §11.1).
- **Modalità Backtest su dati storici reali**: `dotnet run -- --backtest-real [giorni | yyyy-MM-dd yyyy-MM-dd] [opzioni]` → esegue `RunRealBacktestAsync()`, che istanzia `BacktestService` e recupera l'universo di crypto filtrato per volume da `CryptoDataService.GetLargeCapCryptocurrenciesAsync()` (a meno che non sia specificato `--symbols`). A differenza del backtest sintetico, esegue realmente `EmaRibbonTrendFollowingStrategy` e `RiskManager` candela per candela su una simulazione di portafoglio condivisa tra tutti i simboli (vedi §11.2). Argomenti posizionali e opzioni:
  - Argomento posizionale: un numero di giorni (default 30 se omesso) oppure due date `yyyy-MM-dd yyyy-MM-dd` (intervallo esplicito, estremo finale incluso tramite `AddDays(1).AddTicks(-1)`).
  - `--timeframe 1h|2h|4h|6h|12h|1d` — timeframe delle candele (default: `Timeframe` di `Program.cs`, `12h`).
  - `--capital <importo>` — capitale iniziale del backtest (default: `InitialCapital`, €150).
  - `--rr <rapporto>` — take profit come multiplo della distanza dello stop (default: `RewardRiskRatio`, 3.0).
  - `--symbols <file>` — elenco di simboli da usare (uno per riga); se il file non esiste viene creato con l'elenco scaricato da CoinGecko/Crypto.com/Bybit, così più backtest possono essere ripetuti esattamente sullo stesso paniere senza richiamare le API ogni volta.

## 3. Struttura del progetto

```
Program.cs                                  Entry point (Live / Backtest sintetico / Backtest reale)
Models/
  Cryptocurrency.cs                         Modelli dati: Cryptocurrency, Candle, AnalysisResult, Trade
Strategies/
  EmaRibbonTrendFollowingStrategy.cs         Strategia principale (EMA Ribbon + candela + volume + RSI + regime BTC)
  TechnicalIndicators.cs                     Libreria indicatori: EMA, SMA, RSI, MACD, Bollinger Bands
Services/
  BotSchedulerService.cs                     Orchestratore del ciclo live: scansione, paper trading (apertura/chiusura automatica), notifiche
  CryptoDataService.cs                       Recupero dati mercato (Crypto.com → Bybit, mai dati demo) e storico esteso
  RiskManager.cs                             Position sizing (long/short), calcolo P&L/tasse, metriche di performance
  NotificationService.cs                     Notifiche console e log file
  ReportingService.cs                        Persistenza trade (Data/trades.json), chiusura paper trade, report settimanale
  BacktestService.cs                         Backtest a portafoglio su dati storici reali (--backtest-real)
  SyntheticBacktest.cs                       Backtest sintetico basato su distribuzione statistica
config.json                                  Configurazione "di progetto" (parametri strategia, risk, reporting)
appsettings.json / appsettings.local.json    Non più letto dal codice (vedi §12.1)
```

> Nota: `config.json` e `appsettings.json` sono due file di configurazione paralleli con schema diverso, e nessuno dei due è più referenziato da alcuna classe C# (vedi §12): dopo la rimozione delle notifiche email/toast, anche l'ultima sezione di `appsettings.json` effettivamente letta (`Notifications`) è stata eliminata insieme al codice che la consumava.

## 4. Modelli dati (`Models/Cryptocurrency.cs`)

- **`Cryptocurrency`**: `Symbol`, `Name`, `CurrentPrice`, `LastUpdate`.
- **`Candle`**: `Time`, `Open`, `High`, `Low`, `Close`, `Volume`.
- **`AnalysisResult`**: esito dell'analisi di una strategia su un simbolo — `Symbol`, `StrategyName`, `IsSignal`, `Signal` (testo descrittivo, incluso il motivo di rigetto), `CurrentPrice`, `AnalysisTime`, `Indicators` (dizionario nome→valore usato per portare EMA, RSI, stop loss, target, ecc.).
- **`Trade`**: rappresenta un'operazione — `Id` (stringa, di default `Guid.NewGuid().ToString()` ma sovrascrivibile, es. `SyntheticBacktest` usa id testuali tipo `"BTC_0"`), `Symbol`, `OpenTime`, `CloseTime`, `EntryPrice`, `ExitPrice`, `Strategy`, `Status` (`Open`/`Closed`), `Profit`, `ProfitPercentage`. Campi aggiunti per il **paper trading** del ciclo live (§6): `IsLong` (direzione), `StopLoss`/`TargetPrice` (livelli di uscita calcolati dalla strategia/RiskManager al momento dell'apertura), `PositionSize` (quantità dell'asset), `SignalCandleTime` (inizio della candela chiusa che ha generato il segnale, usato per non ri-registrare lo stesso segnale due volte ed evitare di guardare candele precedenti all'apertura quando si cerca lo stop/target), `ExitReason` (`"Stop loss"` o `"Target"`). La proprietà calcolata `IsPaperManaged` (`PositionSize > 0`) distingue i trade gestiti dal nuovo motore di paper trading da eventuali trade storici registrati prima della sua introduzione (che hanno `PositionSize = 0` e vengono ignorati da chiusura automatica, metriche e report settimanale).

## 5. Strategia di trading

### 5.1 EMA Ribbon Trend Following + Candle Confirmation (`Strategies/EmaRibbonTrendFollowingStrategy.cs`)

Unica strategia attiva nel bot live. Richiede almeno 60 candele. Pipeline di filtri sequenziali (ogni filtro fallito interrompe l'analisi con un `Signal` di rigetto specifico):

1. **EMA Ribbon** — calcola EMA a 5, 10, 20, 30 periodi (`TechnicalIndicators.CalculateEMA`).
2. **Trend filter (allineamento ribbon)** — richiede allineamento stretto crescente (uptrend: EMA5>EMA10>EMA20>EMA30) o decrescente (downtrend); altrimenti rigetta ("no clear trend").
3. **Volume filter** — il volume dell'ultima candela deve essere ≥ 150% della media mobile a 20 periodi (`_volumeMultiplierThreshold = 1.5`); altrimenti rigetta. Se la media è zero o negativa (nessun dato di volume), rigetta esplicitamente ("No volume data") invece di dividere per zero.
4. **Candle confirmation** — l'ultima candela deve avere un corpo "solido" (`bodyStrength ≥ 0.6`) nella direzione del trend, e il prezzo deve essere oltre EMA10 nella direzione corretta.
5. **RSI filter** — calcolato su 14 periodi; rigetta segnali long con RSI > 85 (ipercomprato estremo) o segnali short con RSI < 15 (ipervenduto estremo).
6. **Breakout confirmation** — richiede che il prezzo abbia appena rotto EMA5 o EMA10 rispetto alla candela precedente, nella direzione del trend.
7. **Filtro di regime BTC** — il segnale viene accettato solo se è concorde con il regime di mercato di BTC: `IsBtcBullish(btcCandles)` (metodo statico della stessa classe) ritorna `true` se l'ultima chiusura di BTC è sopra la sua EMA a 50 periodi, `false` se sotto, `null` se i dati non bastano per calcolarla. `Analyze()` riceve questo valore come parametro (`btcBullish`) già calcolato dal chiamante: i segnali long sono accettati solo con `btcBullish == true`, quelli short solo con `btcBullish == false`; se il regime è sconosciuto (`null`) il segnale viene sempre scartato ("Rejected - Against BTC regime").

Se tutti i filtri passano, genera un segnale `BUY` o `SELL` con:
- `StopLoss` = min/max tra EMA20 e low/high dell'ultima candela, con margine ±0.5%.
- `Target` = calcolato con rapporto rischio:rendimento **2:1 hardcoded** rispetto allo stop loss, nella direzione del trade. **Nota**: questo è un valore puramente indicativo/di servizio — il target effettivamente usato per aprire la posizione (in live e in entrambi i backtest reali) viene **ricalcolato da `RiskManager.CalculatePosition()`** con il rapporto rischio:rendimento configurabile passato dal chiamante (`rewardRiskRatio`, oggi 3.0 di default, vedi §2 e §8), che sovrascrive questo valore in `emaRibbonResult.Indicators["Target"]`.
- `SignalStrength` = combinazione di forza del corpo candela e rapporto volume (usata da `BotSchedulerService` e `BacktestService` per dare priorità ai segnali più forti quando il capitale disponibile non basta per aprirli tutti, vedi §6, §11.2).

Parametri chiave (hardcoded nella classe, non letti da `config.json`): EMA periods `[5,10,20,30]`, volume threshold `1.5` (150% della media), body strength `0.6`, RSI overbought/oversold dichiarati come campo `70/30` (ma i controlli effettivi usano `85/15`, vedi §14), EMA regime BTC a 50 periodi, rapporto R:R 2:1 nel calcolo interno del `Target` indicativo (sovrascritto da `RiskManager`, vedi sopra).

### 5.2 Indicatori tecnici (`Strategies/TechnicalIndicators.cs`)

Libreria statica condivisa:
- `CalculateEMA(prices, period)` — media mobile esponenziale, seed con SMA del primo periodo.
- `CalculateSMA(prices, period)` — media mobile semplice.
- `CalculateRSI(prices, period=14)` — RSI con smoothing di Wilder.
- `CalculateMACD(prices, fast=12, slow=26, signal=9)` — MACD, signal line, istogramma (definito ma non usato dalla strategia attiva).
- `CalculateBollingerBands(prices, period=20, stdDevMultiplier=2)` — bande di Bollinger (definito ma non usato dalla strategia attiva).

## 6. Ciclo live e paper trading (`Services/BotSchedulerService.cs`)

`BotSchedulerService` orchestra il funzionamento continuo del bot in modalità **paper trading**: apre e chiude posizioni simulate automaticamente, senza alcuna interazione con un exchange reale.

- Costruttore `BotSchedulerService(initialCapital, maxTradeAmount, timeframe, rewardRiskRatio)`: riceve tutti e quattro i parametri da `Program.cs` (oggi €150, €10, `"12h"`, `3.0`) e inizializza `CryptoDataService`, `NotificationService`, `ReportingService`, `EmaRibbonTrendFollowingStrategy` e `RiskManager` (rischio 2% per trade, R:R = `rewardRiskRatio`, max posizione 10% del capitale **o** `maxTradeAmount` se inferiore, max 100 trade simultanei, commissioni 0.25% per lato, tasse 26%). `_timeframeSpan` viene derivato dal timeframe tramite `BacktestService.TimeframeToTimeSpan()` (condivisa con il backtest, vedi §11.2), usato per sapere quando una candela è "chiusa".
- `StartAsync()`:
  - Esegue subito un primo ciclo di controllo mercato.
  - Imposta un `Timer` che richiama `CheckMarketAsync()` ogni 10 minuti (indipendentemente dal timeframe delle candele: il bot controlla spesso se è appena uscita una nuova candela chiusa, vedi sotto).
  - Imposta un secondo `Timer` per generare il report settimanale ogni lunedì alle 00:00 UTC.
  - Rimane in attesa indefinita (`Task.Delay(-1)`).
  - Un flag `Interlocked` (`_cycleRunning`) impedisce che due esecuzioni di `CheckMarketAsync()` si sovrappongano se un ciclo precedente non è ancora terminato quando scatta il timer successivo (altrimenti lo stesso segnale potrebbe essere registrato due volte).
- `CheckMarketAsync()` (ciclo principale), ad ogni esecuzione:
  1. **Chiusura paper trade** (`CloseTradesAtStopOrTargetAsync`) — per ogni trade `Open` e `IsPaperManaged`, scarica le candele più recenti del simbolo e verifica se una candela successiva a quella del segnale (`SignalCandleTime`) ha toccato lo stop loss o il target; se entrambi nella stessa candela, assume lo stop loss (ipotesi conservativa, stessa regola del backtest, vedi §11.2). Il trade viene chiuso con `RiskManager.CalculateProfitAndTaxes()` (gestendo long/short) e loggato tramite `ReportingService.ClosePaperTrade()`.
  2. **Ricalcolo capitale** — `_currentAccountValue` viene ricalcolato ogni ciclo come `_initialCapital + somma dei profitti dei trade paper chiusi`: a differenza delle versioni precedenti del bot, ora riflette realmente l'andamento del paper trading (non resta mai fisso al capitale iniziale).
  3. **Candela chiusa recente?** — i segnali vengono cercati solo su candele BTC/simbolo effettivamente chiuse (`ClosedCandles`, esclude quella ancora in formazione) e solo entro `SignalFreshness` (30 minuti) dalla chiusura della candela più recente: evita di entrare "in ritardo" su una candela ormai vecchia. Se non c'è una candela appena chiusa, il ciclo stampa l'orario della prossima chiusura attesa e salta la ricerca di segnali (va comunque avanti con la chiusura dei trade aperti, punto 1).
  4. Se c'è una candela appena chiusa: calcola il **regime di mercato BTC** (`EmaRibbonTrendFollowingStrategy.IsBtcBullish`) e per ciascuna crypto (fino a 500, da `GetLargeCapCryptocurrenciesAsync()`) scarica fino a 300 candele (`CandlesPerAnalysis`, stessa finestra del backtest) con una cache locale per ciclo (`GetCandlesCachedAsync`, evita di riscaricare le stesse candele più volte nello stesso ciclo, es. per BTC). Salta un simbolo se: ha già una posizione aperta, il segnale di quella stessa candela (`SignalCandleTime`) è già stato registrato in precedenza, ha meno di 60 candele disponibili (`MinCandlesForAnalysis`), oppure la sua ultima candela non coincide con l'ultima candela chiusa di BTC (dati non allineati/aggiornati).
  5. Esegue `EmaRibbonTrendFollowingStrategy.Analyze(symbol, candles, btcBullish)` sui candidati rimanenti; se non genera segnale, classifica il motivo di rigetto tramite `ClassifyStrategyRejection()` (vedi sotto).
  6. I segnali generati vengono ordinati dal `SignalStrength` più alto al più basso (stessa logica del backtest, vedi §11.2): a parità di capitale limitato, entrano prima i segnali più forti. Per ciascuno, chiama `RiskManager.CalculatePosition()` per dimensionare la posizione; se non valida, classifica il motivo tramite `ClassifyRiskRejection()`. Se valida, verifica inoltre che il valore nozionale della nuova posizione sommato al capitale già impegnato sui trade aperti non superi `_currentAccountValue` (**niente leva**: una posizione entra solo se c'è capitale libero sufficiente) — altrimenti scarta per "Capitale già impegnato".
  7. Se la posizione supera entrambi i controlli: invia notifica (`NotificationService`), registra il trade come **aperto e gestito dal paper trading** (`ReportingService.RecordTrade(..., isLong, stopLoss, target, positionSize, signalCandleTime)`), aggiorna i contatori locali.
  8. Applica un piccolo delay (50ms) tra una crypto e l'altra per non sovraccaricare le API.
  9. A fine ciclo stampa un riepilogo (trade chiusi su stop/target, segnali trovati, segnali filtrati per rischio/capitale, trade aperti con relativo capitale impegnato, account value realizzato) seguito dai **motivi di scarto del ciclo corrente** (conteggio per categoria, in ordine decrescente).
  10. Ogni 10 cicli, calcola e stampa le metriche di performance cumulative (win rate, profit factor, P&L totale, expectancy) tramite `RiskManager.CalculatePerformanceMetrics` sui soli trade `IsPaperManaged`, passando il capitale iniziale realmente configurato, seguite dai **motivi di scarto cumulativi** (dall'avvio del bot).

**Diagnostica dei motivi di scarto** — per capire quale filtro blocca i segnali, ogni candidato scartato viene classificato in una categoria leggibile e conteggiato sia per il ciclo corrente (`rejectionCounts`, azzerato a ogni ciclo) sia cumulativamente (`_cumulativeRejectionCounts`, per l'intera durata del processo):
- `ClassifyStrategyRejection(signal)` — mappa il testo del `Signal` di rigetto della strategia (§5.1) in categorie: trend non allineato, volume insufficiente, candela non abbastanza forte, prezzo non conferma vs EMA10, RSI estremo, nessun breakout EMA, **contro il regime BTC**, dati insufficienti; qualsiasi altro testo finisce in "Strategia: altro (...)".
- `ClassifyRiskRejection(reason)` — mappa il `Reason` di rigetto del `RiskManager` (§8) in categorie: troppi trade aperti simultaneamente, profitto non copre commissioni, rapporto rischio/rendimento insufficiente, errore calcolo stop loss; altrimenti "Risk Manager: altro (...)".
- Categorie aggiuntive registrate direttamente nel ciclo (non derivate dalla strategia/RiskManager): "Posizione già aperta sul simbolo", "Segnale di questa candela già registrato", "Dati insufficienti (candele < 60)", "Ultima candela non aggiornata", "Capitale già impegnato".

## 7. Recupero dati di mercato (`Services/CryptoDataService.cs`)

`GetLargeCapCryptocurrenciesAsync()` combina due catene di fallback: una per il ticker/prezzo e una per le capitalizzazioni, che vengono poi incrociate.

**Ticker** — catena di fallback a tre livelli:
1. **Crypto.com API** (`https://api.crypto.com/v2/public/get-ticker`, `get-candlestick`) — sorgente primaria.
2. **Bybit API** (`https://api.bybit.com/v5/market/tickers`, `market/kline`, categoria `spot`) — fallback se Crypto.com fallisce o non risponde.
3. **Nessun fallback demo** — se sia Crypto.com sia Bybit falliscono, `GetLargeCapCryptocurrenciesAsync()` ritorna una lista vuota (ciclo saltato) e `GetCandlesAsync()` ritorna una lista di candele vuota (simbolo saltato). I generatori di dati demo (`GetDemoData`, `GenerateDemoCandles`) sono stati rimossi: il bot non opera mai su prezzi o candele fittizie.

**Parsing numerico** — tutti i prezzi/volumi restituiti dalle API (stringhe JSON) vengono convertiti con `decimal.Parse(..., NumberStyles.Float, CultureInfo.InvariantCulture)`, indipendente dalla cultura di sistema.

**Deduplicazione ticker** — Crypto.com espone sia `X_USDT` sia `X_USD` per molti simboli; dopo aver normalizzato il simbolo (rimuovendo il suffisso), `TryGetCryptoComTickers()` tiene solo il primo risultato per simbolo (`GroupBy(c => c.Symbol).Select(g => g.First())`), evitando che lo stesso simbolo venga analizzato (e nel backtest tradato) due volte.

**Filtro volume via CoinGecko** (`GetVolumesAsync` + `FilterByVolume`):
- Prima di interrogare Crypto.com/Bybit, il servizio scarica il volume 24h da `GET https://api.coingecko.com/api/v3/coins/markets` (2 pagine da 250 risultati, ordinate per market cap decrescente → fino a 500 simboli), costruendo un dizionario simbolo→volume 24h (case-insensitive, primo valore vince in caso di duplicati).
- I ticker ottenuti da Crypto.com o Bybit vengono poi filtrati tenendo solo i simboli presenti nel dizionario con `Volume24h >= $2.000.000` (costante `MinVolume24hUsd`, non letta da `config.json`); il filtro esclude le crypto che scambiano un volume troppo esiguo per essere affidabili (spread larghi, prezzi stantii).
- Se CoinGecko non è raggiungibile o non risponde entro i tentativi previsti, il dizionario risulta vuoto e il filtro viene **saltato per quel ciclo** (vengono restituiti tutti i ticker non filtrati), con un warning in console.

**Storico esteso** (`GetHistoricalCandlesAsync(symbol, interval, from, to)`) — usato dal paper trading live (per riscoprire i prezzi di chiusura di un trade, §6) e dal backtest reale (§11.2) per scaricare più dati di quanti ne servano a `GetCandlesAsync` (limitato a 300 candele più recenti):
- Pagina all'indietro nel tempo chiamando `https://api.crypto.com/exchange/v1/public/get-candlestick` (API "exchange", diversa da quella usata per il ticker) con `end_ts` decrescente, 300 candele a pagina, fino a 50 pagine o finché non copre l'intervallo `[from, to]` richiesto.
- Se il risultato ha meno di 50 candele nell'intervallo (es. simbolo non quotato in USDT su Crypto.com), ricade su `TryGetBybitHistoricalCandles`, che pagina analogamente su `market/kline` di Bybit (fino a 20 pagine da 1000 candele).
- Le candele vengono deduplicate per timestamp (`Dictionary<DateTime, Candle>`) durante la paginazione.

Caratteristiche generali:
- Rate limiting semplice tra chiamate API (100ms minimo, `RateLimitDelay`), applicato anche alle chiamate CoinGecko e allo storico esteso.
- Timeframe supportati per le candele: `1m, 5m, 15m, 30m, 1h, 2h, 4h, 6h, 12h, 1d` (mappati ai formati specifici di ciascun exchange — Crypto.com usa direttamente la stessa stringa, Bybit usa i minuti, es. `"12h"` → `"720"`, `"1d"` → `"D"`).
- Le candele Bybit vengono ordinate e limitate; le candele minime richieste per l'analisi sono 50 nel recupero dati, 60 nella strategia (§5.1).
- I ticker Crypto.com/Bybit vengono ordinati per prezzo decrescente e limitati (in codice) a 500 **prima** del filtro di volume; per Bybit la richiesta HTTP specifica comunque `limit=200`, quindi il numero effettivo restituito non supera 200 anche a filtro disattivato.

## 8. Gestione del rischio (`Services/RiskManager.cs`)

Classe centrale per money management, indipendente dalla strategia. Supporta sia posizioni **long** sia **short**:

- **`CalculatePosition(symbol, entryPrice, volatilityPercent, openTrades, currentAccountValue, isLong = true, strategyStopLoss = 0m)`**:
  - Stop loss: usa quello passato dalla strategia (`strategyStopLoss`, calcolato da `EmaRibbonTrendFollowingStrategy`, vedi §5.1) se fornito (> 0); altrimenti ricade su un fisso 1.5% dall'entry. Per i long lo stop sta sotto il prezzo di entrata, per gli short sopra; il rischio per unità (`riskPerUnit`) è calcolato di conseguenza nella direzione corretta.
  - Position size (in unità dell'asset) = rischio per trade (in valuta) / rischio per unità, poi cappato confrontando il **valore nozionale** (`positionSize * entryPrice`, in €) con il massimale, che è il **minore** tra `currentAccountValue * maxPositionSizePercent` (10% del capitale) e `maxPositionValue` — un importo fisso massimo per trade (in €) passato dal chiamante (parametro opzionale del costruttore, default `decimal.MaxValue` se omesso); sia `BotSchedulerService` sia `BacktestService` lo impostano a `maxTradeAmount` (attualmente €10, vedi §2, §6, §11.2), che con un capitale di €150 è il vincolo che prevale sul 10% (€15).
  - Target calcolato a distanza `riskPerUnit × rewardRiskRatio` dall'entry, nella direzione del trade (sopra per i long, sotto per gli short). `rewardRiskRatio` è un parametro del costruttore di `RiskManager` (default `2.0m` se non specificato), passato da `Program.cs`/`BotSchedulerService`/`BacktestService` con il valore configurato (oggi `3.0`, vedi §2, §6, §11.2) — questo è il target effettivamente usato per aprire le posizioni, **non** il target 2:1 calcolato internamente dalla strategia (§5.1, puramente indicativo).
  - Verifica che il numero di trade aperti (`openTrades.Count`) sia sotto `MaxConcurrentTrades` (costante hardcoded, 100); rigetta se raggiunto.
  - Calcola comunque un'esposizione totale/leva (`LeverageRatio`) come indicatore puramente informativo — non blocca più il trade. Nota: la formula somma il prezzo di entrata grezzo dei trade aperti (`t.EntryPrice * 1`), non il valore reale della posizione (questo calcolo pre-esiste all'introduzione di `Trade.PositionSize`, §4), quindi questo numero non è una leva finanziaria affidabile.
  - Verifica che il profitto atteso netto (dopo commissioni doppie entry+exit) sia positivo.
  - Verifica che il rapporto rischio/rendimento effettivo sia ≥ 1.2; altrimenti rigetta.
  - Ritorna `PositionSizingResult` con size, stop/target, rischio, profitto atteso, leva (informativa), commissioni e motivazione.
- **`CalculateProfitAndTaxes(entryPrice, exitPrice, positionSize, isWinningTrade, isLong = true)`**: calcola P&L lordo (per gli short il segno è invertito: si guadagna quando il prezzo scende), commissioni (entry+exit), tasse (26% solo sui profitti netti positivi), profitto finale netto. Usato sia dal backtest reale sia dalla chiusura automatica dei paper trade nel ciclo live (§6).
- **`CalculatePerformanceMetrics(trades, initialCapital)`**: calcola su tutti i trade chiusi — win rate, profit factor, ROI, expectancy, medie win/loss, massime serie consecutive di vittorie/sconfitte, commissioni totali. `ROI` usa direttamente `TotalProfit / initialCapital`. Il campo `TotalCommissions` usa una formula semplificata (`EntryPrice * 1`, non la position size reale) e non va considerato affidabile; `BacktestService` non lo usa nel proprio report (calcola le tasse separatamente, vedi §11.2).

Commissioni configurate per lato: **0.25%** sia nel ciclo live (`BotSchedulerService`) sia nel backtest reale (`BacktestService`); il backtest sintetico (`SyntheticBacktest`) usa invece **0.6%** (vedi §14).

## 9. Notifiche (`Services/NotificationService.cs`)

Canali di notifica per ogni segnale generato (solo due, dopo la rimozione di toast desktop e email):

1. **Log su file** — `Logs/signals_yyyy-MM-dd.log`, con timestamp UTC esplicito.
2. **Console** — output colorato (verde per BUY, rosso per SELL) con tutti gli indicatori, più un beep.

Le notifiche toast Windows (`Windows.UI.Notifications` via script PowerShell) e le notifiche email (SMTP) sono state rimosse insieme alla relativa configurazione: la sezione `Notifications` non esiste più in `appsettings.json`, e la classe non legge più variabili d'ambiente `ENABLE_EMAIL_ALERTS`/`SMTP_*`/`EMAIL_*`. `SendNotificationAsync` ora si limita a log su file + console, ed è chiamata solo all'**apertura** di un segnale/trade; la chiusura di un paper trade (stop/target) viene loggata separatamente da `ReportingService` (vedi §10), non tramite `NotificationService`.

## 10. Persistenza e reportistica (`Services/ReportingService.cs`)

- Mantiene la lista dei trade in memoria, sincronizzata su file `Data/trades.json` (serializzazione con Newtonsoft.Json).
- `RecordTrade(symbol, entryPrice, strategy, isLong, stopLoss, targetPrice, positionSize, signalCandleTime)` — crea un nuovo `Trade` **aperto e gestito dal paper trading** (`IsPaperManaged = true`, perché `positionSize > 0`), con direzione, livelli di uscita, dimensione e timestamp della candela di segnale già impostati: tutto ciò che serve a `BotSchedulerService` per chiuderlo automaticamente su stop/target (§6).
- `ClosePaperTrade(trade, exitPrice, profit, profitPercentage, exitReason)` — chiude un trade paper trading già aperto: imposta `ExitPrice`, `CloseTime`, `Status = "Closed"`, `Profit`/`ProfitPercentage` (calcolati esternamente da `RiskManager.CalculateProfitAndTaxes`, al netto di commissioni, prima delle tasse) ed `ExitReason` (`"Stop loss"` o `"Target"`), poi logga l'operazione.
- `CloseTradeAsync(symbol, exitPrice)` — **metodo legacy**, chiude il primo trade aperto per il simbolo con la formula semplice `exitPrice - entryPrice`, senza gestire commissioni, tasse, né la direzione long/short: per un trade short il segno del profitto risulterebbe invertito rispetto alla realtà. Non più invocato dal ciclo live automatico (sostituito da `ClosePaperTrade`/`CloseTradesAtStopOrTargetAsync`, §6), rimasto per compatibilità.
- `LogClosedTrade(trade)` — scrive un log dettagliato dell'operazione chiusa in `Logs/Operazioni_chiuse.log`; se `trade.IsPaperManaged`, include anche direzione, stop/target e motivo di uscita.
- `GenerateWeeklyReport()` — produce un report testuale (statistiche generali, performance, elenco trade aperti/chiusi della settimana corrente) stampato in console e salvato in `Data/Reports/Weekly_Report_yyyy-MM-dd.txt`. Considera solo i trade `IsPaperManaged` (i trade storici pre-paper-trading, se presenti in `Data/trades.json`, vengono esclusi).
- `GetAllTrades()` — espone la lista completa dei trade per il calcolo metriche nello scheduler.

## 11. Backtest

### 11.1 `Services/SyntheticBacktest.cs` (usato da `Program.cs` in modalità `--backtest`)

Genera trade **simulati statisticamente** (non basati su dati di mercato reali):
- Per ogni combinazione simbolo/trade, genera un prezzo di entrata casuale, decide se vincente in base al `expectedWinRate` fornito, quindi calcola un'uscita con profitto (1-6%) o perdita (0.5-3%) casuale entro range coerenti con SL/TP configurati.
- Distribuisce le date di apertura/chiusura casualmente entro il periodo richiesto (default 365 giorni, seed `Random(42)` per riproducibilità).
- Calcola le metriche con `RiskManager.CalculatePerformanceMetrics` e stampa un report esteso (ROI annualizzato, top 5 win/loss, validazione rispetto a soglie 50%/55% di win-rate), salvato in `Data/Reports/Backtest_Synthetic_*.txt`.
- Istanzia un proprio `RiskManager` con parametri diversi da quelli usati in live/backtest reale (§6, §11.2): rischio 1% per trade (contro 2%) e commissioni 0.6% (contro 0.25%). Il report stampa inoltre l'etichetta "Commissioni (0.1%)", disallineata sia dal valore realmente configurato qui (0.6%) sia da quello usato altrove (0.25%).

### 11.2 `Services/BacktestService.cs` (invocabile da `Program.cs` con `--backtest-real`, vedi §2 per tutte le opzioni CLI)

Backtest reale su **dati storici veri** scaricati da `CryptoDataService.GetHistoricalCandlesAsync` (Crypto.com/Bybit), che esegue effettivamente `EmaRibbonTrendFollowingStrategy` e `RiskManager` in una **simulazione di portafoglio cronologica e condivisa tra tutti i simboli**:

- Costruttore `BacktestService(initialCapital, maxTradeAmount, rewardRiskRatio = 2.0m)`: istanzia un proprio `RiskManager` con rischio 2% (allineato al live) e commissioni 0.25% per lato (allineate al live, §8); capitale iniziale, importo massimo per trade e R:R sono passati da `Program.cs` (oggi €150, €10, `3.0`, configurabili da riga di comando con `--capital`/`--rr`, vedi §2).
- `TimeframeToTimeSpan(timeframe)` — metodo statico pubblico che mappa una stringa timeframe (`1h, 2h, 6h, 12h, 1d`, default `4h` per valori non riconosciuti) alla durata corrispondente; riutilizzato anche da `BotSchedulerService` (§6) per sapere quando una candela è chiusa.
- **Preparazione dati**: scarica lo storico di BTC (per il regime, vedi §5.1) e di ogni simbolo richiesto da `startDate - warmup` fino a `endDate`, dove il warmup è il massimo tra 20 giorni (`MinWarmupDays`) e `(WarmupCandles(60) + 60) × durata del timeframe` (es. su timeframe `1d` corrisponde a 120 giorni); scarta i simboli con meno di `WarmupCandles(60) + 20` candele disponibili. Il regime BTC viene precalcolato per ogni timestamp della serie storica di BTC (finestra delle ultime 300 candele fino a quel punto, `Window()`).
- **Timeline unica**: costruisce un'unica sequenza ordinata cronologicamente di tutti i timestamp di candela (di tutti i simboli, oltre il warmup) fino a `endDate`, e la percorre in ordine temporale (non simbolo per simbolo), così da sapere in ogni istante quanto capitale è già impegnato in posizioni aperte su altri simboli.
- Ad ogni timestamp della timeline:
  1. **Gestione posizioni aperte** — per ogni posizione aperta, verifica se la candela di quel simbolo in quell'istante ha toccato stop loss o target (se entrambi nella stessa candela, assume lo stop loss, ipotesi conservativa) e la chiude con `RiskManager.CalculateProfitAndTaxes()` (gestendo correttamente long/short).
  2. **Nuovi segnali** (solo per candele dentro `[startDate, endDate]`) — per ogni simbolo senza posizione aperta, chiama `EmaRibbonTrendFollowingStrategy.Analyze()` sulla finestra storica fino a quel punto (mai dati futuri, massimo 300 candele di lookback). I segnali generati nello stesso istante vengono ordinati dal `SignalStrength` più alto al più basso: a parità di capitale limitato, entrano prima i segnali più forti.
  3. Per ogni segnale candidato, `RiskManager.CalculatePosition()` dimensiona il trade (stop loss/target reali della strategia, con l'R:R configurato); se il valore nozionale della nuova posizione sommato al capitale già impegnato (`committed`) supera l'equity corrente (`_initialCapital + P&L realizzato`), il segnale viene scartato per mancanza di capitale (**nessuna leva**: non si apre mai una posizione che non sia coperta da capitale libero) e conteggiato in `SignalsSkippedForCapital`.
  4. **Drawdown** — ad ogni timestamp calcola l'equity a valore di mercato (P&L realizzato + non realizzato sulle posizioni ancora aperte, valutate al prezzo di chiusura più recente) e aggiorna il drawdown massimo rispetto al picco di equity osservato.
- Le posizioni ancora aperte a fine periodo vengono chiuse (mark-to-market) al prezzo dell'ultima candela disponibile entro `endDate`, invece di essere scartate dalle metriche: altrimenti P&L non realizzati (vincenti o perdenti) sparirebbero dal report.
- **Tasse**: applicate **una sola volta sul saldo netto del periodo** (somma di tutti i `Trade.Profit`, già al netto delle commissioni ma lordi di tasse) nel report finale, non per singolo trade vincente — più realistico per la tassazione italiana sulle plusvalenze crypto, dove le minusvalenze compensano le plusvalenze nello stesso periodo. Nota: `result.Metrics.ROI` (calcolato da `RiskManager.CalculatePerformanceMetrics`) resta quindi **lordo di tasse**; il report stampa invece un "ROI netto" ricalcolato separatamente (`netPnl / InitialCapital`) che tiene conto delle tasse — i due valori non coincidono e vanno letti nel contesto giusto.
- Un solo trade aperto per simbolo alla volta.
- Genera un report con: copertura analisi (simboli con dati sufficienti, segnali generati/scartati dal RiskManager, segnali scartati per capitale insufficiente, massimo di posizioni aperte contemporaneamente), P&L al netto delle commissioni, tasse, P&L netto, ROI netto, capitale finale, drawdown massimo, metriche di performance (win rate, profit factor, expectancy, serie consecutive), e un **dettaglio mensile** (trade, win rate, P&L per mese di chiusura) quando il periodo copre più di un mese — salvato in `Data/Reports/Backtest_Report_*.txt`.
- **Nota**: le API di Crypto.com/Bybit restituiscono solo le candele più recenti fino ad "adesso" quando non si specifica un intervallo, ma `GetHistoricalCandlesAsync` pagina a ritroso nel tempo (§7), quindi il backtest reale può testare anche periodi storici arbitrari nel passato tramite `--backtest-real yyyy-MM-dd yyyy-MM-dd`, non solo "gli ultimi N giorni".
- `Program.cs` supporta inoltre `--symbols <file>`: se il file esiste, i simboli vengono letti da lì invece che scaricati da `CryptoDataService` (utile per ripetere più backtest — es. a timeframe o R:R diversi — esattamente sullo stesso paniere di simboli); se non esiste, l'elenco scaricato viene salvato in quel file per i run successivi.

## 12. Configurazione

### 12.1 `appsettings.json` / `appsettings.local.json`

Sezioni presenti nel file: `CryptoExchange`, `TradingSettings`, `MarketMonitoring`, `Logging`. Nessuna di queste sezioni è effettivamente letta dal codice: sono documentative/predisposte per uso futuro (i parametri realmente attivi restano quelli hardcoded nelle classi o passati da `Program.cs`, vedi §14). La sezione `Notifications` (letta in precedenza da `NotificationService` per email/toast) è stata rimossa insieme al codice che la consumava (§9).

### 12.2 `config.json`

File di configurazione "di progetto" con schema più ampio (strategie, risk management, reporting, storage, API, ottimizzazioni) — **non referenziato da alcuna classe C#** nel codice attuale. Da considerare come specifica/riferimento per future estensioni, non come sorgente di configurazione runtime: ad esempio dichiara `volumeMultiplierThreshold: 1.2`, `commissionsPercent: 0.8`, `riskPerTrade: 0.01`, `candleTimeframe: "4h"`, `rewardRiskRatio: 2.0`, nessuno dei quali corrisponde ai valori realmente usati nel codice (rispettivamente 1.5, 0.25%, 2%, `"12h"` e 3.0 in live/backtest reale, vedi §5.1, §2, §6, §8). L'unico valore che oggi coincide per coincidenza è `account.initialCapital: 150`, uguale alla costante `InitialCapital` in `Program.cs` (vedi §2) — ma il file resta comunque non letto dal codice, quindi va aggiornato manualmente a mano se si cambia il capitale in uno dei due posti. Anche la soglia minima di volume 24h usata dal filtro CoinGecko (§7) è hardcoded in `CryptoDataService` (`MinVolume24hUsd = $2.000.000`) e non proviene da questo file.

## 13. Dipendenze principali (`1 - Bot Cripto.csproj`)

- Target framework: `.NET 10.0`, `Nullable` e `ImplicitUsings` abilitati.
- `Newtonsoft.Json` 13.0.4 — serializzazione JSON (trade, risposte API).
- Nessun pacchetto di compatibilità aggiuntivo: `System.Net.Http` e `System.Runtime.InteropServices` (necessari sotto .NET 8) sono stati rimossi nel porting a .NET 10 perché superati dal runtime moderno.

## 14. Limitazioni note / debito tecnico osservato nel codice

- `config.json` non è cablato al codice: i parametri realmente attivi sono quelli hardcoded nelle classi o passati come argomenti da `Program.cs` (`EmaRibbonTrendFollowingStrategy`, `BotSchedulerService`, `BacktestService`, `RiskManager`), e alcuni di essi (volume threshold, commissioni, rischio per trade, timeframe, R:R) sono anche diversi dai valori dichiarati in `config.json` (vedi §12.2).
- Il target `2:1` calcolato internamente da `EmaRibbonTrendFollowingStrategy.Analyze()` (§5.1) è puramente indicativo: viene sempre sovrascritto dal target reale calcolato da `RiskManager.CalculatePosition()` con l'R:R configurato (oggi `3.0`). Chi legge `AnalysisResult.Indicators["Target"]` prima che passi per `RiskManager` (es. in log di debug) vedrebbe quindi un valore diverso da quello realmente usato per aprire la posizione.
- I livelli RSI di ipercomprato/ipervenduto dichiarati come campo (`70/30`) non corrispondono alle soglie realmente applicate nei controlli di rigetto (`85/15`).
- Il filtro di volume 24h (§7) dipende da CoinGecko, un terzo provider aggiuntivo rispetto a Crypto.com/Bybit già usati per prezzi e candele: se CoinGecko è irraggiungibile o applica rate limiting, il filtro viene silenziosamente disattivato per il ciclo (nessun retry, nessun backoff), quindi in quel ciclo possono passare anche crypto poco scambiate.
- Il rischio e le commissioni usati da `SyntheticBacktest` (§11.1) — 1% e 0.6% — non coincidono con quelli usati realmente in live/backtest reale (2% e 0.25%, §6, §11.2): i suoi risultati non sono quindi direttamente comparabili con il comportamento attuale del bot. `SyntheticBacktest` mostra inoltre un'etichetta "Commissioni (0.1%)" nel report che non riflette nessuno dei due valori realmente configurati.
- Il controllo "numero massimo di trade simultanei" (§8) usa una soglia fissa (`MaxConcurrentTrades = 100`) uguale per tutti gli account, indipendente dal capitale configurato: con un capitale di €150 e un importo massimo di €10 per trade (vedi §2, §8), il vero limite pratico resta il capitale libero/profitto minimo-commissioni, non questo contatore (che non scatterebbe praticamente mai a questi importi).
- Nel backtest reale (§11.2), `result.Metrics.ROI` resta calcolato al lordo delle tasse (la tassazione viene applicata solo nel report stampato, sul saldo netto del periodo): chi legge `BacktestResult.Metrics` programmaticamente invece che tramite `PrintBacktestReport` otterrebbe un ROI diverso (più alto) da quello mostrato in console.
- `ReportingService.CloseTradeAsync` (§10) resta nel codice come metodo legacy non più invocato dal ciclo live: il suo calcolo di P&L non gestisce short/commissioni/tasse e produrrebbe un valore errato se richiamato su un trade gestito dal paper trading.
- La leva informativa (`LeverageRatio`, §8) e il campo `TotalCommissions` di `CalculatePerformanceMetrics` (§8) usano entrambi una formula semplificata basata su `EntryPrice * 1` invece della position size reale del trade: restano indicatori non affidabili, anche ora che `Trade.PositionSize` esiste ed è popolato correttamente dal paper trading (§4, §6).
