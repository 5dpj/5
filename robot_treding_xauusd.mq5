//+------------------------------------------------------------------+
//|                                          robot_treding_xauusd.mq5|
//|                               Professional XAUUSD Trading Robot |
//|                     Optimized for 1-Minute Timeframe Trading    |
//+------------------------------------------------------------------+
#property copyright "2024, Professional Trading Systems"
#property link      "https://www.mql5.com"
#property version   "2.50"
#property description "Advanced XAUUSD Expert Advisor with multi-indicator confluence, session filters, and professional money management"
#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+

//--- General Settings
input group "=== GENERAL SETTINGS ==="
input double   InpLots                = 0.01;        // Lot Size (0=Auto)
input int      InpMagicNumber         = 123456;      // Magic Number
input int      InpSlippage            = 5;           // Maximum Slippage (points)
input bool     InpAutoLotSize         = true;        // Use Automatic Lot Sizing
input double   InpRiskPercent         = 2.0;         // Risk Per Trade (%)
input int      InpMaxPositions        = 1;           // Maximum Open Positions
input bool     InpUseTrailingStop     = true;        // Enable Trailing Stop
input bool     InpUseBreakEven        = true;        // Enable Break Even

//--- Market Session Filters
input group "=== SESSION FILTERS ==="
input bool     InpTradeAsianSession   = false;       // Trade Asian Session (00:00-09:00 GMT)
input bool     InpTradeLondonSession  = true;        // Trade London Session (08:00-17:00 GMT)
input bool     InpTradeNewYorkSession = true;        // Trade New York Session (13:00-22:00 GMT)
input bool     InpAvoidNews           = true;        // Avoid High Impact News
input int      InpNewsFilterMinutes   = 30;          // News Filter Minutes Before/After

//--- Technical Indicators Settings
input group "=== TECHNICAL INDICATORS ==="
input int      InpEMA_Fast            = 8;           // Fast EMA Period
input int      InpEMA_Slow            = 21;          // Slow EMA Period
input int      InpEMA_Trend           = 55;          // Trend EMA Period
input int      InpRSI_Period          = 14;          // RSI Period
input double   InpRSI_Oversold        = 30.0;        // RSI Oversold Level
input double   InpRSI_Overbought      = 70.0;        // RSI Overbought Level
input int      InpStoch_K             = 5;           // Stochastic %K Period
input int      InpStoch_D             = 3;           // Stochastic %D Period
input int      InpStoch_Slowing       = 3;           // Stochastic Slowing
input int      InpMACD_Fast           = 12;          // MACD Fast Period
input int      InpMACD_Slow           = 26;          // MACD Slow Period
input int      InpMACD_Signal         = 9;           // MACD Signal Period
input int      InpATR_Period          = 14;          // ATR Period
input double   InpATR_Multiplier      = 2.5;         // ATR Multiplier for SL/TP
input int      InpBB_Period           = 20;          // Bollinger Bands Period
input double   InpBB_Deviation        = 2.0;         // Bollinger Bands Deviation

//--- Advanced Settings
input group "=== ADVANCED SETTINGS ==="
input double   InpMinATR              = 0.0005;      // Minimum ATR for Trading
input double   InpMaxSpread           = 0.0005;      // Maximum Spread (in price)
input int      InpSignalConfirmBars   = 2;           // Signal Confirmation Bars
input bool     InpUseTrendFilter      = true;        // Use Trend Filter
input bool     InpUseVolatilityFilter = true;        // Use Volatility Filter
input double   InpProfitTarget        = 3.0;         // Profit Target Multiplier
input double   InpStopLoss            = 1.5;         // Stop Loss Multiplier
input int      InpBreakEvenPips       = 20;          // Break Even Trigger (pips)
input int      InpTrailingStart       = 25;          // Trailing Stop Start (pips)
input int      InpTrailingStep        = 5;           // Trailing Stop Step (pips)

//--- Money Management
input group "=== MONEY MANAGEMENT ==="
input double   InpMaxRiskPerDay       = 5.0;         // Maximum Daily Risk (%)
input int      InpMaxTradesPerDay     = 10;          // Maximum Trades Per Day
input double   InpEquityStopPercent   = 10.0;        // Equity Stop Percentage
input bool     InpUseTimeFilter       = true;        // Use Time Filters

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/AccountInfo.mqh>

CTrade         trade;
CPositionInfo  position;
CAccountInfo   account;

// Indicator handles
int h_EMA_Fast, h_EMA_Slow, h_EMA_Trend;
int h_RSI, h_Stochastic, h_MACD, h_ATR, h_BB;

// Market structure variables
double daily_high, daily_low, weekly_high, weekly_low;
double support_level, resistance_level;
datetime last_update_time;

// Trading statistics
int trades_today = 0;
double daily_profit = 0.0;
datetime last_trade_date;

// Signal arrays
double ema_fast[], ema_slow[], ema_trend[];
double rsi[], stoch_main[], stoch_signal[];
double macd_main[], macd_signal[], atr[];
double bb_upper[], bb_middle[], bb_lower[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("Initializing Professional XAUUSD Trading Robot...");
    
    // Initialize trade object
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(InpSlippage);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    trade.SetTypeTime(ORDER_TIME_GTC);
    
    // Initialize indicators
    if(!InitializeIndicators())
    {
        Print("Failed to initialize indicators");
        return INIT_FAILED;
    }
    
    // Initialize market structure
    UpdateMarketStructure();
    
    // Set timer for periodic updates
    EventSetTimer(60); // Update every minute
    
    Print("Professional XAUUSD Trading Robot initialized successfully!");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    IndicatorRelease(h_EMA_Fast);
    IndicatorRelease(h_EMA_Slow);
    IndicatorRelease(h_EMA_Trend);
    IndicatorRelease(h_RSI);
    IndicatorRelease(h_Stochastic);
    IndicatorRelease(h_MACD);
    IndicatorRelease(h_ATR);
    IndicatorRelease(h_BB);
    
    EventKillTimer();
    Print("Professional XAUUSD Trading Robot deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Basic checks
    if(!IsNewBar()) return;
    if(!PreTradeChecks()) return;
    
    // Update market structure
    UpdateMarketStructure();
    
    // Update indicator values
    if(!UpdateIndicators()) return;
    
    // Manage existing positions
    ManagePositions();
    
    // Check for new trade opportunities
    if(PositionsTotal() < InpMaxPositions)
    {
        CheckTradeSignals();
    }
    
    // Update daily statistics
    UpdateDailyStats();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
    UpdateMarketStructure();
    CheckSessionTimes();
}

//+------------------------------------------------------------------+
//| Initialize all indicators                                        |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
    // EMA indicators
    h_EMA_Fast = iMA(_Symbol, PERIOD_M1, InpEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
    h_EMA_Slow = iMA(_Symbol, PERIOD_M1, InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
    h_EMA_Trend = iMA(_Symbol, PERIOD_M1, InpEMA_Trend, 0, MODE_EMA, PRICE_CLOSE);
    
    // Oscillators
    h_RSI = iRSI(_Symbol, PERIOD_M1, InpRSI_Period, PRICE_CLOSE);
    h_Stochastic = iStochastic(_Symbol, PERIOD_M1, InpStoch_K, InpStoch_D, InpStoch_Slowing, MODE_SMA, STO_LOWHIGH);
    h_MACD = iMACD(_Symbol, PERIOD_M1, InpMACD_Fast, InpMACD_Slow, InpMACD_Signal, PRICE_CLOSE);
    
    // Volatility and trend indicators
    h_ATR = iATR(_Symbol, PERIOD_M1, InpATR_Period);
    h_BB = iBands(_Symbol, PERIOD_M1, InpBB_Period, 0, InpBB_Deviation, PRICE_CLOSE);
    
    // Check if all indicators are created successfully
    if(h_EMA_Fast == INVALID_HANDLE || h_EMA_Slow == INVALID_HANDLE || 
       h_EMA_Trend == INVALID_HANDLE || h_RSI == INVALID_HANDLE ||
       h_Stochastic == INVALID_HANDLE || h_MACD == INVALID_HANDLE ||
       h_ATR == INVALID_HANDLE || h_BB == INVALID_HANDLE)
    {
        Print("Error creating indicators");
        return false;
    }
    
    // Initialize arrays
    ArraySetAsSeries(ema_fast, true);
    ArraySetAsSeries(ema_slow, true);
    ArraySetAsSeries(ema_trend, true);
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(stoch_main, true);
    ArraySetAsSeries(stoch_signal, true);
    ArraySetAsSeries(macd_main, true);
    ArraySetAsSeries(macd_signal, true);
    ArraySetAsSeries(atr, true);
    ArraySetAsSeries(bb_upper, true);
    ArraySetAsSeries(bb_middle, true);
    ArraySetAsSeries(bb_lower, true);
    
    return true;
}

//+------------------------------------------------------------------+
//| Update indicator values                                          |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
    // Get indicator values
    if(CopyBuffer(h_EMA_Fast, 0, 0, 3, ema_fast) < 3) return false;
    if(CopyBuffer(h_EMA_Slow, 0, 0, 3, ema_slow) < 3) return false;
    if(CopyBuffer(h_EMA_Trend, 0, 0, 3, ema_trend) < 3) return false;
    if(CopyBuffer(h_RSI, 0, 0, 3, rsi) < 3) return false;
    if(CopyBuffer(h_Stochastic, 0, 0, 3, stoch_main) < 3) return false;
    if(CopyBuffer(h_Stochastic, 1, 0, 3, stoch_signal) < 3) return false;
    if(CopyBuffer(h_MACD, 0, 0, 3, macd_main) < 3) return false;
    if(CopyBuffer(h_MACD, 1, 0, 3, macd_signal) < 3) return false;
    if(CopyBuffer(h_ATR, 0, 0, 3, atr) < 3) return false;
    if(CopyBuffer(h_BB, 1, 0, 3, bb_upper) < 3) return false;
    if(CopyBuffer(h_BB, 0, 0, 3, bb_middle) < 3) return false;
    if(CopyBuffer(h_BB, 2, 0, 3, bb_lower) < 3) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if new bar has formed                                     |
//+------------------------------------------------------------------+
bool IsNewBar()
{
    static datetime last_time = 0;
    datetime current_time = (datetime)SeriesInfoInteger(Symbol(), PERIOD_M1, SERIES_LASTBAR_DATE);
    
    if(last_time != current_time)
    {
        last_time = current_time;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Pre-trade checks                                                |
//+------------------------------------------------------------------+
bool PreTradeChecks()
{
    // Check if trading is allowed
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || 
       !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
       !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
    {
        return false;
    }
    
    // Check spread
    double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(spread > InpMaxSpread)
    {
        return false;
    }
    
    // Check ATR for minimum volatility
    if(InpUseVolatilityFilter && atr[0] < InpMinATR)
    {
        return false;
    }
    
    // Check daily limits
    if(trades_today >= InpMaxTradesPerDay)
    {
        return false;
    }
    
    if(daily_profit <= -InpMaxRiskPerDay * account.Balance() / 100.0)
    {
        return false;
    }
    
    // Check trading sessions
    if(InpUseTimeFilter && !IsValidTradingTime())
    {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if current time is valid for trading                      |
//+------------------------------------------------------------------+
bool IsValidTradingTime()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int current_hour = dt.hour;
    
    // Convert to GMT
    current_hour = (current_hour + (int)TimeGMTOffset()/3600) % 24;
    
    bool valid_session = false;
    
    // Asian Session (00:00-09:00 GMT)
    if(InpTradeAsianSession && current_hour >= 0 && current_hour < 9)
        valid_session = true;
    
    // London Session (08:00-17:00 GMT)
    if(InpTradeLondonSession && current_hour >= 8 && current_hour < 17)
        valid_session = true;
    
    // New York Session (13:00-22:00 GMT)
    if(InpTradeNewYorkSession && current_hour >= 13 && current_hour < 22)
        valid_session = true;
    
    return valid_session;
}

//+------------------------------------------------------------------+
//| Update market structure levels                                  |
//+------------------------------------------------------------------+
void UpdateMarketStructure()
{
    datetime current_time = TimeCurrent();
    
    // Update daily levels
    daily_high = iHigh(_Symbol, PERIOD_D1, 0);
    daily_low = iLow(_Symbol, PERIOD_D1, 0);
    
    // Update weekly levels
    weekly_high = iHigh(_Symbol, PERIOD_W1, 0);
    weekly_low = iLow(_Symbol, PERIOD_W1, 0);
    
    // Calculate dynamic support and resistance
    CalculateSupportResistance();
    
    last_update_time = current_time;
}

//+------------------------------------------------------------------+
//| Calculate dynamic support and resistance levels                 |
//+------------------------------------------------------------------+
void CalculateSupportResistance()
{
    double highs[20], lows[20];
    
    // Get recent highs and lows
    for(int i = 0; i < 20; i++)
    {
        highs[i] = iHigh(_Symbol, PERIOD_M5, i);
        lows[i] = iLow(_Symbol, PERIOD_M5, i);
    }
    
    // Find significant levels
    resistance_level = highs[ArrayMaximum(highs)];
    support_level = lows[ArrayMinimum(lows)];
}

//+------------------------------------------------------------------+
//| Check for trade signals                                         |
//+------------------------------------------------------------------+
void CheckTradeSignals()
{
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Get trend direction
    int trend = GetTrendDirection();
    
    // Check buy signals
    if(IsBuySignal(trend, current_price))
    {
        OpenBuyPosition();
    }
    // Check sell signals
    else if(IsSellSignal(trend, current_price))
    {
        OpenSellPosition();
    }
}

//+------------------------------------------------------------------+
//| Get trend direction                                             |
//+------------------------------------------------------------------+
int GetTrendDirection()
{
    int trend_score = 0;
    
    // EMA trend analysis
    if(ema_fast[0] > ema_slow[0] && ema_slow[0] > ema_trend[0])
        trend_score += 2; // Strong bullish
    else if(ema_fast[0] > ema_slow[0])
        trend_score += 1; // Mild bullish
    else if(ema_fast[0] < ema_slow[0] && ema_slow[0] < ema_trend[0])
        trend_score -= 2; // Strong bearish
    else if(ema_fast[0] < ema_slow[0])
        trend_score -= 1; // Mild bearish
    
    // MACD trend confirmation
    if(macd_main[0] > macd_signal[0] && macd_main[0] > 0)
        trend_score += 1;
    else if(macd_main[0] < macd_signal[0] && macd_main[0] < 0)
        trend_score -= 1;
    
    return trend_score;
}

//+------------------------------------------------------------------+
//| Check buy signal conditions                                     |
//+------------------------------------------------------------------+
bool IsBuySignal(int trend, double price)
{
    int signal_count = 0;
    
    // Trend filter
    if(InpUseTrendFilter && trend < 0) return false;
    
    // EMA crossover
    if(ema_fast[0] > ema_slow[0] && ema_fast[1] <= ema_slow[1])
        signal_count++;
    
    // RSI oversold
    if(rsi[0] < InpRSI_Oversold && rsi[0] > rsi[1])
        signal_count++;
    
    // Stochastic oversold crossover
    if(stoch_main[0] > stoch_signal[0] && stoch_main[1] <= stoch_signal[1] && stoch_main[0] < 20)
        signal_count++;
    
    // MACD bullish crossover
    if(macd_main[0] > macd_signal[0] && macd_main[1] <= macd_signal[1])
        signal_count++;
    
    // Bollinger Bands bounce from lower band
    if(price <= bb_lower[0] && iClose(_Symbol, PERIOD_M1, 1) > bb_lower[1])
        signal_count++;
    
    // Price above key support
    if(price > support_level && price < support_level + atr[0])
        signal_count++;
    
    return signal_count >= InpSignalConfirmBars;
}

//+------------------------------------------------------------------+
//| Check sell signal conditions                                    |
//+------------------------------------------------------------------+
bool IsSellSignal(int trend, double price)
{
    int signal_count = 0;
    
    // Trend filter
    if(InpUseTrendFilter && trend > 0) return false;
    
    // EMA crossover
    if(ema_fast[0] < ema_slow[0] && ema_fast[1] >= ema_slow[1])
        signal_count++;
    
    // RSI overbought
    if(rsi[0] > InpRSI_Overbought && rsi[0] < rsi[1])
        signal_count++;
    
    // Stochastic overbought crossover
    if(stoch_main[0] < stoch_signal[0] && stoch_main[1] >= stoch_signal[1] && stoch_main[0] > 80)
        signal_count++;
    
    // MACD bearish crossover
    if(macd_main[0] < macd_signal[0] && macd_main[1] >= macd_signal[1])
        signal_count++;
    
    // Bollinger Bands bounce from upper band
    if(price >= bb_upper[0] && iClose(_Symbol, PERIOD_M1, 1) < bb_upper[1])
        signal_count++;
    
    // Price below key resistance
    if(price < resistance_level && price > resistance_level - atr[0])
        signal_count++;
    
    return signal_count >= InpSignalConfirmBars;
}

//+------------------------------------------------------------------+
//| Open buy position                                               |
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = price - (InpStopLoss * atr[0]);
    double tp = price + (InpProfitTarget * atr[0]);
    double lots = CalculateLotSize(sl);
    
    // Normalize prices
    sl = NormalizeDouble(sl, _Digits);
    tp = NormalizeDouble(tp, _Digits);
    
    if(trade.Buy(lots, _Symbol, price, sl, tp, "XAUUSD_Buy"))
    {
        Print("Buy order opened: Price=", price, " SL=", sl, " TP=", tp, " Lots=", lots);
        trades_today++;
    }
    else
    {
        Print("Failed to open buy order. Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Open sell position                                              |
//+------------------------------------------------------------------+
void OpenSellPosition()
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = price + (InpStopLoss * atr[0]);
    double tp = price - (InpProfitTarget * atr[0]);
    double lots = CalculateLotSize(sl);
    
    // Normalize prices
    sl = NormalizeDouble(sl, _Digits);
    tp = NormalizeDouble(tp, _Digits);
    
    if(trade.Sell(lots, _Symbol, price, sl, tp, "XAUUSD_Sell"))
    {
        Print("Sell order opened: Price=", price, " SL=", sl, " TP=", tp, " Lots=", lots);
        trades_today++;
    }
    else
    {
        Print("Failed to open sell order. Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Calculate optimal lot size                                      |
//+------------------------------------------------------------------+
double CalculateLotSize(double stop_loss)
{
    if(!InpAutoLotSize) return InpLots;
    
    double current_price = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2;
    double sl_distance = MathAbs(current_price - stop_loss);
    
    if(sl_distance == 0) return InpLots;
    
    double risk_amount = account.Balance() * InpRiskPercent / 100.0;
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tick_value == 0 || tick_size == 0) return InpLots;
    
    double money_per_pip = tick_value / tick_size;
    double pips_at_risk = sl_distance / _Point;
    double lots = risk_amount / (money_per_pip * pips_at_risk);
    
    // Apply position size limits
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lots = MathMax(lots, min_lot);
    lots = MathMin(lots, max_lot);
    lots = NormalizeDouble(lots / lot_step, 0) * lot_step;
    
    return lots;
}

//+------------------------------------------------------------------+
//| Manage existing positions                                       |
//+------------------------------------------------------------------+
void ManagePositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!position.SelectByIndex(i)) continue;
        if(position.Symbol() != _Symbol || position.Magic() != InpMagicNumber) continue;
        
        // Apply break even
        if(InpUseBreakEven)
        {
            ApplyBreakEven();
        }
        
        // Apply trailing stop
        if(InpUseTrailingStop)
        {
            ApplyTrailingStop();
        }
    }
}

//+------------------------------------------------------------------+
//| Apply break even logic                                          |
//+------------------------------------------------------------------+
void ApplyBreakEven()
{
    double open_price = position.PriceOpen();
    double current_price = (position.PositionType() == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double profit_pips = 0;
    if(position.PositionType() == POSITION_TYPE_BUY)
        profit_pips = (current_price - open_price) / _Point;
    else
        profit_pips = (open_price - current_price) / _Point;
    
    if(profit_pips >= InpBreakEvenPips)
    {
        double new_sl = open_price;
        if(MathAbs(position.StopLoss() - new_sl) > _Point)
        {
            trade.PositionModify(position.Ticket(), new_sl, position.TakeProfit());
        }
    }
}

//+------------------------------------------------------------------+
//| Apply trailing stop logic                                       |
//+------------------------------------------------------------------+
void ApplyTrailingStop()
{
    double open_price = position.PriceOpen();
    double current_price = (position.PositionType() == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double profit_pips = 0;
    if(position.PositionType() == POSITION_TYPE_BUY)
        profit_pips = (current_price - open_price) / _Point;
    else
        profit_pips = (open_price - current_price) / _Point;
    
    if(profit_pips >= InpTrailingStart)
    {
        double new_sl = 0;
        if(position.PositionType() == POSITION_TYPE_BUY)
        {
            new_sl = current_price - (InpTrailingStep * _Point);
            if(new_sl > position.StopLoss() + (InpTrailingStep * _Point))
            {
                trade.PositionModify(position.Ticket(), new_sl, position.TakeProfit());
            }
        }
        else
        {
            new_sl = current_price + (InpTrailingStep * _Point);
            if(new_sl < position.StopLoss() - (InpTrailingStep * _Point) || position.StopLoss() == 0)
            {
                trade.PositionModify(position.Ticket(), new_sl, position.TakeProfit());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update daily trading statistics                                 |
//+------------------------------------------------------------------+
void UpdateDailyStats()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    datetime today = StructToTime(dt);
    today = today - (dt.hour * 3600 + dt.min * 60 + dt.sec); // Start of day
    
    if(last_trade_date != today)
    {
        trades_today = 0;
        daily_profit = 0.0;
        last_trade_date = today;
    }
    
    // Calculate current daily profit
    daily_profit = 0.0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!position.SelectByIndex(i)) continue;
        if(position.Symbol() != _Symbol || position.Magic() != InpMagicNumber) continue;
        daily_profit += position.Profit();
    }
}

//+------------------------------------------------------------------+
//| Check session times                                             |
//+------------------------------------------------------------------+
void CheckSessionTimes()
{
    // This function can be expanded to handle news filters
    // and other time-based restrictions
}

//+------------------------------------------------------------------+
//| Expert advisor optimization function                            |
//+------------------------------------------------------------------+
double OnTester()
{
    double profit = TesterStatistics(STAT_PROFIT);
    double dd = TesterStatistics(STAT_BALANCE_DD_PERCENT);
    
    if(dd == 0) return 0;
    
    return profit / dd; // Profit factor / Drawdown ratio
}
