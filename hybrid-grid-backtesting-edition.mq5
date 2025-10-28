//+------------------------------------------------------------------+
//|                                                                  |
//|                                                                  |
//|                                  Hybrid Grid Backtesting Version |
//+------------------------------------------------------------------+
#property copyright "Catalyst"
#include <Trade\Trade.mqh>
#include <Controls\Button.mqh>
CTrade trade;
CButton btnClose;
CButton btnToggleGrid;

// Global Variables \\
// Manual Settings
input int grid_level = 10;
input double TP_Pips = 50;
input double gridprofitlimit = 1000; // Profit limit that closes all pending
input double profitLimit = 50; // Profit limit that closes everything
input double maxLoss = 1000;
input double lotSize = 0.01;
input bool Autotrading = true;
input bool StopAfterLoss;
input bool Activated = true;
//input int openHour = 9;
//input int closeHour = 23;

// Etc
double askPrice = 0.0;
double bidPrice = 0.0;
double totalProfit = 0.0;
double first_upper_grid = 0.0;
double first_lower_grid = 0.0;
int maxLossCount = 0;
int profitLimitCount = 0;
double highest_loss_reached = 0;
bool stopTrading;
bool togglegrid = true;

#define BTN_CLOSE_NAME "Btn Close"
#define BTN_TOGGLE_NAME "Btn Toggle"
int OnInit()
  {
   btnClose.Create(0, BTN_CLOSE_NAME, 0, 1500, 570, 1600, 600);
   btnClose.Text("Close All");
   btnClose.Color(clrBlack);
   btnClose.ColorBackground(clrWhiteSmoke);

   btnToggleGrid.Create(0, BTN_TOGGLE_NAME, 0, 1650, 570, 1750, 600);
   btnToggleGrid.Text("Toggle");
   btnToggleGrid.Color(clrBlack);
   btnToggleGrid.ColorBackground(clrWhiteSmoke);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   btnClose.Destroy(reason);
   btnToggleGrid.Destroy(reason);
  }

//+------------------------------------------------------------------+
//| OnTick Function                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(btnClose.Pressed())
     {
      Print(__FUNCTION__, "Closing All...");
      ClosePendings();
      ClosePositions();
      totalProfit = 0.00;
      ObjectDelete(0, "HorizontalLine");
      btnClose.Pressed(false);
      togglegrid = true;
      btnToggleGrid.ColorBackground(clrGreen);
     }

   if(btnToggleGrid.Pressed())
     {
      if(togglegrid)
        {
         ClosePendings();
         togglegrid = false;
         Print("Grid Replacement Off");
         btnToggleGrid.ColorBackground(clrRed);
        }
      else
        {
         togglegrid = true;
         Print("Grid Replacement On");
         btnToggleGrid.ColorBackground(clrGreen);
        }
      btnToggleGrid.Pressed(false);
     }

// Main Code \\
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
   double TP_Pips_Point = TP_Pips * point;
   double TP_Gap = 100 * point; // gap to increase TP for better grid replacement calculations
   double askPricelive = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), 4); // constantly changing values
   double bidPricelive = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), 4);
   double spread = askPricelive - bidPricelive;

// Initializing Grids
   MqlDateTime timeNow; // Backtesting purpose
   TimeToStruct(TimeCurrent(), timeNow); // Backtesting purpose

   if(Activated == true && PositionsTotal() == 0 && OrdersTotal() == 0 &&
      stopTrading == false) //openHour <= timeNow.hour && closeHour >= timeNow.hour &&
     {
      totalProfit = 0;
      togglegrid = true;
      btnToggleGrid.ColorBackground(clrGreen);
      Print("Starting Catalyst's Grid...");
      askPrice = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), 4); // these values are constant
      bidPrice = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), 4);
      double price = bidPrice + (askPrice - bidPrice) / 2; // for better grid placement
      first_upper_grid = price + TP_Pips_Point / 2;
      first_lower_grid = price - TP_Pips_Point / 2;
      double line_level = (first_upper_grid + first_lower_grid) / 2;

      // Create a horizontal line at the specified price level
      ObjectCreate(0, "HorizontalLine", OBJ_HLINE, 0, 0, line_level);

      // Set line color (optional)
      ObjectSetInteger(0, "HorizontalLine", OBJPROP_COLOR, clrLightSkyBlue);

      // Set line width (optional)
      ObjectSetInteger(0, "HorizontalLine", OBJPROP_WIDTH, 1);

      double sell_limit_tp = first_upper_grid - TP_Pips_Point - TP_Gap;
      double buy_stop_tp = first_upper_grid + TP_Pips_Point + TP_Gap;
      double buy_limit_tp = first_lower_grid + TP_Pips_Point + TP_Gap;
      double sell_stop_tp = first_lower_grid - TP_Pips_Point - TP_Gap;

      for(int i = 0; i < grid_level; i++)
        {
         trade.SellLimit(lotSize, first_upper_grid + i * TP_Pips_Point, _Symbol, 0, sell_limit_tp + i * TP_Pips_Point, ORDER_TIME_GTC);
         trade.BuyStop(lotSize, first_upper_grid + i * TP_Pips_Point, _Symbol, 0, buy_stop_tp + i * TP_Pips_Point, ORDER_TIME_GTC);

         trade.BuyLimit(lotSize, first_lower_grid -  i * TP_Pips_Point, _Symbol, 0, buy_limit_tp - i * TP_Pips_Point, ORDER_TIME_GTC);
         trade.SellStop(lotSize, first_lower_grid - i * TP_Pips_Point, _Symbol, 0, sell_stop_tp - i * TP_Pips_Point, ORDER_TIME_GTC);
        }
     }

// Grid Replacement
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong posTicket = PositionGetTicket(i);
      if(PositionSelectByTicket(posTicket))
        {
         if(PositionGetInteger(POSITION_TYPE) == 0 &&
            NormalizeDouble(PositionGetDouble(POSITION_PRICE_CURRENT), 5) + TP_Gap >= NormalizeDouble(PositionGetDouble(POSITION_TP), 5))
           {
            double buyPrice = NormalizeDouble(PositionGetDouble(POSITION_TP), 5) - TP_Pips_Point - TP_Gap;
            double buyLimitTP = buyPrice + TP_Pips_Point + TP_Gap;
            trade.PositionClose(posTicket);
            if(togglegrid)
              {
               trade.BuyLimit(lotSize, buyPrice, _Symbol, 0, buyLimitTP, ORDER_TIME_GTC);
              }
           }
         else
            if(PositionGetInteger(POSITION_TYPE) == 1 &&
               NormalizeDouble(PositionGetDouble(POSITION_PRICE_CURRENT), 5) - TP_Gap <= NormalizeDouble(PositionGetDouble(POSITION_TP), 5))
              {
               double sellPrice = NormalizeDouble(PositionGetDouble(POSITION_TP), 5) + TP_Pips_Point + TP_Gap;
               double sellLimitTP = sellPrice - TP_Pips_Point - TP_Gap;
               trade.PositionClose(posTicket);
               if(togglegrid)
                 {
                  trade.SellLimit(lotSize, sellPrice, _Symbol, 0, sellLimitTP, ORDER_TIME_GTC);
                 }
              }
        }
     }

// Deactivate EA
   if(Activated == false)
     {
      ClosePendings();
      ClosePositions();
      ObjectDelete(0, "HorizontalLine");
      Print("Catalyst's Grid Deactivated.");
     }

// Risk Management Area \\
// Loss Calculation
   double totalLoss = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong posTicket = PositionGetTicket(i);
      if(PositionSelectByTicket(posTicket))
        {
         if(PositionGetDouble(POSITION_PROFIT) < 0)
           {
            totalLoss += PositionGetDouble(POSITION_PROFIT);
           }
        }
     }

// Profit Calculation
   int totalDeals = HistoryDealsTotal();
   bool markedDeals[]; // Declare a dynamic array
   ArrayResize(markedDeals, totalDeals); // Resize the array to match the total number of historical deals

   HistorySelect(0, TimeCurrent());
   for(int i = totalDeals - 1; i >= 0; i--)
     {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(!markedDeals[i])
        {
         if(HistoryDealSelect(dealTicket) && HistoryDealGetInteger(dealTicket, DEAL_TYPE) != DEAL_TYPE_BALANCE)
           {
            if(HistoryDealGetDouble(dealTicket, DEAL_PROFIT) > 0)
              {
               totalProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
              }
            markedDeals[i] = true; // Mark the deal as processed
           }
        }
     }

// Auto Trading \\
// Auto TP
   Print(totalProfit);
   if(totalProfit >= gridprofitlimit)
     {
      ClosePendings();
      togglegrid = false;
      btnToggleGrid.ColorBackground(clrRed);
     }

   double net = NormalizeDouble((totalProfit + totalLoss), 2);
   Print("Net: ", net);
   if(Autotrading == true && net >= profitLimit)
     {
      TakeProfit();
      totalProfit = 0;
      togglegrid = true;
      btnToggleGrid.ColorBackground(clrGreen);
     }

// Auto SL (adjust based on acc size)
   if(net < 0 && highest_loss_reached > net)
     {
      highest_loss_reached = net;
     }

   if(net <= -maxLoss)
     {
      ObjectDelete(0, "HorizontalLine");
      ClosePositions();
      ClosePendings();
      totalProfit = 0.00;
      maxLossCount++;
      togglegrid = true;
      btnToggleGrid.ColorBackground(clrGreen);
      if(StopAfterLoss == true)
        {
         stopTrading = true;
        }
     }

// Status
   if(Autotrading == true)
     {
      Print("Auto TP hit         : ", profitLimitCount);
      Print("Max Loss hit        : ", maxLossCount);
      Print("Highest Loss Reached: ", highest_loss_reached);
     }

  }

//+------------------------------------------------------------------+
//| Close Positions Function                                         |
//+------------------------------------------------------------------+
void ClosePositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong posTicket = PositionGetTicket(i);
      if(PositionSelectByTicket(posTicket))
        {
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(trade.PositionClose(posTicket))
           {
            Print("Positions Closed.");
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Close Pending Orders Function                                    |
//+------------------------------------------------------------------+
void ClosePendings()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong orderTicket = OrderGetTicket(i);
      if(OrderSelect(orderTicket))
        {
         if(OrderGetString(ORDER_SYMBOL) != _Symbol)
            continue;
         if(trade.OrderDelete(orderTicket))
           {
            Print("Pending Orders Closed.");
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Take Profit Function                                             |
//+------------------------------------------------------------------+
void TakeProfit()
  {
   totalProfit = 0.00;
   ClosePositions();
   ClosePendings();
   ObjectDelete(0, "HorizontalLine");
   profitLimitCount++;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

