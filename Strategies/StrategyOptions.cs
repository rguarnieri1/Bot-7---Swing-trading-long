namespace BotCripto.Strategies;

// Parametri della strategia modificabili senza ricompilare (nel backtest tramite flag da riga di comando,
// vedi Program.cs). I valori predefiniti sono quelli usati anche dal bot live.
public static class StrategyOptions
{
    // RSI14 deve essere sceso sotto questa soglia durante il ritracciamento.
    // Backtest 4 anni: 50 → 160 trade; 45 → solo 8 trade; 40 → 0 trade (troppo restrittivo).
    public static decimal RsiPullback = 50m;

    // Richiede che il volume della candela di ripartenza superi la media delle 20 candele precedenti
    public static bool RequireVolume = true;
    // Volume minimo della candela di ripartenza come multiplo della media (1 = sopra la media)
    public static decimal VolumeMultiplier = 1.5m;
    public const int VolumeLookback = 20;

    // Regime BTC: chiusura sopra questa EMA e EMA50 in salita (prima: solo chiusura sopra EMA50)
    public static int BtcRegimeEma = 200;

    // Breadth: quota minima di monete del paniere sopra la propria EMA50 per aprire nuovi long (0 = filtro disattivato)
    public static decimal MinBreadth = 0.55m;
    public const int MinBreadthSamples = 10; // sotto questo numero di monete valutabili la breadth non è affidabile

    // Massimo di nuovi segnali per candela/ciclo: si prendono i più forti per SignalStrength (0 = nessun limite)
    public static int MaxSignalsPerCycle = 8;

    // Uscita a tempo: chiude al prezzo di chiusura dopo N candele se stop e target non sono stati toccati (0 = disattivata)
    // Backtest 4 anni (1d): 3 candele → winrate 53%, P&L €5; 5 → 58,5%, €13,7; 10 → 44,6%, €12,4; nessuna → 42,9%, €14,9.
    public static int MaxHoldCandles = 5;

    // Dopo che il prezzo ha raggiunto +N volte il rischio iniziale lo stop viene portato al prezzo di ingresso (0 = disattivato)
    public static decimal BreakevenAtR = 1.0m;
}
