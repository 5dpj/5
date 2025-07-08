//+------------------------------------------------------------------+
//|                                                Improved_EA.mq5|
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                                  https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Expert Advisor with improved logic, error handling, and modern MQL5 practices."
#property strict

// --- Input Parameters ---
input double Lots = 0.01;            // حجم اللوت
input int    Magic = 12345;          // الرقم السحري
input int    Slippage = 5;           // الانزلاق السعري بالنقاط

// MACD Parameters
input int    MACD_Fast_EMA = 12;
input int    MACD_Slow_EMA = 26;
input int    MACD_Signal_SMA = 9;

// RSI Parameters
input int    RSI_Period = 14;
input double RSI_Buy_Level = 30.0;
input double RSI_Sell_Level = 70.0;

// Bollinger Bands Parameters
input int    BB_Period = 20;
input double BB_Deviations = 2.0;

// ATR Parameters for Take Profit and Trailing Stop
input int    ATR_Period = 14;
input double ATR_TakeProfit_Multiplier = 8.0; // مضاعف ATR لجني الأرباح
input double Trailing_Stop_ATR_Multiplier = 2.0; // مضاعف ATR للوقف المتحرك

// NEW ADVANCED PARAMETERS
input ENUM_TIMEFRAMES Analysis_Timeframe = PERIOD_M1;   // الاطار الزمني للتحليل (افتراضي 1 دقيقة)

// Risk Management
input bool   Use_Risk_Management   = true;   // تفعيل إدارة المخاطر
input double Risk_Percentage       = 1.0;    // نسبة المخاطرة من رصيد الحساب لكل صفقة
input double SL_ATR_Multiplier     = 3.0;    // مضاعف ATR لوقف الخسارة

// Spread Filter
input bool   Use_Spread_Filter   = true;     // تفعيل فلتر السبريد
input double Max_Spread_Points   = 30;       // أقصى سبريد مسموح (نقاط)

// Session Filter (server time)
input bool   Use_Session_Filter  = true;     // تفعيل فلتر جلسة التداول
input int    Session_Start_Hour  = 8;        // بداية الجلسة
input int    Session_End_Hour    = 18;       // نهاية الجلسة

// News Filter
input bool   Use_News_Filter     = false;    // تفعيل فلتر الأخبار
input int    News_Avoidance_Minutes = 30;    // دقائق الابتعاد قبل/بعد الأخبار

input bool   Use_Break_Even = true;  // استخدام نقطة التعادل
input int    Break_Even_Pips = 30;   // عدد النقاط لنقطة التعادل (30 بيب) - سيتم تحويلها إلى نقاط فعليًا

input bool   Use_Trailing_Stop = true; // استخدام الوقف المتحرك
input bool   Use_Dynamic_TakeProfit = true; // استخدام جني الأرباح المتحرك الديناميكي

// --- Global Variables ---
#include <Trade/Trade.mqh> // Include CTrade class for trade operations

CTrade trade; // Global instance of CTrade class

MqlTick last_tick; // To store the latest tick data

// Indicator handles
int macd_handle;
int rsi_handle;
int bb_handle;
int atr_handle;

// Helper function to get current Bid/Ask price, accounting for potential zero values
double GetCurrentBid() {
    if(!SymbolInfoTick(_Symbol, last_tick)) {
        Print("Failed to get tick data for ", _Symbol, ". Error: ", GetLastError());
        return 0.0;
    }
    return last_tick.bid;
}

double GetCurrentAsk() {
    if(!SymbolInfoTick(_Symbol, last_tick)) {
        Print("Failed to get tick data for ", _Symbol, ". Error: ", GetLastError());
        return 0.0;
    }
    return last_tick.ask;
}

// Function to calculate effective pip size based on symbol digits
double GetSymbolPipSize() {
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    if (digits == 3 || digits == 5) { // JPY pairs (3 digits) or typical 5-digit pairs
        return _Point * 10;
    }
    return _Point; // 2 or 4 digit pairs
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize CTrade object
    // The CTrade object automatically uses the EA's Magic number if the EA has one.
    // Explicit SetExpertMagic is often deprecated or not needed in recent builds.
    trade.SetDeviationInPoints(Slippage);

    // Warn if EA attached to a different timeframe
    if(_Period != Analysis_Timeframe)
        Print("تنبيه: الإكسبيرت مُحسَّن لإطار ", EnumToString(Analysis_Timeframe), "، والإطار الحالي هو ", EnumToString(_Period), ".");

    // Initialize indicator handles
    macd_handle = iMACD(_Symbol, Analysis_Timeframe, MACD_Fast_EMA, MACD_Slow_EMA, MACD_Signal_SMA, PRICE_CLOSE);
    if(macd_handle == INVALID_HANDLE) { Print("Failed to create MACD indicator handle. Error: ", GetLastError()); return INIT_FAILED; }

    rsi_handle  = iRSI(_Symbol, Analysis_Timeframe, RSI_Period, PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE)  { Print("Failed to create RSI indicator handle. Error: ",  GetLastError()); return INIT_FAILED; }

    bb_handle   = iBands(_Symbol, Analysis_Timeframe, BB_Period, 0, BB_Deviations, PRICE_CLOSE);
    if(bb_handle == INVALID_HANDLE)   { Print("Failed to create Bollinger Bands indicator handle. Error: ", GetLastError()); return INIT_FAILED; }

    atr_handle  = iATR(_Symbol, Analysis_Timeframe, ATR_Period);
    if(atr_handle == INVALID_HANDLE)  { Print("Failed to create ATR indicator handle. Error: ", GetLastError()); return INIT_FAILED; }

    Print("Expert Advisor Initialized Successfully!");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    if (macd_handle != INVALID_HANDLE) IndicatorRelease(macd_handle);
    if (rsi_handle != INVALID_HANDLE) IndicatorRelease(rsi_handle);
    if (bb_handle != INVALID_HANDLE) IndicatorRelease(bb_handle);
    if (atr_handle != INVALID_HANDLE) IndicatorRelease(atr_handle);
    Print("Expert Advisor Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Get latest tick data
    if(!SymbolInfoTick(_Symbol, last_tick)) { Print("Failed to get tick data for ", _Symbol, ". Error: ", GetLastError()); return; }

    // Detect new bar on analysis timeframe
    static datetime last_bar_time = 0;
    datetime current_bar_time = (datetime)iTime(_Symbol, Analysis_Timeframe, 0);
    if(current_bar_time != last_bar_time) {
        last_bar_time = current_bar_time;
        // Actions once per bar can be placed here
    }

    ManageOpenTrades();
    CheckForNewTrades();
}

//+------------------------------------------------------------------+
//| Function to manage open trades (Break-Even, Trailing Stop, Dynamic Take Profit) |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    // Get latest tick data for current prices
    double current_bid = GetCurrentBid();
    double current_ask = GetCurrentAsk();
    if (current_bid == 0.0 || current_ask == 0.0) return; // Error in getting tick, return

    // Calculate ATR for dynamic levels
    double atr_values[1]; // Array to store ATR value
    // Get ATR value for the current bar (shift 0) as it represents current volatility
    if(CopyBuffer(atr_handle, 0, 0, 1, atr_values) <= 0) {
        Print("Failed to get ATR value. Error: ", GetLastError());
        return;
    }
    double atr_value = atr_values[0];

    if(atr_value == 0) {
        Print("ATR value is zero, cannot calculate dynamic levels.");
        return;
    }

    // Get symbol stop level (minimum distance for SL/TP from current price)
    // FIX: SYMBOL_TRADE_STOPS_LEVEL returns an integer, use SymbolInfoInteger
    long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL); // Value is in points

    // Iterate through all open positions
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong position_ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(position_ticket)) {
            Print("Failed to select position ", position_ticket, ". Error: ", GetLastError());
            continue;
        }

        // Ensure the position belongs to this EA and symbol using the Magic number
        // CTrade implicitly uses the EA's magic number, so this check is valid.
        if(PositionGetInteger(POSITION_MAGIC) != Magic || PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;

        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double current_sl = PositionGetDouble(POSITION_SL);
        double current_tp = PositionGetDouble(POSITION_TP);
        double current_position_price = (type == POSITION_TYPE_BUY ? current_bid : current_ask); // Use bid for buy, ask for sell for current market price reference

        // Normalize prices to symbol's digits
        open_price = NormalizeDouble(open_price, _Digits);
        current_sl = NormalizeDouble(current_sl, _Digits);
        current_tp = NormalizeDouble(current_tp, _Digits);

        // --- Break-Even Logic ---
        if(Use_Break_Even) {
            double profit_in_points = (type == POSITION_TYPE_BUY) ? (current_position_price - open_price) / _Point : (open_price - current_position_price) / _Point;
            
            // Convert Break_Even_Pips (input) to actual points based on GetSymbolPipSize()
            double break_even_points = Break_Even_Pips * (GetSymbolPipSize() / _Point);

            if(profit_in_points >= break_even_points) {
                double new_sl_be = open_price; // Move SL to open price
                new_sl_be = NormalizeDouble(new_sl_be, _Digits); // Normalize to account for symbol's digits

                bool modify_sl = false;
                if (type == POSITION_TYPE_BUY) {
                    // For BUY, new SL must be greater than current SL, or if current SL is not set (0)
                    if (new_sl_be > current_sl || current_sl == 0.0) {
                        modify_sl = true;
                    }
                } else { // POSITION_TYPE_SELL
                    // For SELL, new SL must be less than current SL, or if current SL is not set (0)
                    if (new_sl_be < current_sl || current_sl == 0.0) {
                        modify_sl = true;
                    }
                }
                
                if (modify_sl) {
                    // Make sure the new SL is not too close to the current price (broker restrictions)
                    if (type == POSITION_TYPE_BUY) {
                        if (new_sl_be >= current_position_price - stops_level * _Point) {
                            new_sl_be = current_position_price - stops_level * _Point;
                        }
                    } else { // POSITION_TYPE_SELL
                        if (new_sl_be <= current_position_price + stops_level * _Point) {
                            new_sl_be = current_position_price + stops_level * _Point;
                        }
                    }
                    
                    if (trade.PositionModify(position_ticket, new_sl_be, current_tp)) {
                        PrintFormat("Position #%I64d: Moved SL to Break-Even (%.5f). Current TP: %.5f", position_ticket, new_sl_be, current_tp);
                    } else {
                        PrintFormat("Failed to move SL to Break-Even for #%I64d. Error: %d", position_ticket, GetLastError());
                    }
                }
            }
        }

        // --- Trailing Stop Logic ---
        if(Use_Trailing_Stop) {
            double trailing_distance = Trailing_Stop_ATR_Multiplier * atr_value; // Distance in price points
            double new_sl_ts = 0;

            if(type == POSITION_TYPE_BUY) {
                new_sl_ts = current_position_price - trailing_distance; // For BUY, SL is below current price
                new_sl_ts = NormalizeDouble(new_sl_ts, _Digits);

                // Only move SL if it's higher than current SL (or current SL is 0, meaning not set yet)
                // And ensure it's not violating the stops level
                if (new_sl_ts > current_sl || current_sl == 0.0) { 
                    // Make sure the new SL is not too close to the current price (broker restrictions)
                    if (new_sl_ts >= current_position_price - stops_level * _Point) {
                        new_sl_ts = current_position_price - stops_level * _Point;
                    }
                    if (trade.PositionModify(position_ticket, new_sl_ts, current_tp)) {
                        PrintFormat("Position #%I64d: Trailing SL to %.5f. Current TP: %.5f", position_ticket, new_sl_ts, current_tp);
                    } else {
                        PrintFormat("Failed to trail SL for #%I64d. Error: %d", position_ticket, GetLastError());
                    }
                }
            } else { // POSITION_TYPE_SELL
                new_sl_ts = current_position_price + trailing_distance; // For SELL, SL is above current price
                new_sl_ts = NormalizeDouble(new_sl_ts, _Digits);

                // Only move SL if it's lower than current SL (or current SL is 0, meaning not set yet)
                // And ensure it's not violating the stops level
                if (new_sl_ts < current_sl || current_sl == 0.0) { 
                    // Make sure the new SL is not too close to the current price (broker restrictions)
                    if (new_sl_ts <= current_position_price + stops_level * _Point) {
                        new_sl_ts = current_position_price + stops_level * _Point;
                    }
                    if (trade.PositionModify(position_ticket, new_sl_ts, current_tp)) {
                        PrintFormat("Position #%I64d: Trailing SL to %.5f. Current TP: %.5f", position_ticket, new_sl_ts, current_tp);
                    } else {
                        PrintFormat("Failed to trail SL for #%I64d. Error: %d", position_ticket, GetLastError());
                    }
                }
            }
        }
        
        // --- Dynamic Take Profit Logic ---
        if (Use_Dynamic_TakeProfit) {
            double dynamic_tp_distance = ATR_TakeProfit_Multiplier * atr_value;
            double new_tp = 0;
            
            if (type == POSITION_TYPE_BUY) {
                new_tp = open_price + dynamic_tp_distance; // TP for buy is above open price
            } else { // POSITION_TYPE_SELL
                new_tp = open_price - dynamic_tp_distance; // TP for sell is below open price
            }
            new_tp = NormalizeDouble(new_tp, _Digits);
            
            // Only modify TP if it's different from the current TP and valid
            // Check for minimum distance from current price to avoid broker errors
            bool is_tp_valid = true;
            if (type == POSITION_TYPE_BUY) {
                if (new_tp <= current_position_price + stops_level * _Point) {
                    is_tp_valid = false; // TP is too close to current price
                }
            } else { // POSITION_TYPE_SELL
                if (new_tp >= current_position_price - stops_level * _Point) {
                    is_tp_valid = false; // TP is too close to current price
                }
            }


            if (is_tp_valid && MathAbs(new_tp - current_tp) > _Point) { // Compare with a small tolerance
                if (trade.PositionModify(position_ticket, current_sl, new_tp)) {
                    PrintFormat("Position #%I64d: Dynamically adjusted TP to %.5f. Current SL: %.5f", position_ticket, new_tp, current_sl);
                } else {
                    PrintFormat("Failed to dynamically adjust TP for #%I64d. Error: %d", position_ticket, GetLastError());
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Function to check for new trade opportunities                    |
//+------------------------------------------------------------------+
void CheckForNewTrades()
{
    if(PositionsTotal() > 0)
        return;

    // Professional Filters
    if(!IsSpreadAcceptable())      return;
    if(!IsWithinTradingSession())  return;
    if(IsHighImpactNewsTime())     return;

    // Arrays to store indicator values
    double macd_main_buffer[2]; // Need 2 values for shift 1 and 2
    double macd_signal_buffer[2]; // Need 2 values for shift 1 and 2
    double rsi_buffer[1]; // Need 1 value for shift 1
    double bb_upper_buffer[1]; // Need 1 value for shift 1
    double bb_lower_buffer[1]; // Need 1 value for shift 1
    double atr_values[1]; // Need 1 value for shift 0

    // Get MACD values for previous two bars (shift 1 and 2 for crossovers)
    // CopyBuffer(indicator_handle, buffer_index, start_index, count, array)
    // Shift 1 is array[0], Shift 2 is array[1] when you copy 2 values starting from shift 1
    if(CopyBuffer(macd_handle, 0, 1, 2, macd_main_buffer) <= 0 || CopyBuffer(macd_handle, 1, 1, 2, macd_signal_buffer) <= 0) {
        Print("Failed to get MACD values. Error: ", GetLastError());
        return;
    }
    double macd_main_prev = macd_main_buffer[0];   // Value on the previous bar (shift 1)
    double macd_signal_prev = macd_signal_buffer[0]; // Value on the previous bar (shift 1)
    double macd_main_prev2 = macd_main_buffer[1];   // Value two bars ago (shift 2)
    double macd_signal_prev2 = macd_signal_buffer[1]; // Value two bars ago (shift 2)

    // Get RSI value for previous bar (shift 1)
    if(CopyBuffer(rsi_handle, 0, 1, 1, rsi_buffer) <= 0) {
        Print("Failed to get RSI value. Error: ", GetLastError());
        return;
    }
    double rsi_value_prev = rsi_buffer[0]; // Value on the previous bar (shift 1)

    // Get Bollinger Bands values for previous bar (shift 1)
    if(CopyBuffer(bb_handle, 0, 1, 1, bb_upper_buffer) <= 0 || CopyBuffer(bb_handle, 1, 1, 1, bb_lower_buffer) <= 0) {
        Print("Failed to get Bollinger Bands values. Error: ", GetLastError());
        return;
    }
    double bb_upper_prev = bb_upper_buffer[0]; // Value on the previous bar (shift 1)
    double bb_lower_prev = bb_lower_buffer[0]; // Value on the previous bar (shift 1)

    // Get ATR value for the current bar (shift 0) for initial TP setting
    if(CopyBuffer(atr_handle, 0, 0, 1, atr_values) <= 0) {
        Print("Failed to get ATR value. Error: ", GetLastError());
        return;
    }
    double atr_value = atr_values[0];

    if(atr_value == 0) {
        Print("ATR value is zero, cannot calculate Take Profit.");
        return;
    }
    
    double take_profit_distance = ATR_TakeProfit_Multiplier * atr_value;

    // Get current prices
    double current_bid = GetCurrentBid();
    double current_ask = GetCurrentAsk();
    if (current_bid == 0.0 || current_ask == 0.0) return;

    // Get symbol stop levels (minimum distance for SL/TP from current price)
    // FIX: SYMBOL_TRADE_STOPS_LEVEL returns an integer, use SymbolInfoInteger
    long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL); // Value is in points

    // --- Buy Signal ---
    bool buy_signal = false;
    // MACD crossover buy: Main line crosses above Signal line
    if(macd_main_prev > macd_signal_prev && macd_main_prev2 <= macd_signal_prev2)
        buy_signal = true;
    // RSI oversold
    if(rsi_value_prev < RSI_Buy_Level)
        buy_signal = true;
    // Price below lower Bollinger Band
    if(current_bid < bb_lower_prev)
        buy_signal = true;

    if(buy_signal) {
        double sl_distance = SL_ATR_Multiplier * atr_value; // ATR based SL distance
        double sl_price    = NormalizeDouble(current_ask - sl_distance, _Digits);
        double stop_loss_pips = sl_distance / GetSymbolPipSize();
        double lot_size = Use_Risk_Management ? CalculateLotSize(Risk_Percentage, stop_loss_pips) : Lots;
        double tp_price   = NormalizeDouble(current_ask + take_profit_distance, _Digits);

        if (sl_price >= current_ask - stops_level * _Point)
            sl_price = current_ask - stops_level * _Point;
        if (tp_price <= current_ask + stops_level * _Point)
            tp_price = current_ask + stops_level * _Point;

        if(trade.Buy(lot_size, _Symbol, current_ask, sl_price, tp_price, "Buy Order"))
            PrintFormat("Buy Order Sent: Lots=%.2f, Price=%.5f, SL=%.5f, TP=%.5f", lot_size, current_ask, sl_price, tp_price);
        else
            PrintFormat("Failed to send Buy Order. Error: %d", GetLastError());
    }

    // --- Sell Signal ---
    bool sell_signal = false;
    // MACD crossover sell: Main line crosses below Signal line
    if(macd_main_prev < macd_signal_prev && macd_main_prev2 >= macd_signal_prev2)
        sell_signal = true;
    // RSI overbought
    if(rsi_value_prev > RSI_Sell_Level)
        sell_signal = true;
    // Price above upper Bollinger Band
    if(current_ask > bb_upper_prev)
        sell_signal = true;

    if(sell_signal) {
        double sl_distance = SL_ATR_Multiplier * atr_value;
        double sl_price    = NormalizeDouble(current_bid + sl_distance, _Digits);
        double stop_loss_pips = sl_distance / GetSymbolPipSize();
        double lot_size = Use_Risk_Management ? CalculateLotSize(Risk_Percentage, stop_loss_pips) : Lots;
        double tp_price   = NormalizeDouble(current_bid - take_profit_distance, _Digits);

        if (sl_price <= current_bid + stops_level * _Point)
            sl_price = current_bid + stops_level * _Point;
        if (tp_price >= current_bid - stops_level * _Point)
            tp_price = current_bid - stops_level * _Point;

        if(trade.Sell(lot_size, _Symbol, current_bid, sl_price, tp_price, "Sell Order"))
            PrintFormat("Sell Order Sent: Lots=%.2f, Price=%.5f, SL=%.5f, TP=%.5f", lot_size, current_bid, sl_price, tp_price);
        else
            PrintFormat("Failed to send Sell Order. Error: %d", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| OnTradeTransaction function (for asynchronous trade event handling)|
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result)
{
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
        PrintFormat("Deal #%I64d executed. Order: %I64d, Position: %I64d, Type: %s, Price: %.5f, Volume: %.2f",
                    trans.deal, trans.order, trans.position, EnumToString(trans.type), trans.price, trans.volume);
    } else if(trans.type == TRADE_TRANSACTION_ORDER_ADD) {
        PrintFormat("Order #%I64d placed. Symbol: %s, Type: %s, Price: %.5f, Volume: %.2f",
                    trans.order, trans.symbol, EnumToString(trans.type), trans.price, trans.volume);
    }
}

//+------------------------------------------------------------------+
//| OnTimer function (for periodic tasks)                            |
//+------------------------------------------------------------------+
void OnTimer()
{
    // This function can be used for periodic tasks that don't need to run on every tick.
    // For now, it's empty, but can be extended.
}

//+------------------------------------------------------------------+
//| OnChartEvent function (for user interaction)                     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // This function can be used to handle chart events like button clicks or object dragging.
    // For now, it's empty, but can be extended for interactive dashboards.
}

// --- Additional helper functions (Append after existing helpers) ---
// Spread filter helper
bool IsSpreadAcceptable()
{
    if(!Use_Spread_Filter) return true;
    double spread_points = (GetCurrentAsk() - GetCurrentBid()) / _Point;
    return (spread_points <= Max_Spread_Points);
}

// Session filter helper (server time assumed)
bool IsWithinTradingSession()
{
    if(!Use_Session_Filter) return true;
    datetime now = TimeCurrent();
    int hour = TimeHour(now);
    return (hour >= Session_Start_Hour && hour < Session_End_Hour);
}

// News filter placeholder (requires economic calendar functions)
bool IsHighImpactNewsTime()
{
    if(!Use_News_Filter) return false;
    // Placeholder: implement actual economic calendar check here
    return false;
}

// --- Additional helper functions (if needed) ---
// Example: Function to check if market is open
bool IsMarketOpen()
{
    long trade_mode_long; 
    if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE, trade_mode_long)) {
        Print("Failed to get trade mode for ", _Symbol, ". Error: ", GetLastError());
        return false;
    }
    // Using the numerical values for the enums, as the enum names seem to be problematic
    // SYMBOL_TRADE_MODE_FULL = 0, SYMBOL_TRADE_MODE_CLOSE_ONLY = 1
    return (trade_mode_long == 0 || trade_mode_long == 1); 
}

// Example: Function to calculate lot size based on risk
double CalculateLotSize(double risk_percentage, double stop_loss_pips)
{
    if(stop_loss_pips <= 0 || risk_percentage <= 0)
        return 0.0;

    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = account_balance * (risk_percentage / 100.0);
    
    // Calculate the value of one pip for the current symbol and lot size of 1.0
    // A pip is defined by GetSymbolPipSize()
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    if (tick_value == 0 || tick_size == 0) {
        Print("Error: Tick value or tick size is zero. Cannot calculate lot size.");
        return 0.0;
    }

    double pip_value_per_lot = tick_value / tick_size * GetSymbolPipSize();

    if (pip_value_per_lot == 0) {
        Print("Error: Pip value per lot is zero. Cannot calculate lot size.");
        return 0.0;
    }

    double lot_size = risk_amount / (stop_loss_pips * pip_value_per_lot);

    // Normalize lot size to minimum and maximum allowed by broker/symbol
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    // Adjust lot_size to be a multiple of step_lot and within min/max bounds
    lot_size = floor(lot_size / step_lot) * step_lot; // Round down to the nearest step
    
    if(lot_size < min_lot)
        lot_size = min_lot;
    if(lot_size > max_lot)
        lot_size = max_lot;

    return lot_size;
}
