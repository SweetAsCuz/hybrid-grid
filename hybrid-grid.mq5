//+------------------------------------------------------------------+
//|                                                                  |
//|                                                                  |
//|                                                      Hybrid Grid |
//+------------------------------------------------------------------+
#property copyright "Catalyst"
#include <Trade\Trade.mqh>
CTrade trade;

struct SymbolData
  {
   string            symbol;
   bool              Activated; // 0 = OFF, 1 = ON
   bool              togglegrid; // 0 = OFF, 1 = ON
   datetime          start_date;
   double            TP_Pips; // Pips
   double            TakeProfit; // USD
   double            stopLoss; // USD
   int               grid_level;
   double            lotSize;
   double            profit;
   double            loss;
   double            net;
  };

///// User Manual \\\\\ 
/*
1. Attach to chart
2. Reset starting date (YEAR.MONTH.DAY 00:00)

*/

SymbolData symbols[2]; // Adjust according to amount of symbols
void OnInit() // Add new symbols here
  {
//                                                             Time                Pips  TP   SL   G  Lots
   InitializeSymbol(symbols[0], "XAUUSD.s", 1, 1, StringToTime("2023.11.13 11:00"), 10, 999,  15, 07, 0.01);
   InitializeSymbol(symbols[1], "EURUSD.s", 0, 0, StringToTime("2023.10.30 17:00"),  6,  45,  50, 15, 0.01);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InitializeSymbol(SymbolData &symbolData, string symbol, bool activated, bool toggle_grid, datetime startdate, double tpPips, double takeprofit, double stoploss, int gridLevel, double lotSize)
  {
   symbolData.symbol = symbol;
   symbolData.Activated = activated;
   symbolData.togglegrid = toggle_grid;
   symbolData.start_date = startdate;
   symbolData.TP_Pips = tpPips;
   symbolData.TakeProfit = takeprofit;
   symbolData.stopLoss = stoploss;
   symbolData.grid_level = gridLevel;
   symbolData.lotSize = lotSize;
   symbolData.profit = 0;
   symbolData.loss = 0;
   symbolData.net = 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   string currentSymbol = _Symbol;
   for(int i = 0; i < ArraySize(symbols); i++)
     {
      SymbolData symbolData = symbols[i];

      if(currentSymbol == symbolData.symbol)
        {
         Grid(symbolData.symbol, symbolData.grid_level, symbolData.TP_Pips, symbolData.lotSize, symbolData.Activated, symbolData.togglegrid);
         DeactivateGrid(symbolData.Activated, symbolData.symbol);
         Status(symbolData.symbol, symbolData.profit, symbolData.loss, symbolData.net, symbolData.TakeProfit, symbolData.stopLoss, symbolData.start_date);
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Grid(string symbol, int grid_level, double TP_Pips, double lotSize, bool Activated, bool togglegrid)
  {
// Initializing Grids
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
   double TP_Pips_Point = TP_Pips * point;
   double TP_Gap = 10 * point; // gap to increase TP for better grid replacement calculations
   double askPricelive = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_ASK), 4); // constantly changing values
   double bidPricelive = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_BID), 4);
   double spread = askPricelive - bidPricelive;
   int TotalPositions = 0;
   int TotalOrders = 0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong posTicket = PositionGetTicket(i);
      if(PositionSelectByTicket(posTicket) && PositionGetString(POSITION_SYMBOL) == symbol)
        {
         TotalPositions++;
        }
     }

   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong orderTicket = OrderGetTicket(i);
      if(OrderSelect(orderTicket) && OrderGetString(ORDER_SYMBOL) == symbol)
        {
         TotalOrders++;
        }
     }

   if(Activated == true && TotalPositions == 0 && TotalOrders == 0 && spread <= 2 * point)
     {
      double askPrice = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_ASK), 4); // these values are constant
      double bidPrice = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_ASK), 4);
      double price = bidPrice + (askPrice - bidPrice) / 2; // for better grid placement
      double first_upper_grid = price + TP_Pips_Point / 2;
      double first_lower_grid = price - TP_Pips_Point / 2;

      double line_level = (first_upper_grid + first_lower_grid) / 2;
      ObjectCreate(0, "HorizontalLine", OBJ_HLINE, 0, 0, line_level);
      ObjectSetInteger(0, "HorizontalLine", OBJPROP_COLOR, clrLightSkyBlue);
      ObjectSetInteger(0, "HorizontalLine", OBJPROP_WIDTH, 1);

      double sell_limit_tp = first_upper_grid - TP_Pips_Point - TP_Gap;
      double buy_stop_tp = first_upper_grid + TP_Pips_Point + TP_Gap;
      double buy_limit_tp = first_lower_grid + TP_Pips_Point + TP_Gap;
      double sell_stop_tp = first_lower_grid - TP_Pips_Point - TP_Gap;

      for(int i = 0; i < grid_level; i++)
        {
         trade.SellLimit(lotSize, first_upper_grid + i * TP_Pips_Point, symbol, 0, sell_limit_tp + i * TP_Pips_Point, ORDER_TIME_GTC);
         trade.BuyStop(lotSize, first_upper_grid + i * TP_Pips_Point, symbol, 0, buy_stop_tp + i * TP_Pips_Point, ORDER_TIME_GTC);

         trade.BuyLimit(lotSize, first_lower_grid -  i * TP_Pips_Point, symbol, 0, buy_limit_tp - i * TP_Pips_Point, ORDER_TIME_GTC);
         trade.SellStop(lotSize, first_lower_grid - i * TP_Pips_Point, symbol, 0, sell_stop_tp - i * TP_Pips_Point, ORDER_TIME_GTC);
        }
     }

// Grid Replacement
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong posTicket = PositionGetTicket(i);
      if(PositionSelectByTicket(posTicket) && PositionGetString(POSITION_SYMBOL) == symbol)
        {
         if(PositionGetInteger(POSITION_TYPE) == 0 && PositionGetDouble(POSITION_TP) != 0 &&
            NormalizeDouble(PositionGetDouble(POSITION_PRICE_CURRENT), 5) + TP_Gap >= NormalizeDouble(PositionGetDouble(POSITION_TP), 5))
           {
            double buyPrice = PositionGetDouble(POSITION_TP) - TP_Pips_Point - TP_Gap;
            double buyLimitTP = buyPrice + TP_Pips_Point + TP_Gap;
            trade.PositionClose(posTicket);
            if(togglegrid)
              {
               trade.BuyLimit(lotSize, buyPrice, symbol, 0, buyLimitTP, ORDER_TIME_GTC);
              }
           }
         else
            if(PositionGetInteger(POSITION_TYPE) == 1 && PositionGetDouble(POSITION_TP) != 0 &&
               NormalizeDouble(PositionGetDouble(POSITION_PRICE_CURRENT), 5) - TP_Gap <= NormalizeDouble(PositionGetDouble(POSITION_TP), 5))
              {
               double sellPrice = PositionGetDouble(POSITION_TP) + TP_Pips_Point + TP_Gap;
               double sellLimitTP = sellPrice - TP_Pips_Point - TP_Gap;
               trade.PositionClose(posTicket);
               if(togglegrid)
                 {
                  trade.SellLimit(lotSize, sellPrice, symbol, 0, sellLimitTP, ORDER_TIME_GTC);
                 }
              }
        }
     }

// Toggle Grid
   if(!togglegrid)
     {
      ClosePendings(symbol);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Status(string symbol, double profit, double loss, double net, double TakeProfit, double stopLoss, datetime start_date)
  {
// Profit
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong posTicket = PositionGetTicket(i);
      if(PositionSelectByTicket(posTicket) && PositionGetString(POSITION_SYMBOL) == symbol)
        {
         if(PositionGetDouble(POSITION_PROFIT) > 0)
           {
            profit += (PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP));
           }
        }
     }

   HistorySelect(start_date, TimeCurrent());
   int history_deal = HistoryDealsTotal();
   for(int i = history_deal - 1; i >= 0; i--)
     {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0 && HistoryDealGetString(dealTicket, DEAL_SYMBOL) == symbol)
        {
         if(HistoryDealGetDouble(dealTicket, DEAL_PROFIT) > 0)
           {
            profit += (HistoryDealGetDouble(dealTicket, DEAL_PROFIT) + HistoryDealGetDouble(dealTicket, DEAL_SWAP));
           }
        }
     }

// Loss
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong posTicket = PositionGetTicket(i);
      if(PositionSelectByTicket(posTicket) && PositionGetString(POSITION_SYMBOL) == symbol)
        {
         if(PositionGetDouble(POSITION_PROFIT) < 0)
           {
            loss += (PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP));
           }
        }
     }

// Auto TP

   net = NormalizeDouble((profit + loss), 2);
   if(net > TakeProfit)
     {
      ClosePositions(symbol);
      ClosePendings(symbol);
      ObjectDelete(0, "HorizontalLine");
      ExpertRemove();
     }

   Comment
   (
      symbol,
      "\nProfit: ", NormalizeDouble((profit), 2),
      "\nLoss: ", NormalizeDouble((loss), 2),
      "\nNet: ", NormalizeDouble((net), 2)
   );

// Auto SL
   if(net < -stopLoss)
     {
      ClosePositions(symbol);
      ClosePendings(symbol);
      ObjectDelete(0, "HorizontalLine");
      ExpertRemove();
     }
  }

//+------------------------------------------------------------------+
//| DeactivateGrid Function                                          |
//+------------------------------------------------------------------+
void DeactivateGrid(bool Activated, string symbol)
  {
// Deactivate EA
   if(Activated == false)
     {
      ClosePositions(symbol);
      ClosePendings(symbol);
      ObjectDelete(0, "HorizontalLine");
     }
  }

//+------------------------------------------------------------------+
//| Close Positions Function                                         |
//+------------------------------------------------------------------+
void ClosePositions(string symbol)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong posTicket = PositionGetTicket(i);
      if(PositionSelectByTicket(posTicket))
        {
         if(PositionGetString(POSITION_SYMBOL) != symbol)
            continue;
         if(trade.PositionClose(posTicket))
           {
            Print("Closing Positions for ", symbol, "...");
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Close Pending Orders Function                                    |
//+------------------------------------------------------------------+
void ClosePendings(string symbol)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong orderTicket = OrderGetTicket(i);
      if(OrderSelect(orderTicket))
        {
         if(OrderGetString(ORDER_SYMBOL) != symbol)
            continue;
         if(trade.OrderDelete(orderTicket))
           {
            Print("Closing Pending Orders for ", symbol, "...");
           }
        }
     }
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
