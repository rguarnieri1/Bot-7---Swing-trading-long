using BotCripto.Models;

namespace BotCripto.Strategies;

// Swing trading long-only su candele chiuse (timeframe configurato, tipicamente 1d):
//  1) trend di fondo rialzista: Close > EMA50 e EMA20 > EMA50 con EMA50 in salita
//  2) ritracciamento: nelle ultime candele l'RSI14 è sceso sotto RsiPullback e il minimo ha toccato l'EMA20
//  3) ripartenza: candela rialzista che chiude sopra l'EMA20 e sopra il massimo della candela precedente,
//     RSI in crescita e non ipercomprato
// Stop loss sotto il minimo dello swing recente (meno un buffer ATR); il target lo calcola il RiskManager (R:R configurato).
public class SwingTradingLongStrategy
{
    private const int FastEma = 20;
    private const int SlowEma = 50;
    private const int PullbackLookback = 5;      // candele entro cui deve essere avvenuto il ritracciamento
    private const int SwingLookback = 10;        // candele per il minimo dello swing (stop)
    private const int AtrPeriod = 14;
    private const decimal AtrStopBuffer = 0.5m;  // buffer sotto lo swing, in ATR
    private const decimal RsiMax = 70m;
    private const decimal MaxStopPercent = 0.15m; // stop più largo del 15% = setup scartato
    public const int MinCandles = SlowEma + 20;

    // Candele minime di BTC per valutare il regime (EMA lenta + qualche candela per la pendenza della EMA50)
    public static int BtcRegimeMinCandles => StrategyOptions.BtcRegimeEma + 5;

    // Regime di mercato: true se BTC chiude sopra la EMA lenta (default EMA200) e la EMA50 è in salita,
    // false altrimenti, null se i dati sono insufficienti.
    public static bool? IsBtcBullish(List<Candle> btcCandles)
    {
        var closes = btcCandles.Select(c => c.Close).ToList();
        var slow = TechnicalIndicators.CalculateEMA(closes, StrategyOptions.BtcRegimeEma);
        var mid = TechnicalIndicators.CalculateEMA(closes, SlowEma);
        if (slow.Count == 0 || mid.Count < 6)
            return null;
        return closes.Last() > slow.Last() && mid.Last() > mid[mid.Count - 6];
    }

    // Per la breadth di mercato: true se la moneta chiude sopra la propria EMA50, null se dati insufficienti.
    public static bool? IsAboveEma50(List<Candle> candles)
    {
        var ema = TechnicalIndicators.CalculateEMA(candles.Select(c => c.Close).ToList(), SlowEma);
        if (ema.Count == 0)
            return null;
        return candles.Last().Close > ema.Last();
    }

    // Quota di monete sopra la propria EMA50; null se le monete valutabili sono troppo poche.
    public static decimal? CalculateBreadth(IEnumerable<List<Candle>> candlesPerSymbol)
    {
        int above = 0, total = 0;
        foreach (var candles in candlesPerSymbol)
        {
            var a = IsAboveEma50(candles);
            if (a == null) continue;
            total++;
            if (a.Value) above++;
        }
        return total >= StrategyOptions.MinBreadthSamples ? (decimal)above / total : null;
    }

    // btcBullish: filtro di mercato, il long è consentito solo con BTC rialzista (sopra la EMA50).
    public AnalysisResult Analyze(string symbol, List<Candle> candles, bool? btcBullish)
    {
        var result = new AnalysisResult
        {
            Symbol = symbol,
            StrategyName = "Swing Trading Long",
            IsSignal = false,
            Signal = "No Signal",
            AnalysisTime = DateTime.UtcNow
        };

        if (candles.Count < MinCandles)
        {
            result.Rejection = RejectionReason.InsufficientData;
            return result;
        }

        var closes = candles.Select(c => c.Close).ToList();
        var ema20 = TechnicalIndicators.CalculateEMA(closes, FastEma);
        var ema50 = TechnicalIndicators.CalculateEMA(closes, SlowEma);
        var rsi = TechnicalIndicators.CalculateRSI(closes);
        if (ema20.Count < PullbackLookback + 1 || ema50.Count < 6 || rsi.Count < PullbackLookback + 2)
        {
            result.Rejection = RejectionReason.InsufficientData;
            return result;
        }

        var last = candles.Last();
        var prev = candles[candles.Count - 2];
        result.CurrentPrice = last.Close;

        // Le serie sono allineate alla fine: l'indice i-esimo dalla fine corrisponde alla candela i-esima dalla fine
        decimal E20(int back) => ema20[ema20.Count - 1 - back];
        decimal E50(int back) => ema50[ema50.Count - 1 - back];
        decimal Rsi(int back) => rsi[rsi.Count - 1 - back];

        var e20 = E20(0);
        var e50 = E50(0);
        result.Indicators["EMA20"] = e20;
        result.Indicators["EMA50"] = e50;

        // 0) Regime BTC
        if (btcBullish != true)
        {
            result.Rejection = RejectionReason.AgainstBtcRegime;
            return result;
        }

        // 1) Trend di fondo
        if (!(last.Close > e50 && e20 > e50 && e50 > E50(5)))
        {
            result.Rejection = RejectionReason.TrendNotAligned;
            return result;
        }

        // 2) Ritracciamento recente: minimo sull'EMA20 (ma sopra l'EMA50) e RSI sceso sotto soglia
        bool pullback = false;
        for (int back = 1; back <= PullbackLookback; back++)
        {
            var c = candles[candles.Count - 1 - back];
            if (c.Low <= E20(back) && c.Low >= E50(back) * 0.97m && Rsi(back) < StrategyOptions.RsiPullback)
            {
                pullback = true;
                break;
            }
        }
        if (!pullback)
        {
            result.Rejection = RejectionReason.NoBreakout;
            return result;
        }

        // 3) Ripartenza: candela rialzista sopra EMA20 e sopra il massimo precedente, RSI in crescita ma non ipercomprato
        var rsiNow = Rsi(0);
        result.Indicators["RSI"] = rsiNow;
        bool reversal = last.Close > last.Open && last.Close > e20 && last.Close > prev.High;
        if (!reversal || rsiNow > RsiMax || rsiNow <= Rsi(1))
        {
            result.Rejection = RejectionReason.RsiExtreme;
            return result;
        }

        // 4) Volume: la candela di ripartenza deve avere volume superiore alla media delle 20 precedenti
        if (StrategyOptions.RequireVolume)
        {
            var avgVolume = candles.Skip(candles.Count - 1 - StrategyOptions.VolumeLookback).Take(StrategyOptions.VolumeLookback).Average(c => c.Volume);
            if (avgVolume <= 0)
            {
                result.Rejection = RejectionReason.NoVolumeData;
                return result;
            }
            if (last.Volume <= avgVolume * StrategyOptions.VolumeMultiplier)
            {
                result.Rejection = RejectionReason.VolumeInsufficient;
                return result;
            }
        }

        // Stop sotto lo swing low recente, con buffer ATR
        var atr = CalculateAtr(candles, AtrPeriod);
        var swingLow = candles.Skip(candles.Count - SwingLookback).Min(c => c.Low);
        var stop = swingLow - atr * AtrStopBuffer;
        if (stop <= 0 || stop >= last.Close || (last.Close - stop) / last.Close > MaxStopPercent)
        {
            result.Rejection = RejectionReason.StopLossError;
            return result;
        }

        result.IsSignal = true;
        result.Signal = "BUY";
        result.Indicators["StopLoss"] = stop;
        result.Indicators["ATR"] = atr;
        // Più forte = trend più marcato (distanza EMA20 da EMA50) e ripartenza più decisa (RSI)
        result.Indicators["SignalStrength"] = (e20 - e50) / e50 * 100m + rsiNow / 10m;
        return result;
    }

    private static decimal CalculateAtr(List<Candle> candles, int period)
    {
        var trs = new List<decimal>();
        for (int i = candles.Count - period; i < candles.Count; i++)
        {
            var c = candles[i];
            var prevClose = candles[i - 1].Close;
            trs.Add(Math.Max(c.High - c.Low, Math.Max(Math.Abs(c.High - prevClose), Math.Abs(c.Low - prevClose))));
        }
        return trs.Average();
    }
}
