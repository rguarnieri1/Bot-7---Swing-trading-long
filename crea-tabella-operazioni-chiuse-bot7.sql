-- Tabella bot7.bot7_operazioni_chiuse nel database "bot", corrispondente al file Logs/Operazioni_chiuse.log
-- del Bot 7 (ReportingService.LogClosedTrade): una riga per ogni blocco "OPERAZIONE CHIUSA".
-- Lo script non modifica la tabella se esiste già.
IF DB_ID(N'bot') IS NULL
    CREATE DATABASE [bot];
GO
USE [bot];
GO
IF SCHEMA_ID(N'bot7') IS NULL
    EXEC(N'CREATE SCHEMA [bot7]');
GO
IF OBJECT_ID(N'bot7.bot7_operazioni_chiuse', N'U') IS NULL
BEGIN
    CREATE TABLE [bot7].[bot7_operazioni_chiuse] (
        [Id]               bigint IDENTITY(1,1) NOT NULL,
        [TradeId]          nvarchar(36)    NOT NULL, -- "ID": bot7.bot7_trades.Id dell'operazione chiusa
        [Symbol]           nvarchar(50)    NULL,     -- "Simbolo"
        [Strategy]         nvarchar(200)   NULL,     -- "Strategia"
        [IsLong]           bit             NOT NULL, -- "Direzione": 1 = LONG, 0 = SHORT
        [StopLoss]         decimal(38, 18) NULL,     -- "Stop Loss"
        [TargetPrice]      decimal(38, 18) NULL,     -- "Target"
        [ExitReason]       nvarchar(100)   NULL,     -- "Motivo uscita", es. Stop loss / Target
        [EntryPrice]       decimal(38, 18) NOT NULL, -- "Prezzo Entrata"
        [ExitPrice]        decimal(38, 18) NULL,     -- "Prezzo Uscita"
        [Profit]           decimal(38, 18) NULL,     -- "Profitto" (EUR, netto commissioni)
        [ProfitPercentage] decimal(38, 18) NULL,     -- "Percentuale"
        [Status]           nvarchar(20)    NULL,     -- "Stato", es. Closed
        [OpenTime]         datetime2       NOT NULL, -- "Apertura" (UTC)
        [CloseTime]        datetime2       NULL,     -- "Chiusura" (UTC)
        [Bot]              nvarchar(50)    NOT NULL CONSTRAINT [DF_bot7_operazioni_chiuse_Bot] DEFAULT (N'Bot 7'), -- bot che ha scritto la riga
        CONSTRAINT [PK_bot7_operazioni_chiuse] PRIMARY KEY ([Id])
    );
    CREATE INDEX [IX_bot7_operazioni_chiuse_TradeId] ON [bot7].[bot7_operazioni_chiuse] ([TradeId]);
    CREATE INDEX [IX_bot7_operazioni_chiuse_CloseTime] ON [bot7].[bot7_operazioni_chiuse] ([CloseTime]);
    PRINT 'Tabella bot7.bot7_operazioni_chiuse creata';
END
ELSE
    PRINT 'Tabella bot7.bot7_operazioni_chiuse gia esistente: nessuna modifica';
GO
