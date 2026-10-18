# 📧 Configurazione Email Alerts - Tutti i Bot

## ✅ Stato

Email alerts sono **ABILITATE** su:
- ✅ Bot 1 - Bot Cripto
- ✅ Bot 2 - Bot Sma - Crypto
- ✅ Bot 3 - ERTF Ita

---

## 🔧 Configurazione Rapida

### Step 1: Generare App Password Gmail

1. Accedi a [Google Account](https://myaccount.google.com/)
2. Vai a **Security** → **App passwords**
3. Seleziona **Mail** e **Windows Computer**
4. Copia la password generata (16 caratteri)

### Step 2: Impostare Variabili di Ambiente

Crea un file `.env` nella cartella di ogni bot oppure imposta variabili di ambiente Windows:

**Windows - Variabili di Sistema:**
```bash
setx ENABLE_EMAIL_ALERTS "true"
setx SMTP_SERVER "smtp.gmail.com"
setx SMTP_PORT "587"
setx EMAIL_FROM "roberto.guarnieri2@gmail.com"
setx EMAIL_APP_PASSWORD "YOUR_16_CHAR_PASSWORD"
setx EMAIL_TO "roberto.guarnieri2@gmail.com"
setx EMAIL_ON_SIGNAL "true"
setx EMAIL_ON_TRADE "true"
setx EMAIL_ON_ERROR "true"
```

**Oppure nel file appsettings.json:**
```json
"Notifications": {
  "EnableEmailAlerts": true,
  "EmailSmtpServer": "smtp.gmail.com",
  "EmailSmtpPort": 587,
  "EmailFrom": "roberto.guarnieri2@gmail.com",
  "EmailToAddresses": ["roberto.guarnieri2@gmail.com"],
  "EmailAppPassword": "YOUR_16_CHAR_PASSWORD",
  "EmailAlertOnSignal": true,
  "EmailAlertOnTrade": true,
  "EmailAlertOnError": true
}
```

### Step 3: Verificare Configurazione

Avvia uno qualsiasi dei bot:
```bash
dotnet run
```

Dovresti vedere:
```
✉️  Email inviata a roberto.guarnieri2@gmail.com
```

---

## 📬 Cosa Riceverai

### 1. **Segnali di Trading** 🎯
```
Oggetto: 🤖 BotCripto: BUY - BTC

Riceverai email con:
- Criptovaluta/Titolo
- Azione (BUY/SELL)
- Prezzo attuale
- Indicatori tecnici
- Strategia utilizzata
```

### 2. **Trade Chiusi** ✅/❌
```
Oggetto: 🤖 BotCripto: Trade Chiuso - BTC

Con:
- P&L (Profit & Loss)
- Percentuale di profitto/perdita
- Prezzo di ingresso/uscita
```

### 3. **Errori** ⚠️
```
Se EnableEmailOnError = true
```

---

## 🔐 Sicurezza

### ⚠️ IMPORTANTE

**NON usare mai la tua password Gmail reale!**

Usa sempre una **App Password** generata da Google:
1. Abilita 2-Factor Authentication
2. Genera una App Password (16 caratteri)
3. Usa quella password nella configurazione

### Credenziali Sicure

Opzioni (in ordine di preferenza):

**1️⃣ Variabili d'Ambiente (CONSIGLIATO)**
```bash
setx EMAIL_APP_PASSWORD "your_app_password"
```

**2️⃣ File .env (locale, non committare!)**
```
ENABLE_EMAIL_ALERTS=true
EMAIL_APP_PASSWORD=your_app_password
```

**3️⃣ appsettings.local.json**
```json
{
  "Notifications": {
    "EmailAppPassword": "your_app_password"
  }
}
```

---

## 🧪 Test Email

Per testare la configurazione, puoi creare un segnale manuale:

```csharp
var testResult = new AnalysisResult
{
    Symbol = "BTC",
    Signal = "BUY",
    CurrentPrice = 98765.43m,
    StrategyName = "Test Strategy",
    AnalysisTime = DateTime.UtcNow,
    Indicators = new Dictionary<string, decimal>
    {
        { "EMA5", 98765.12m },
        { "EMA10", 98760.00m }
    }
};

var notificationService = new NotificationService();
await notificationService.SendNotificationAsync(testResult);
```

---

## 🐛 Troubleshooting

### ❌ "Email alerts disabilitati: credenziali mancanti"

**Soluzione:**
```bash
# Verifica che le variabili siano impostate
echo %EMAIL_FROM%
echo %EMAIL_APP_PASSWORD%

# Se vuoti, impostali:
setx EMAIL_FROM "roberto.guarnieri2@gmail.com"
setx EMAIL_APP_PASSWORD "your_16_char_app_password"

# Riavvia il bot
```

### ❌ "The SMTP server requires a secure connection"

**Soluzione:**
- Assicurati che `EmailSmtpPort` = `587`
- Assicurati che `EnableSsl` = `true` (già impostato nel codice)

### ❌ "Invalid username or password"

**Soluzione:**
- Verifica di aver usato una **App Password**, non la password Gmail
- Controlla che non ci siano spazi prima/dopo la password
- Genera una nuova App Password

### ❌ Non ricevo email

**Checklist:**
1. ✓ Email alerts abilitati in appsettings.json?
2. ✓ Credenziali corrette?
3. ✓ App Password di Google (non password account)?
4. ✓ Email Gmail ha accesso da app meno sicure? (Google gestisce questo con App Passwords)
5. ✓ Controlla cartella **Spam**

---

## 📊 Configurazione per Bot

### Bot 1 - Bot Cripto
- **File config**: `appsettings.json`
- **Stato**: ✅ Email alerts abilitati
- **Strategia**: EMA Ribbon Trend Following + Bullish Divergence

### Bot 2 - Bot Sma - Crypto
- **File config**: `appsettings.json`
- **Stato**: ✅ Email alerts abilitati
- **Strategia**: SMA Strategy

### Bot 3 - ERTF Ita
- **File config**: `appsettings.json`
- **Stato**: ✅ Email alerts abilitati
- **Source**: Interactive Brokers (Mercato Italiano)
- **Strategia**: EMA Ribbon Trend Following

---

## 🚀 Best Practices

1. **Test prima di usare in produzione**
   - Avvia il bot in modalità test
   - Verifica che ricevi almeno un'email di test

2. **Filtra le email**
   - Usa Gmail filters per categorizzare i segnali
   - Crea cartelle: "Bot Signals", "Bot Trades", "Bot Errors"

3. **Notifiche Push aggiuntive**
   - Gmail push notifications sul cellulare
   - Configura Gmail per notificare su email importanti

4. **Monitora Performance**
   - Tieni traccia di quanti segnali ricevi
   - Verifica la qualità dei segnali (% corretti)

---

## 📝 Variabili di Ambiente Disponibili

| Variabile | Default | Descrizione |
|-----------|---------|-------------|
| `ENABLE_EMAIL_ALERTS` | false | Abilita invio email |
| `SMTP_SERVER` | smtp.gmail.com | Server SMTP |
| `SMTP_PORT` | 587 | Porta SMTP |
| `EMAIL_FROM` | - | Email mittente |
| `EMAIL_APP_PASSWORD` | - | App password Gmail |
| `EMAIL_TO` | - | Email destinatario (separati da ;) |
| `EMAIL_ON_SIGNAL` | true | Invia email su segnali |
| `EMAIL_ON_TRADE` | true | Invia email su trade chiusi |
| `EMAIL_ON_ERROR` | true | Invia email su errori |

---

**Ultimo aggiornamento**: 2026-09-08  
**Status**: ✅ Pronto per uso
