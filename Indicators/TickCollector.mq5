//+------------------------------------------------------------------+
//|                                                TickCollector.mq5 |
//|                                                        avoitenko |
//|                        https://login.mql5.com/en/users/avoitenko |
//+------------------------------------------------------------------+
#property copyright  "avoitenko"
#property link       "https://login.mql5.com/en/users/avoitenko"
#property version    "1.00"
//---
#property description "Indicator for collecting ticks"
#property description "Generates a custom event \"New tick\" for the chart - the receiver of the event"
//---
#property indicator_chart_window
#property indicator_buffers  0
#property indicator_plots 0
//---
#define CHARTEVENT_INIT 0x0   // Initialization event
#define CHARTEVENT_TICK 0x1   // New tick event
#define SEP             ";"   // delimiter
//---
input long   chart_id=0;      // the identifier of the event receiver
input ushort custom_event_id=0;// event identifier
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
/*
//--- check, for tester OnChartEvent doesn't work
   if(MQLInfoInteger(MQL_TESTER))
     {
      Print("Indicator '",MQLInfoString(MQL_PROGRAM_NAME),"' does not work in the tester");
      return(INIT_FAILED);
     }
*/
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   MqlTick tick;
   SymbolInfoTick(_Symbol,tick);

   long vol_m1[1];
   CopyTickVolume(_Symbol,PERIOD_M1,0,1,vol_m1);

//--- form a line like: Symbol, (long)DateTime, (long)DateTime_msec, Bid, Ask, Last, (int)Flags, (int)Volume
   string sparam=_Symbol+SEP
                 +(string)tick.time+SEP
                 +(string)tick.time_msc+SEP
                 +DoubleToString(tick.bid,_Digits)+SEP
                 +DoubleToString(tick.ask,_Digits)+SEP
                 +DoubleToString(tick.last,_Digits)+SEP
                 +(string)tick.flags+SEP
                 +(string)vol_m1[0]+SEP
                 +(string)tick_volume[rates_total-1]+SEP
                 +(string)_Digits+SEP
                 +(string)GetMicrosecondCount();

   if(prev_calculated==0)
     {
      //--- initialization event CHARTEVENT_INIT
      EventChartCustom(chart_id,custom_event_id,CHARTEVENT_INIT,tick.bid,sparam);
      return(rates_total);
     }

//--- event new tick CHARTEVENT_TICK
   EventChartCustom(chart_id,custom_event_id,CHARTEVENT_TICK,tick.bid,sparam);

   return(rates_total);
  }
//+------------------------------------------------------------------+
